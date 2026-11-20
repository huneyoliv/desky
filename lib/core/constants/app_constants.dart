class AppConstants {
  AppConstants._();

  static const String appName = 'Desky';
  static const String appVersion = '1.3.0';
  static const int buildNumber = 23;
  static const String githubRepo = 'huneyoliv/desky';

  /// When compiled with `--dart-define=ENABLE_IN_APP_UPDATER=false` (e.g. for Microsoft Store / MSIX),
  /// the in-app updater is entirely disabled at compile time.
  static const bool enableInAppUpdater = bool.fromEnvironment(
    'ENABLE_IN_APP_UPDATER',
    defaultValue: true,
  );

  /// Name shown in Discord Rich Presence texts.
  static const String discordDisplayName = 'Desky';

  /// Raw files of this repository (bundled assets Discord can fetch).
  static const String repoRawBaseUrl =
      'https://raw.githubusercontent.com/huneyoliv/desky/main';

  /// Public PNG icon URL for Discord RPC small image and external services.
  static const String deskyIconUrl =
      'https://raw.githubusercontent.com/huneyoliv/desky/main/assets/icons/icon.png';
}
