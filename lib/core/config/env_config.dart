import 'dart:io';

class EnvConfig {
  EnvConfig._();

  static final Map<String, String> _envMap = {};
  static bool _initialized = false;

  static const String defaultGoogleClientId =
      '203174165071-6ig6ng4dmiciop1uo471ndmbbr4fa3nd.apps.googleusercontent.com';
  static const String defaultGoogleClientSecret = '';

  static Future<void> init() async {
    loadSync();
  }

  static void loadSync() {
    if (_initialized) return;

    final file = _findEnvFile();
    if (file != null && file.existsSync()) {
      try {
        final lines = file.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final idx = trimmed.indexOf('=');
          if (idx > 0) {
            final key = trimmed.substring(0, idx).trim();
            final value = trimmed.substring(idx + 1).trim();
            _envMap[key] = value;
          }
        }
      } catch (_) {}
    }
    _initialized = true;
  }

  static File? _findEnvFile() {
    // 1. Check relative .env
    try {
      final direct = File('.env');
      if (direct.existsSync()) return direct;
    } catch (_) {}

    // 2. Search upwards from current directory
    try {
      var dir = Directory.current;
      for (int i = 0; i < 5; i++) {
        final candidate = File('${dir.path}${Platform.pathSeparator}.env');
        if (candidate.existsSync()) return candidate;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}

    // 3. Search upwards from executable directory
    try {
      var exeDir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 6; i++) {
        final candidate = File('${exeDir.path}${Platform.pathSeparator}.env');
        if (candidate.existsSync()) return candidate;
        final parent = exeDir.parent;
        if (parent.path == exeDir.path) break;
        exeDir = parent;
      }
    } catch (_) {}

    return null;
  }

  static const String _dartDefineClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String _dartDefineClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  static String get googleClientId {
    if (_dartDefineClientId.isNotEmpty) return _dartDefineClientId;
    if (!_initialized) loadSync();

    final fromMap = _envMap['GOOGLE_CLIENT_ID'];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;

    final fromEnv = Platform.environment['GOOGLE_CLIENT_ID'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    return defaultGoogleClientId;
  }

  static String get googleClientSecret {
    if (_dartDefineClientSecret.isNotEmpty) return _dartDefineClientSecret;
    if (!_initialized) loadSync();

    final fromMap = _envMap['GOOGLE_CLIENT_SECRET'];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;

    final fromEnv = Platform.environment['GOOGLE_CLIENT_SECRET'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    return defaultGoogleClientSecret;
  }
}
