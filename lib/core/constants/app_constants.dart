class AppConstants {
  AppConstants._();

  static const String appName = 'Desky';
  static const String appVersion = '1.0.2';
  static const int buildNumber = 3;
  static const String githubRepo = 'huneyoliv/desky';

  /// When compiled with `--dart-define=ENABLE_IN_APP_UPDATER=false` (e.g. for Microsoft Store / MSIX),
  /// the in-app updater is entirely disabled at compile time.
  static const bool enableInAppUpdater = bool.fromEnvironment(
    'ENABLE_IN_APP_UPDATER',
    defaultValue: true,
  );

  /// Public PNG icon URL for Discord RPC small image and external services.
  static const String deskyIconUrl =
      'https://raw.githubusercontent.com/huneyoliv/desky/main/assets/icons/icon.png';
}


