import 'dart:io';

import 'package:desky/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

ProcessResult _ok(String out) => ProcessResult(0, 0, out, '');

void main() {
  group('linuxSecretServiceAvailable', () {
    test('true when the Secret Service is running', () async {
      final ok = await linuxSecretServiceAvailable(
        run: (exe, args) async =>
            _ok("(['org.freedesktop.DBus', 'org.freedesktop.secrets'],)"),
      );
      expect(ok, isTrue);
    });

    test('true when it is only activatable (dbus-send output)', () async {
      final ok = await linuxSecretServiceAvailable(
        run: (exe, args) async {
          if (exe == 'gdbus') throw const ProcessException('gdbus', []);
          final method = args.last;
          return _ok(method.endsWith('ListActivatableNames')
              ? 'array [ string "org.freedesktop.secrets" ]'
              : 'array [ string "org.freedesktop.DBus" ]');
        },
      );
      expect(ok, isTrue);
    });

    test('false when no Secret Service is on the bus', () async {
      final ok = await linuxSecretServiceAvailable(
        run: (exe, args) async => _ok("(['org.freedesktop.DBus'],)"),
      );
      expect(ok, isFalse);
    });

    test('false when neither gdbus nor dbus-send can run', () async {
      final ok = await linuxSecretServiceAvailable(
        run: (exe, args) async => throw ProcessException(exe, args),
      );
      expect(ok, isFalse);
    });
  });

  test('KeyringlessSecureStorage stores nothing and never throws', () async {
    const storage = KeyringlessSecureStorage();
    await storage.write(key: 'jwt_token', value: 'abc');
    expect(await storage.read(key: 'jwt_token'), isNull);
    expect(await storage.containsKey(key: 'jwt_token'), isFalse);
    expect(await storage.readAll(), isEmpty);
    await storage.delete(key: 'jwt_token');
    await storage.deleteAll();
  });
}
