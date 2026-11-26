import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Removes secrets and personal data from text before it is written to disk.
///
/// The log is meant to be attached to bug reports, so anything that would
/// let someone act as the user, or identify them, is replaced:
///
/// * `Authorization`/`Bearer` values, JWTs and long opaque tokens;
/// * values of sensitive keys (token, password, secret, cookie, code, ...),
///   in JSON (`"token": "..."`), query (`token=...`) and header form;
/// * URL query strings (they carry ids and one-time codes);
/// * email addresses;
/// * the user name inside home-directory paths.
String redactCrashText(String input) {
  var out = input;

  // Redact the complete Authorization value, including its authentication
  // scheme. Quoted values may contain whitespace, commas, or semicolons.
  out = out.replaceAllMapped(
    RegExp(
      r'''\bauthorization(\s*[:=]\s*)("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\r\n,;}\]]+)''',
      caseSensitive: false,
    ),
    (m) => 'Authorization${m[1]}<redacted>',
  );
  out = out.replaceAllMapped(
    RegExp(
      r'''\bbearer(\s*[:=]\s*|\s+)("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\s",;}]+)''',
      caseSensitive: false,
    ),
    (m) => 'Bearer${m[1]}<redacted>',
  );

  // Cookie headers often contain several key/value pairs. Redact the whole
  // header instead of stopping at the first semicolon or comma.
  out = out.replaceAllMapped(
    RegExp(
      r'''\b((?:set-)?cookie)(\s*[:=]\s*)("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\r\n}\]]+)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}<redacted>',
  );

  // JSON-style "key": "value" / "key": 123 for sensitive keys.
  out = out.replaceAllMapped(
    RegExp('("$_sensitiveKey"\\s*:\\s*)("(?:[^"\\\\]|\\\\.)*"|[^,}\\s]+)',
        caseSensitive: false),
    (m) => '${m[1]}"<redacted>"',
  );

  // key=value / key: value (query strings, headers, Dart map toString).
  out = out.replaceAllMapped(
    RegExp(
      '\\b($_sensitiveKey)(\\s*[=:]\\s*)'
      r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\s&,;}\]"']+)''',
      caseSensitive: false,
    ),
    (m) {
      final value = m[3]!;
      final quote =
          value.startsWith('"') ? '"' : (value.startsWith("'") ? "'" : '');
      return '${m[1]}${m[2]}$quote<redacted>$quote';
    },
  );

  // Whole query strings of URLs.
  out = out.replaceAllMapped(
    RegExp(r'(https?://[^\s?#"]+)\?[^\s#"]*', caseSensitive: false),
    (m) => '${m[1]}?<redacted>',
  );

  // JWTs and other long opaque tokens.
  out = out.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*'),
      '<redacted>');
  out = out.replaceAll(
      RegExp(r'(?<![A-Za-z0-9_\-/.])[A-Za-z0-9_\-+=]{40,}(?![A-Za-z0-9_\-/.])'),
      '<redacted>');

  // Email addresses.
  out = out.replaceAll(
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), '<email>');

  // User names in home paths (Windows, macOS, Linux).
  out = out.replaceAllMapped(
    RegExp(r'([A-Za-z]:[\\/]+Users[\\/]+)[^\\/:"\r\n]+', caseSensitive: false),
    (m) => '${m[1]}<user>',
  );
  out = out.replaceAllMapped(
    RegExp(r'(/(?:home|Users)/)[^/\s:"]+'),
    (m) => '${m[1]}<user>',
  );
  return out;
}

/// A key name that holds a secret: any prefix (`accessToken`,
/// `refresh_token`), a sensitive word, and an optional short suffix. Words
/// that only contain one (`footprint`, `statusCode`) do not match.
const String _sensitiveKey =
    r'(?:[a-z0-9_\-]*(?:token|password|passwd|secret|api_?key|cookie|jwt|credentials?|auth_?code|otp|signature|session_?id)(?:_?(?:id|s|hash|value))?|code(?:_?verifier)?|session)';

/// Cuts [text] to at most [maxBytes] of UTF-8, never splitting a character.
String truncateUtf8(String text, int maxBytes,
    {String marker = '…[truncated]'}) {
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return text;
  final markerBytes = utf8.encode(marker).length;
  var end = maxBytes - markerBytes;
  if (end <= 0) return '';
  // Step back over UTF-8 continuation bytes (10xxxxxx).
  while (end > 0 && (bytes[end] & 0xC0) == 0x80) {
    end--;
  }
  return utf8.decode(bytes.sublist(0, end)) + marker;
}

/// Appends redacted, size-bounded entries to `crash.log`.
///
/// Limits are in bytes, as stored on disk:
///
/// * an entry is at most [maxEntryBytes];
/// * `crash.log` never grows past [maxFileBytes]: when the next entry would
///   not fit, the file is moved to `crash.log.1` (replacing the previous one)
///   and a new file is started. At most `2 * maxFileBytes` is ever on disk.
///
/// Writes are synchronous, and fatal entries are explicitly flushed before
/// the handler returns. Failures are exposed through [lastError], not thrown.
void _acquireExclusiveLock(RandomAccessFile lock) {
  final wait = Stopwatch()..start();
  while (true) {
    try {
      lock.lockSync(FileLock.exclusive);
      return;
    } on FileSystemException catch (error) {
      // Windows reports an already-held lock as ERROR_LOCK_VIOLATION (33).
      // Wait briefly instead of losing a valid crash entry during contention.
      if (error.osError?.errorCode != 33 || wait.elapsedMilliseconds >= 2000) {
        rethrow;
      }
      sleep(const Duration(milliseconds: 2));
    }
  }
}

