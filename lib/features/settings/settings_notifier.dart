import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/country_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../../core/theme/timer_appearance.dart';
import 'settings_state.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs: prefs);
});

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repository);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository)
      : super(SettingsState(selectedLanguage: _repository.getInitialLanguage())) {
    init();
  }

  Future<void> init() async {
    try {
      final country = await _repository.getSavedCountry();
      final language = await _repository.getSavedLanguage();
      final dayResetHour = await _repository.getDayResetHour();
      final showRestTime = await _repository.getShowRestTime();
      final wakeNotifications = await _repository.getWakeNotifications();
      final soundEffects = await _repository.getSoundEffects();
      final blockedUsers = await _repository.getBlockedUsers();
      final discordRpc = await _repository.getDiscordRpcEnabled();
      final betaChannel = await _repository.getBetaChannel();
      final timerBackground = await _repository.getTimerBackground();
      final timerBackgroundImagePath =
          await _repository.getTimerBackgroundImagePath();
      final timerFont = await _repository.getTimerFont();
      if (!mounted) return;
      state = state.copyWith(
        timerBackground: timerBackground,
        timerBackgroundImagePath: timerBackgroundImagePath,
        timerFont: timerFont,
      );
      final obsOverlayMode = await _repository.getObsOverlayMode();
      final classicYptLook = await _repository.getClassicYptLook();
      final classicUiScale = await _repository.getClassicUiScale();

      if (!mounted) return;
      state = state.copyWith(
        selectedCountry: country,
        selectedLanguage: language,
        dayResetHour: dayResetHour,
        showRestTime: showRestTime,
        wakeNotifications: wakeNotifications,
        soundEffects: soundEffects,
        blockedUsers: blockedUsers.isNotEmpty ? blockedUsers : state.blockedUsers,
        discordRpcEnabled: discordRpc,
        obsOverlayMode: obsOverlayMode,
        classicYptLook: classicYptLook,
        classicUiScale: classicUiScale,
        betaChannel: betaChannel,
        timerBackground: timerBackground,
        timerBackgroundImagePath: timerBackgroundImagePath,
        timerFont: timerFont,
        countryCategories: SettingsRepository.defaultFallbackCategories,
        availableCountries: SettingsRepository.defaultFallbackCountries,
      );
    } catch (_) {}
  }

  Future<void> loadCountries() async {
    state = state.copyWith(isLoadingCountries: true, errorMessage: null);
    try {
      final countries = await _repository.fetchCountries();
      if (!mounted) return;
      state = state.copyWith(
        availableCountries: countries,
        isLoadingCountries: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingCountries: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadCategories({int? countryId, String? language}) async {
    final targetCountryId = countryId ?? state.selectedCountry.id;
    final targetLang = language ?? state.selectedLanguage;

    state = state.copyWith(isLoadingCategories: true, errorMessage: null);
    try {
      final categories = await _repository.fetchCategoriesByCountry(
        countryId: targetCountryId,
        language: targetLang,
      );
      if (!mounted) return;
      state = state.copyWith(
        countryCategories: categories,
        isLoadingCategories: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingCategories: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> selectCountry(CountryModel country) async {
    await _repository.saveCountry(country);
    if (!mounted) return;
    state = state.copyWith(selectedCountry: country);
    await loadCategories(countryId: country.id);
  }

  Future<void> selectLanguage(String languageCode) async {
    await _repository.saveLanguage(languageCode);
    if (!mounted) return;
    state = state.copyWith(selectedLanguage: languageCode);
    await loadCategories(language: languageCode);
  }

  Future<void> setDayResetHour(int hour) async {
    state = state.copyWith(dayResetHour: hour);
    await _repository.saveDayResetHour(hour);
  }

  Future<void> toggleShowRestTime(bool value) async {
    state = state.copyWith(showRestTime: value);
    await _repository.saveShowRestTime(value);
  }

  Future<void> toggleWakeNotifications(bool value) async {
    state = state.copyWith(wakeNotifications: value);
    await _repository.saveWakeNotifications(value);
  }

  Future<void> toggleSoundEffects(bool value) async {
    state = state.copyWith(soundEffects: value);
    await _repository.saveSoundEffects(value);
  }

  Future<void> toggleDiscordRpc(bool value) async {
    state = state.copyWith(discordRpcEnabled: value);
    await _repository.saveDiscordRpcEnabled(value);
  }

  Future<void> setTimerBackground(String value) async {
    final normalized = normalizeTimerBackground(value);
    state = state.copyWith(timerBackground: normalized);
    await _repository.saveTimerBackground(normalized);
  }

  Future<void> setTimerBackgroundImage(String path) async {
    state = state.copyWith(
      timerBackground: timerBackgroundCustomImage,
      timerBackgroundImagePath: path,
    );
    await _repository.saveTimerBackgroundImagePath(path);
    await _repository.saveTimerBackground(timerBackgroundCustomImage);
  }

  Future<void> setTimerFont(String value) async {
    final normalized = normalizeTimerFont(value);
    state = state.copyWith(timerFont: normalized);
    await _repository.saveTimerFont(normalized);
  }

  Future<void> toggleObsOverlayMode(bool value) async {
    state = state.copyWith(obsOverlayMode: value);
    await _repository.saveObsOverlayMode(value);
  }

  Future<void> toggleClassicYptLook(bool value) async {
    state = state.copyWith(classicYptLook: value);
    await _repository.saveClassicYptLook(value);
  }

  static const double minUiScale = 0.7;
  static const double maxUiScale = 1.8;

  Future<void> setClassicUiScale(double value) async {
    final clamped = (value.clamp(minUiScale, maxUiScale) * 20).round() / 20;
    if (clamped == state.classicUiScale) return;
    state = state.copyWith(classicUiScale: clamped);
    await _repository.saveClassicUiScale(clamped);
  }

  /// Opts in or out of pre-release update checks.
  Future<void> toggleBetaChannel(bool value) async {
    state = state.copyWith(betaChannel: value);
    await _repository.saveBetaChannel(value);
  }

  Future<void> blockUser(String nickname) async {
    if (nickname.trim().isEmpty || state.blockedUsers.contains(nickname.trim())) return;
    final updated = [...state.blockedUsers, nickname.trim()];
    state = state.copyWith(blockedUsers: updated);
    await _repository.saveBlockedUsers(updated);
  }

  Future<void> unblockUser(String nickname) async {
    final updated = state.blockedUsers.where((u) => u != nickname).toList();
    state = state.copyWith(blockedUsers: updated);
    await _repository.saveBlockedUsers(updated);
  }
}
