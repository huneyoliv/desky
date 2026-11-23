import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desky/core/diagnostics/crash_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactCrashText', () {
    test('removes bearer tokens and Authorization headers', () {
      final out = redactCrashText(
          'headers: {Authorization: Bearer abc.def.ghi, x: 1}\nbearer=s3cr3tvalue');
      expect(out, isNot(contains('abc.def.ghi')));
      expect(out, isNot(contains('s3cr3tvalue')));
      expect(out, contains('Authorization: Bearer <redacted>'));
    });

    test('removes values of sensitive keys in JSON, query and map form', () {
      const input = '{"token":"t-123","refresh_token": "r-456","password":"hunter2",'
          '"accessToken":"a-789","count":3}\n'
          'POST /login?user=me&password=pw1&api_key=k1\n'
          '{sessionId: sid-1, cookie: c=1, otp: 123456}';
      final out = redactCrashText(input);
      for (final secret in ['t-123', 'r-456', 'hunter2', 'a-789', 'pw1', 'k1', 'sid-1', '123456']) {
        expect(out, isNot(contains(secret)), reason: secret);
      }
      expect(out, contains('"count":3'), reason: 'non-sensitive values stay');
    });

    test('keeps ordinary words that merely contain a sensitive word', () {
      const input = 'statusCode: 500, footprint: 12, spinner: true, tokenizer error';
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
      const frame = '#0      TimerNotifier.stopStudy (package:desky/features/timer/timer_notifier.dart:812:7)';
      expect(redactCrashText(frame), frame);
    });
  });

  group('truncateUtf8', () {
    test('never splits a multi-byte character and respects the byte cap', () {
      final text = 'ação✓' * 100;
      for (var cap = 15; cap < 60; cap++) {
        final out = truncateUtf8(text, cap);
        expect(utf8.encode(out).length, lessThanOrEqualTo(cap), reason: 'cap $cap');
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

    setUp(() async => dir = await Directory.systemTemp.createTemp('crash_log_test'));
    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    CrashLogWriter writer({int file = 4096, int entry = 1024}) => CrashLogWriter(
          dir,
          maxFileBytes: file,
          maxEntryBytes: entry,
          clock: () => DateTime.utc(2026, 11, 23, 12),
        );

    test('writes redacted entries with kind, time and stack', () {
      final w = writer();
      expect(w.record('flutter', 'failed with token=abc123', StackTrace.fromString('#0 main (x.dart:1:1)')), isTrue);
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

    test('caps the stack length in lines', () {
      final w = CrashLogWriter(dir, maxStackLines: 3, maxEntryBytes: 4096, maxFileBytes: 8192);
      final stack = StackTrace.fromString(List.generate(50, (i) => '#$i frame$i').join('\n'));
      w.record('k', 'e', stack);
      final text = w.file.readAsStringSync();
      expect(text, contains('#2 frame2'));
      expect(text, isNot(contains('#3 frame3')));
    });

    test('rotates by bytes: the file never exceeds the cap and at most one old file is kept', () {
      final w = writer(file: 2000, entry: 500);
      for (var i = 0; i < 200; i++) {
        w.record('k', 'entry $i ${'é' * 100}', null);
        expect(w.file.lengthSync(), lessThanOrEqualTo(2000), reason: 'after entry $i');
        if (w.rotatedFile.existsSync()) {
          expect(w.rotatedFile.lengthSync(), lessThanOrEqualTo(2000));
        }
      }
      final files = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(files, {'crash.log', 'crash.log.1'});
      // The newest entry is in the live file, the one before rotation in .1.
      expect(w.file.readAsStringSync(), contains('entry 199 '));
      final rotated = w.rotatedFile.readAsStringSync();
      expect(rotated, isNot(contains('entry 199 ')));
      expect(rotated, contains('=== '));
      // Entries are whole: every file starts at an entry header.
      expect(w.file.readAsStringSync().startsWith('=== '), isTrue);
      expect(rotated.startsWith('=== '), isTrue);
    });

    test('never throws when the folder cannot be written', () async {
      final gone = Directory('${dir.path}/missing/deeper');
      final w = CrashLogWriter(gone);
      expect(w.record('k', 'e', StackTrace.current), isFalse);
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

    test('fatal platform errors are logged synchronously; the previous decision is kept', () async {
      Object? seen;
      PlatformDispatcher.instance.onError = (e, s) {
        seen = e;
        return true;
      };
      await CrashLog.install(directory: dir);

      final handled = PlatformDispatcher.instance.onError!(Exception('boom'), StackTrace.empty);
      expect(handled, isTrue);
      expect(seen, isA<Exception>());
      // Already on disk when the handler returns, before any await.
      expect(File(CrashLog.path!).readAsStringSync(), contains('[fatal]'));
    });

    test('without a previous handler a platform error is not reported as handled', () async {
      PlatformDispatcher.instance.onError = null;
      await CrashLog.install(directory: dir);
      expect(PlatformDispatcher.instance.onError!(Exception('x'), StackTrace.empty), isFalse);
    });

    test('record before install is a harmless no-op', () {
      CrashLog.reset();
      expect(() => CrashLog.record('k', 'e', null), returnsNormally);
      expect(CrashLog.path, isNull);
    });
  });
}
