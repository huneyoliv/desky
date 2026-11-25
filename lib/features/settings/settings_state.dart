import '../../data/models/category_model.dart';
import '../../data/models/country_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../../core/theme/timer_appearance.dart';

class SettingsState {
  final CountryModel selectedCountry;
  final String selectedLanguage;
  final List<CountryModel> availableCountries;
  final List<CategoryModel> countryCategories;
  final bool isLoadingCountries;
  final bool isLoadingCategories;
  final String? errorMessage;
  final int dayResetHour;
  final bool showRestTime;
  final bool wakeNotifications;
  final bool soundEffects;
  final List<String> blockedUsers;
  final bool discordRpcEnabled;
  final bool obsOverlayMode;
  final bool classicYptLook;

  /// Classic YPT layout: the same destinations as the sidebar, as tabs along
  /// the top of the window. Off by default.
  final bool classicTopTabs;
  final double classicUiScale;
  final bool betaChannel;
  final String timerBackground;
  final String? timerBackgroundImagePath;
  final String timerFont;

  const SettingsState({
    this.selectedCountry = SettingsRepository.defaultCountry,
    this.selectedLanguage = 'pt',
    this.availableCountries = const [],
    this.countryCategories = const [],
    this.isLoadingCountries = false,
    this.isLoadingCategories = false,
    this.errorMessage,
    this.dayResetHour = 5,
    this.showRestTime = true,
    this.wakeNotifications = true,
    this.soundEffects = true,
    this.blockedUsers = const [],
    this.discordRpcEnabled = true,
    this.obsOverlayMode = false,
    this.classicYptLook = false,
    this.classicTopTabs = false,
    this.classicUiScale = 1.0,
    this.betaChannel = false,
    this.timerBackground = timerBackgroundTheme,
    this.timerBackgroundImagePath,
    this.timerFont = timerFontDigital,
  });

  SettingsState copyWith({
    CountryModel? selectedCountry,
    String? selectedLanguage,
    List<CountryModel>? availableCountries,
    List<CategoryModel>? countryCategories,
    bool? isLoadingCountries,
    bool? isLoadingCategories,
    String? errorMessage,
    int? dayResetHour,
    bool? showRestTime,
    bool? wakeNotifications,
    bool? soundEffects,
    List<String>? blockedUsers,
    bool? discordRpcEnabled,
    bool? obsOverlayMode,
    bool? classicYptLook,
    bool? classicTopTabs,
    double? classicUiScale,
    bool? betaChannel,
    String? timerBackground,
    String? timerBackgroundImagePath,
    bool clearTimerBackgroundImagePath = false,
    String? timerFont,
  }) {
    return SettingsState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      availableCountries: availableCountries ?? this.availableCountries,
      countryCategories: countryCategories ?? this.countryCategories,
      isLoadingCountries: isLoadingCountries ?? this.isLoadingCountries,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      errorMessage: errorMessage,
      dayResetHour: dayResetHour ?? this.dayResetHour,
      showRestTime: showRestTime ?? this.showRestTime,
      wakeNotifications: wakeNotifications ?? this.wakeNotifications,
      soundEffects: soundEffects ?? this.soundEffects,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      discordRpcEnabled: discordRpcEnabled ?? this.discordRpcEnabled,
      obsOverlayMode: obsOverlayMode ?? this.obsOverlayMode,
      classicYptLook: classicYptLook ?? this.classicYptLook,
      classicTopTabs: classicTopTabs ?? this.classicTopTabs,
      classicUiScale: classicUiScale ?? this.classicUiScale,
      betaChannel: betaChannel ?? this.betaChannel,
      timerBackground: normalizeTimerBackground(
        timerBackground ?? this.timerBackground,
      ),
      timerBackgroundImagePath: clearTimerBackgroundImagePath
          ? null
          : (timerBackgroundImagePath ?? this.timerBackgroundImagePath),
      timerFont: normalizeTimerFont(timerFont ?? this.timerFont),
    );
  }
}
