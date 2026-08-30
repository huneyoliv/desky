class AppConstants {
  AppConstants._();

  static const String appName = 'Desky';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;
  static const String githubRepo = 'huneyoliv/desky';

  /// When compiled with `--dart-define=ENABLE_IN_APP_UPDATER=false` (e.g. for Microsoft Store / MSIX),
  /// the in-app updater is entirely disabled at compile time.
  static const bool enableInAppUpdater = bool.fromEnvironment(
    'ENABLE_IN_APP_UPDATER',
    defaultValue: true,
  );
}


