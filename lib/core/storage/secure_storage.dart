import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The secure storage the app uses for the login token.
///
/// On Linux the keyring plugin aborts the whole process (an uncaught C++
/// exception, not a Dart error) when no Secret Service is running: KDE or
/// i3 without gnome-keyring, WSL, minimal installs. [initSecureStorage] checks
/// for the service first and, when it is missing, swaps in
/// [KeyringlessSecureStorage]. The token is also kept in SharedPreferences,
/// so login still survives a restart there.
FlutterSecureStorage appSecureStorage = const FlutterSecureStorage();

/// Call once in `main` before anything reads the token.
Future<void> initSecureStorage() async {
  if (kIsWeb || !Platform.isLinux) return;
  if (await linuxSecretServiceAvailable()) return;
  debugPrint('[secure-storage] no Secret Service on D-Bus; using preferences only');
  appSecureStorage = const KeyringlessSecureStorage();
}

/// The D-Bus name the keyring plugin (libsecret) talks to.
const String secretServiceBusName = 'org.freedesktop.secrets';

/// True when a Secret Service is running or can be started on the session bus.
Future<bool> linuxSecretServiceAvailable({
  Future<ProcessResult> Function(String, List<String>)? run,
}) async {
  final runner = run ??
      (String exe, List<String> args) =>
          Process.run(exe, args).timeout(const Duration(seconds: 3));
  if ((Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ?? '').isEmpty &&
      run == null) {
    // No session bus at all: libsecret cannot work.
    return false;
  }
  for (final method in const ['ListNames', 'ListActivatableNames']) {
    final out = await _busNames(runner, method);
    if (out == null) return false; // no tool to ask with: play it safe
    if (out.contains('"$secretServiceBusName"') ||
        out.contains("'$secretServiceBusName'")) {
      return true;
    }
  }
  return false;
}

/// Output of a DBus name-listing call, or null when neither gdbus nor
/// dbus-send could be run.
Future<String?> _busNames(
  Future<ProcessResult> Function(String, List<String>) run,
  String method,
) async {
  final attempts = <(String, List<String>)>[
    (
      'gdbus',
      [
        'call', '--session',
        '--dest', 'org.freedesktop.DBus',
        '--object-path', '/org/freedesktop/DBus',
        '--method', 'org.freedesktop.DBus.$method',
      ],
    ),
    (
      'dbus-send',
      [
        '--session', '--print-reply',
        '--dest=org.freedesktop.DBus', '/org/freedesktop/DBus',
        'org.freedesktop.DBus.$method',
      ],
    ),
  ];
  for (final (exe, args) in attempts) {
    try {
      final result = await run(exe, args);
      if (result.exitCode == 0) return '${result.stdout}';
    } catch (_) {
      // Tool missing or timed out: try the next one.
    }
  }
  return null;
}

/// Stores nothing; the callers already fall back to SharedPreferences.
class KeyringlessSecureStorage extends FlutterSecureStorage {
  const KeyringlessSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      false;

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      const {};

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}
