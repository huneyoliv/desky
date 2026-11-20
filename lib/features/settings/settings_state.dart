import '../../data/models/category_model.dart';
import '../../data/models/country_model.dart';
import '../../data/repositories/settings_repository.dart';

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

  /// Windows: minimizing sends the window behind the others instead of
  /// really minimizing it, so an OBS Window Capture keeps receiving frames.
  final bool obsOverlayMode;

  /// Layout modelled on the YPT desktop app: top tabs instead of the sidebar.
  final bool classicYptLook;

  /// Zoom of the Classic look (1.0 = 100 %), changed with Ctrl +/- or Ctrl + wheel.
  final double classicUiScale;

  /// Opacity of the floating mini player (0.3 to 1.0).
  final double miniOpacity;
  final bool betaChannel;

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
    this.classicUiScale = 1.0,
    this.miniOpacity = 0.95,
    this.betaChannel = false,
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
    double? classicUiScale,
    double? miniOpacity,
    bool? betaChannel,
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
      classicUiScale: classicUiScale ?? this.classicUiScale,
      miniOpacity: miniOpacity ?? this.miniOpacity,
      betaChannel: betaChannel ?? this.betaChannel,
    );
  }
}