class CrashLogWriter {
  CrashLogWriter(
    this.directory, {
    this.maxFileBytes = 256 * 1024,
    this.maxEntryBytes = 16 * 1024,
    this.maxStackLines = 40,
    DateTime Function()? clock,
  })  : assert(maxEntryBytes <= maxFileBytes),
        _clock = clock ?? DateTime.now;

  final Directory directory;
  final int maxFileBytes;
  final int maxEntryBytes;
  final int maxStackLines;
  final DateTime Function() _clock;
  bool _writing = false;
  Object? _lastError;
  StackTrace? _lastErrorStackTrace;

  /// The most recent formatting, locking, or filesystem failure, if any.
  Object? get lastError => _lastError;

  /// The stack associated with [lastError].
  StackTrace? get lastErrorStackTrace => _lastErrorStackTrace;

  static const String fileName = 'crash.log';

  File get file => File('${directory.path}${Platform.pathSeparator}$fileName');
  File get rotatedFile => File('${file.path}.1');

  /// Builds the text of one entry (redacted and truncated).
  String formatEntry(String kind, Object? error, StackTrace? stack) {
    final lines = (stack ?? StackTrace.empty)
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(maxStackLines)
        .join('\n');
    final mode =
        kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
    final header = redactCrashText(
        '=== ${_clock().toUtc().toIso8601String()} [$kind] $mode\n');
    final message = redactCrashText('${error ?? '(no message)'}');
    final frames = redactCrashText(lines);

    // Reserve room for the stack before truncating a long error message.
    final suffix = '\n$frames';
    final contentLimit = maxEntryBytes - 1;
    final fixedBytes = utf8.encode('$header$suffix').length;
    final messageBudget = contentLimit - fixedBytes;
    final boundedMessage =
        messageBudget > 0 ? truncateUtf8(message, messageBudget) : '';
    return '${truncateUtf8('$header$boundedMessage$suffix', contentLimit)}\n';
  }

  /// Writes one entry. Returns false when it could not be written.
  bool record(String kind, Object? error, StackTrace? stack) {
    // An error raised while logging must not be logged again (and again).
    if (_writing) return false;
    _writing = true;
    _lastError = null;
    _lastErrorStackTrace = null;
    RandomAccessFile? lock;
    var locked = false;
    var recorded = false;
    try {
      final entry = formatEntry(kind, error, stack);
      final entryBytes = utf8.encode(entry);
      final f = file;

      // The size check, rotation, and append must be one operation across
      // processes; otherwise concurrent writers can lose or corrupt entries.
      lock = File('${f.path}.lock').openSync(mode: FileMode.write);
      _acquireExclusiveLock(lock);
      locked = true;
      final current = f.existsSync() ? f.lengthSync() : 0;
      if (current + entryBytes.length > maxFileBytes) _rotate();
      f.writeAsBytesSync(
        entryBytes,
        mode: FileMode.append,
        flush: kind == 'fatal',
      );
      recorded = true;
    } catch (error, stack) {
      _lastError = error;
      _lastErrorStackTrace = stack;
    } finally {
      if (locked) {
        try {
          lock!.unlockSync();
        } catch (error, stack) {
          recorded = false;
          _lastError = error;
          _lastErrorStackTrace = stack;
        }
      }
      try {
        lock?.closeSync();
      } catch (error, stack) {
        recorded = false;
        _lastError = error;
        _lastErrorStackTrace = stack;
      }
      _writing = false;
    }
    return recorded;
  }

  void _rotate() {
    final f = file;
    if (!f.existsSync()) return;
    final old = rotatedFile;
    if (old.existsSync()) old.deleteSync();
    f.renameSync(old.path);
  }
}

/// App-wide crash log: uncaught Flutter, platform and zone errors are
/// written to `crash.log` in the app support folder.
class CrashLog {
  CrashLog._();

  static CrashLogWriter? _writer;
  static Object? _lastError;
  static StackTrace? _lastErrorStackTrace;

  /// Where the log lives (for "send us your log" support requests).
  static String? get path => _writer?.file.path;

  /// The most recent installation or write failure, if any.
  static Object? get lastError => _lastError;

  /// The stack associated with [lastError].
  static StackTrace? get lastErrorStackTrace => _lastErrorStackTrace;

  /// Hooks the error handlers. The handlers already in place keep running
  /// after logging, and the decision whether a platform error counts as
  /// handled stays theirs (false, the framework default, when there is none):
  /// logging never hides an error.
  static Future<void> install({
    Directory? directory,
    CrashLogWriter? writer,
    Future<Directory> Function()? directoryLoader,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      _writer = writer ??
          CrashLogWriter(
            directory ??
                await (directoryLoader ?? getApplicationSupportDirectory)()
                    .timeout(timeout),
          );
      _lastError = null;
      _lastErrorStackTrace = null;
    } catch (error, stack) {
      _writer = null;
      _lastError = error;
      _lastErrorStackTrace = stack;
    }

    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.silent ? 'flutter-silent' : 'flutter',
          details.exceptionAsString(), details.stack);
      previousFlutter?.call(details);
    };

    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('fatal', error, stack);
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  /// Records an error. Safe to call before [install] (it is then dropped)
  /// and from inside error handlers. Returns whether the entry was written.
  static bool record(String kind, Object? error, StackTrace? stack) {
    final writer = _writer;
    if (writer == null) return false;
    final recorded = writer.record(kind, error, stack);
    _lastError = writer.lastError;
    _lastErrorStackTrace = writer.lastErrorStackTrace;
    return recorded;
  }

  @visibleForTesting
  static void reset() {
    _writer = null;
    _lastError = null;
    _lastErrorStackTrace = null;
  }
}
