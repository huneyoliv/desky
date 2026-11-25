import 'dart:io';

import 'package:desky/core/storage/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    appSecureStorage = const FlutterSecureStorage();
  });

  test(
    'real Linux secure storage initializes and reads without aborting',
    () async {
      await initSecureStorage();
      final hasBus =
          (Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ?? '').isNotEmpty;
      stderr.writeln(
          'secure-storage backend=${appSecureStorage.runtimeType}; sessionBus=$hasBus');

      expect(
        appSecureStorage,
        anyOf(isA<FlutterSecureStorage>(), isA<KeyringlessSecureStorage>()),
      );
      final value =
          await appSecureStorage.read(key: 'desky_nonexistent_smoke_key');
      expect(value, isNull);
    },
    skip: !Platform.isLinux,
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
