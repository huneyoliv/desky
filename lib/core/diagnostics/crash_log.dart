import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Writes uncaught errors to `crash.log` in the app support folder, so a
/// crash that cannot be reproduced still leaves a trace to report.
///
/// The file is capped at [_maxBytes]: when it grows past that, the older half
/// is dropped. Logging never throws.
class CrashLog {
  CrashLog._();

  static const int _maxBytes = 256 * 1024;
  static File? _file;

  /// Where the log lives (for "send us your log" support requests).
  static String? get path => _file?.path;

  static Future<void> install() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}crash.log');
    } catch (_) {}

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record('flutter', details.exceptionAsString(), details.stack);
      previous?.call(details);
    };
    final platformPrevious = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      record('platform', error.toString(), stack);
      // Report as handled so one stray async error does not take the app down.
      return platformPrevious?.call(error, stack) ?? true;
    };
  }

  static void record(String kind, String message, StackTrace? stack) {
    final file = _file;
    if (file == null) return;
    try {
      if (file.existsSync() && file.lengthSync() > _maxBytes) {
        final text = file.readAsStringSync();
        file.writeAsStringSync(text.substring(text.length ~/ 2));
      }
      final lines = (stack ?? StackTrace.empty).toString().split('\n').take(25).join('\n');
      file.writeAsStringSync(
        '=== ${DateTime.now().toIso8601String()} [$kind] ${kReleaseMode ? 'release' : 'debug'}\n$message\n$lines\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }
}
