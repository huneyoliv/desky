import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/country_model.dart';
import '../../data/repositories/settings_repository.dart';
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

      if (!mounted) return;
      state = state.copyWith(
        selectedCountry: country,
        selectedLanguage: language,
        dayResetHour: dayResetHour,
        showRestTime: showRestTime,
        wakeNotifications: wakeNotifications,
        soundEffects: soundEffects,
        blockedUsers: blockedUsers.isNotEmpty ? blockedUsers : state.blockedUsers,
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
