import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desky/core/diagnostics/crash_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

String _readLog(String path) => File('$path/crash.log').readAsStringSync();

void main() {
  group('redactCrashText', () {
    test('removes bearer tokens and Authorization headers', () {
      final out = redactCrashText(
          'headers: {Authorization: Bearer abc.def.ghi, x: 1}\nbearer=s3cr3tvalue');
      expect(out, isNot(contains('abc.def.ghi')));
      expect(out, isNot(contains('s3cr3tvalue')));
      expect(out, contains('Authorization: <redacted>'));
    });

    test('removes values of sensitive keys in JSON, query and map form', () {
      const input =
          '{"token":"t-123","refresh_token": "r-456","password":"hunter2",'
          '"accessToken":"a-789","count":3}\n'
          'POST /login?user=me&password=pw1&api_key=k1\n'
          '{sessionId: sid-1, cookie: c=1, otp: 123456}';
      final out = redactCrashText(input);
      for (final secret in [
        't-123',
        'r-456',
        'hunter2',
        'a-789',
        'pw1',
        'k1',
        'sid-1',
        '123456'
      ]) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      expect(out, contains('"count":3'), reason: 'non-sensitive values stay');
    });

    test('keeps ordinary words that merely contain a sensitive word', () {
      const input =
          'statusCode: 500, footprint: 12, spinner: true, tokenizer error';
      expect(redactCrashText(input), input);
    });

    test('removes URL query strings but keeps host and path', () {
      final out = redactCrashText(
          'DioException uri: https://api.example.com/logs/day?date=2026-11-23&uid=42 failed');
      expect(out, contains('https://api.example.com/logs/day?<redacted>'));
      expect(out, isNot(contains('uid=42')));
    });

    test('removes JWTs and long opaque tokens', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJl';
      final opaque = 'A' * 20 + 'b9_-' * 6;
      final out = redactCrashText('jwt $jwt and $opaque end');
      expect(out, isNot(contains(jwt)));
      expect(out, isNot(contains(opaque)));
      expect(out, contains('end'));
    });

    test('removes emails and the user name from home paths', () {
      final out = redactCrashText(
          'user a.b+c@example.co.uk at C:\\Users\\Jane Doe\\AppData\\x.dart '
          'and /home/jane/.config/y and /Users/jane/Library/z');
      expect(out, isNot(contains('example.co.uk')));
      expect(out, contains('<email>'));
      expect(out, isNot(contains('jane')));
      expect(out, isNot(contains('Jane')));
      expect(out, isNot(contains('Doe')));
      expect(out, contains(r'C:\Users\<user>'));
      expect(out, contains('/home/<user>/.config/y'));
      expect(out, contains('/Users/<user>/Library/z'));
    });

    test('keeps Dart stack frames readable', () {
      const frame =
          '#0      TimerNotifier.stopStudy (package:desky/features/timer/timer_notifier.dart:812:7)';
      expect(redactCrashText(frame), frame);
    });
    test('redacts JWT Authorization credentials regardless of length', () {
      const input = 'Authorization: JWT short-secret';
      final out = redactCrashText(input);
      expect(out, isNot(contains('short-secret')));
      expect(out, 'Authorization: <redacted>');
    });

    test('redacts Basic Authorization credentials regardless of length', () {
      const input = 'Authorization: Basic short-secret';
      final out = redactCrashText(input);
      expect(out, isNot(contains('short-secret')));
      expect(out, 'Authorization: <redacted>');
    });

    test('redacts a quoted password value', () {
      const input = 'password="short-secret"';
      final out = redactCrashText(input);
      expect(out, isNot(contains('short-secret')));
      expect(out, 'password="<redacted>"');
    });

    test('redacts OAuth code values without touching statusCode', () {
      const input = 'statusCode=302&code=abc123&code_verifier=xyz789';
      final out = redactCrashText(input);
      expect(out, isNot(contains('abc123')));
      expect(out, isNot(contains('xyz789')));
      expect(out, contains('statusCode=302'));
      expect(out, contains('code=<redacted>'));
      expect(out, contains('code_verifier=<redacted>'));
    });

    test('redacts every cookie in a Cookie header', () {
      const input = 'Cookie: a=1; session=abc123';
      final out = redactCrashText(input);
      expect(out, isNot(contains('a=1')));
      expect(out, isNot(contains('abc123')));
      expect(out, 'Cookie: <redacted>');
    });
  });

  group('truncateUtf8', () {
    test('never splits a multi-byte character and respects the byte cap', () {
      final text = 'ação✓' * 100;
      for (var cap = 15; cap < 60; cap++) {
        final out = truncateUtf8(text, cap);
        expect(utf8.encode(out).length, lessThanOrEqualTo(cap),
            reason: 'cap $cap');
        expect(() => utf8.decode(utf8.encode(out)), returnsNormally);
        expect(out.endsWith('…[truncated]'), isTrue);
      }
    });

    test('leaves short text alone', () {
      expect(truncateUtf8('ok', 100), 'ok');
    });
  });

  group('CrashLogWriter', () {
    late Directory dir;

    setUp(() async =>
        dir = await Directory.systemTemp.createTemp('crash_log_test'));
    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    CrashLogWriter writer({int file = 4096, int entry = 1024}) =>
        CrashLogWriter(
          dir,
          maxFileBytes: file,
          maxEntryBytes: entry,
          clock: () => DateTime.utc(2026, 11, 23, 12),
        );

    test('writes redacted entries with kind, time and stack', () {
      final w = writer();
      expect(
          w.record('flutter', 'failed with token=abc123',
              StackTrace.fromString('#0 main (x.dart:1:1)')),
          isTrue);
      final text = w.file.readAsStringSync();
      expect(text, contains('=== 2026-11-23T12:00:00.000Z [flutter]'));
      expect(text, contains('#0 main (x.dart:1:1)'));
      expect(text, isNot(contains('abc123')));
    });

    test('caps each entry in bytes, multi-byte text included', () {
      final w = writer(entry: 300);
      w.record('platform', 'ç' * 5000, null);
      expect(w.file.lengthSync(), lessThanOrEqualTo(300));
      expect(() => utf8.decode(w.file.readAsBytesSync()), returnsNormally);
    });

    test('keeps stack frames when the error message is truncated', () {
      final w = writer(entry: 600);
      const frame = '#0 importantFrame (package:desky/core/crash.dart:42:7)';
      expect(
        w.record(
          'platform',
          'long diagnostic message ' * 300,
          StackTrace.fromString(frame),
        ),
        isTrue,
      );
      final text = w.file.readAsStringSync();
      expect(w.file.lengthSync(), lessThanOrEqualTo(600));
      expect(text, contains('…[truncated]'));
      expect(text, contains(frame));
    });

    test('caps the stack length in lines', () {
      final w = CrashLogWriter(dir,
          maxStackLines: 3, maxEntryBytes: 4096, maxFileBytes: 8192);
      final stack = StackTrace.fromString(
          List.generate(50, (i) => '#$i frame$i').join('\n'));
      w.record('k', 'e', stack);
      final text = w.file.readAsStringSync();
      expect(text, contains('#2 frame2'));
      expect(text, isNot(contains('#3 frame3')));
    });

    test(
        'rotates by bytes: the file never exceeds the cap and at most one old file is kept',
        () {
      final w = writer(file: 2000, entry: 500);
      for (var i = 0; i < 200; i++) {
        w.record('k', 'entry $i ${'é' * 100}', null);
        expect(w.file.lengthSync(), lessThanOrEqualTo(2000),
            reason: 'after entry $i');
        if (w.rotatedFile.existsSync()) {
          expect(w.rotatedFile.lengthSync(), lessThanOrEqualTo(2000));
        }
      }
      final files = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(files, {'crash.log', 'crash.log.1', 'crash.log.lock'});
      // The newest entry is in the live file, the one before rotation in .1.
      expect(w.file.readAsStringSync(), contains('entry 199 '));
      final rotated = w.rotatedFile.readAsStringSync();
      expect(rotated, isNot(contains('entry 199 ')));
      expect(rotated, contains('=== '));
      // Entries are whole: every file starts at an entry header.
      expect(w.file.readAsStringSync().startsWith('=== '), isTrue);
      expect(rotated.startsWith('=== '), isTrue);
    });

    test('serializes concurrent writers with a file lock', () async {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
          File(Platform.resolvedExecutable)
              .parent
              .parent
              .parent
              .parent
              .parent
              .path;
      final flutter =
          '$flutterRoot/bin/flutter${Platform.isWindows ? '.bat' : ''}';
      final helper = File('${dir.path}/writer_process_test.dart');
      await helper.writeAsString("""
import 'dart:io';
import 'package:desky/core/diagnostics/crash_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker', () {
    final worker = int.parse(Platform.environment['CRASH_WORKER']!);
    final writer = CrashLogWriter(
      Directory(r'${dir.path}'),
      maxFileBytes: 65536,
      maxEntryBytes: 512,
      clock: () => DateTime.utc(2026, 11, 23, 12),
    );
    for (var entry = 0; entry < 25; entry++) {
      final ok = writer.record('k', 'worker=\$worker entry=\$entry', null);
      expect(ok, isTrue, reason: '\${writer.lastError}');
    }
  });
}
""");
      final results = await Future.wait(
        List.generate(
            4,
            (worker) => Process.run(
                  flutter,
                  ['test', helper.path, '--reporter', 'expanded'],
                  workingDirectory: Directory.current.path,
                  environment: {'CRASH_WORKER': '$worker'},
                )),
      );
      for (final result in results) {
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      }

      final text = _readLog(dir.path);
      expect(RegExp(r'^=== ', multiLine: true).allMatches(text).length, 100);
      for (var worker = 0; worker < 4; worker++) {
        for (var entry = 0; entry < 25; entry++) {
          expect(text, contains('worker=$worker entry=$entry'));
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('never throws when the folder cannot be written', () async {
      final gone = Directory('${dir.path}/missing/deeper');
      final w = CrashLogWriter(gone);
      expect(w.record('k', 'e', StackTrace.current), isFalse);
      expect(w.lastError, isNotNull);
      expect(w.lastErrorStackTrace, isNotNull);
    });

    test('an error while logging is not logged again', () {
      late CrashLogWriter w;
      var calls = 0;
      w = CrashLogWriter(dir, clock: () {
        calls++;
        // Logging from inside logging must be dropped, not recurse.
        expect(w.record('nested', 'inner', null), isFalse);
        return DateTime.utc(2026);
      });
      expect(w.record('outer', 'e', null), isTrue);
      expect(calls, 1);
      expect(w.file.readAsStringSync(), isNot(contains('inner')));
    });
  });

  group('CrashLog.install', () {
    late Directory dir;
    late FlutterExceptionHandler? savedFlutter;
    late ErrorCallback? savedPlatform;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('crash_log_install');
      savedFlutter = FlutterError.onError;
      savedPlatform = PlatformDispatcher.instance.onError;
    });

    tearDown(() async {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
      CrashLog.reset();
      await dir.delete(recursive: true);
    });

    test('logs Flutter errors and still calls the previous handler', () async {
      FlutterErrorDetails? forwarded;
      FlutterError.onError = (d) => forwarded = d;
      await CrashLog.install(directory: dir);

      final details = FlutterErrorDetails(
        exception: StateError('build failed password=pw9'),
        stack: StackTrace.fromString('#0 build (w.dart:3:4)'),
      );
      FlutterError.onError!(details);

      expect(forwarded, same(details));
      final text = File(CrashLog.path!).readAsStringSync();
      expect(text, contains('[flutter]'));
      expect(text, contains('build failed'));
      expect(text, isNot(contains('pw9')));
    });

    test(
        'fatal platform errors are logged synchronously; the previous decision is kept',
        () async {
      Object? seen;
      PlatformDispatcher.instance.onError = (e, s) {
        seen = e;
        return true;
      };
      await CrashLog.install(directory: dir);

      final handled = PlatformDispatcher.instance.onError!(
          Exception('boom'), StackTrace.empty);
      expect(handled, isTrue);
      expect(seen, isA<Exception>());
      // Already on disk when the handler returns, before any await.
      expect(File(CrashLog.path!).readAsStringSync(), contains('[fatal]'));
    });

    test(
        'without a previous handler a platform error is not reported as handled',
        () async {
      PlatformDispatcher.instance.onError = null;
      await CrashLog.install(directory: dir);
      expect(
          PlatformDispatcher.instance.onError!(
              Exception('x'), StackTrace.empty),
          isFalse);
    });

    test('exposes application support directory failures', () async {
      await CrashLog.install(
        directoryLoader: () async => throw StateError('directory unavailable'),
      );

      expect(CrashLog.path, isNull);
      expect(CrashLog.lastError, isA<StateError>());
      expect(CrashLog.lastErrorStackTrace, isNotNull);
      expect(CrashLog.record('k', 'e', null), isFalse);
    });

    test('times out application support directory lookup', () async {
      await CrashLog.install(
        directoryLoader: () => Completer<Directory>().future,
        timeout: const Duration(milliseconds: 10),
      );

      expect(CrashLog.path, isNull);
      expect(CrashLog.lastError, isA<TimeoutException>());
    });

    test('record before install is a harmless no-op', () {
      CrashLog.reset();
      expect(CrashLog.record('k', 'e', null), isFalse);
      expect(CrashLog.path, isNull);
    });
  });
}
