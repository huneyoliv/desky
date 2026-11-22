import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../features/updates/update_channel.dart';
import '../../core/theme/timer_appearance.dart';
import '../models/category_model.dart';
import '../models/country_model.dart';

class SettingsRepository {
  final ApiClient _apiClient;
  final SharedPreferences? _prefs;

  SettingsRepository({
    ApiClient? apiClient,
    SharedPreferences? prefs,
  })  : _apiClient = apiClient ?? ApiClient(),
        _prefs = prefs;

  static const String keyCountryId = 'selected_country_id';
  static const String keyCountryCode = 'selected_country_code';
  static const String keyCountryName = 'selected_country_name';
  static const String keyTimezone = 'selected_timezone';
  static const String keyGmtOffset = 'selected_gmt_offset';
  static const String keyStartTime = 'selected_start_time';
  static const String keyLanguage = 'selected_language';
  static const String keyDayResetHour = 'day_reset_hour';
  static const String keyShowRestTime = 'show_rest_time';
  static const String keyWakeNotifications = 'wake_notifications';
  static const String keySoundEffects = 'sound_effects';
  static const String keyBlockedUsers = 'blocked_users_list';
  static const String keyDiscordRpc = 'discord_rpc_enabled';
  static const String keyObsOverlayMode = 'obs_overlay_mode';
  static const String keyClassicYptLook = 'classic_ypt_look';
  static const String keyClassicUiScale = 'classic_ui_scale';
  static const String keyMiniOpacity = 'mini_opacity';
  static const String keyOfflineMode = 'offline_mode';
  static const String keyDialStudy = 'dial_study_color';
  static const String keyDialBreak = 'dial_break_color';
  static const String keyDialShow = 'dial_show_stopwatch';
  static const String keyThemePreset = 'selected_theme_preset';
  static const String keyDarkThemePreset = 'selected_dark_theme_preset';
  static const String keyLightThemePreset = 'selected_light_theme_preset';
  static const String keyBetaChannel = 'beta_update_channel';
  static const String keyTimerBackground = 'timer_background_style';
  static const String keyTimerBackgroundImagePath = 'timer_background_image_path';
  static const String keyTimerFont = 'timer_font_family';

  static const CountryModel defaultCountry = CountryModel(
    id: 23,
    name: 'BRAZIL',
    code: 'BR',
    timezone: 'America/Sao_Paulo',
    continent: 'South America',
    gmtOffset: -3,
    startTime: '5 AM',
  );

  static const List<CountryModel> defaultFallbackCountries = [
    CountryModel(id: 23, name: 'BRAZIL', code: 'BR', timezone: 'America/Sao_Paulo', continent: 'South America'),
    CountryModel(id: 1, name: 'UNITED STATES', code: 'US', timezone: 'America/New_York', continent: 'North America'),
    CountryModel(id: 82, name: 'SOUTH KOREA', code: 'KR', timezone: 'Asia/Seoul', continent: 'Asia'),
    CountryModel(id: 81, name: 'JAPAN', code: 'JP', timezone: 'Asia/Tokyo', continent: 'Asia'),
    CountryModel(id: 86, name: 'CHINA', code: 'CN', timezone: 'Asia/Shanghai', continent: 'Asia'),
    CountryModel(id: 44, name: 'UNITED KINGDOM', code: 'GB', timezone: 'Europe/London', continent: 'Europe'),
    CountryModel(id: 351, name: 'PORTUGAL', code: 'PT', timezone: 'Europe/Lisbon', continent: 'Europe'),
    CountryModel(id: 34, name: 'SPAIN', code: 'ES', timezone: 'Europe/Madrid', continent: 'Europe'),
    CountryModel(id: 33, name: 'FRANCE', code: 'FR', timezone: 'Europe/Paris', continent: 'Europe'),
    CountryModel(id: 49, name: 'GERMANY', code: 'DE', timezone: 'Europe/Berlin', continent: 'Europe'),
    CountryModel(id: 39, name: 'ITALY', code: 'IT', timezone: 'Europe/Rome', continent: 'Europe'),
    CountryModel(id: 2, name: 'CANADA', code: 'CA', timezone: 'America/Toronto', continent: 'North America'),
    CountryModel(id: 52, name: 'MEXICO', code: 'MX', timezone: 'America/Mexico_City', continent: 'North America'),
    CountryModel(id: 54, name: 'ARGENTINA', code: 'AR', timezone: 'America/Argentina/Buenos_Aires', continent: 'South America'),
    CountryModel(id: 56, name: 'CHILE', code: 'CL', timezone: 'America/Santiago', continent: 'South America'),
    CountryModel(id: 57, name: 'COLOMBIA', code: 'CO', timezone: 'America/Bogota', continent: 'South America'),
    CountryModel(id: 51, name: 'PERU', code: 'PE', timezone: 'America/Lima', continent: 'South America'),
    CountryModel(id: 61, name: 'AUSTRALIA', code: 'AU', timezone: 'Australia/Sydney', continent: 'Oceania'),
    CountryModel(id: 91, name: 'INDIA', code: 'IN', timezone: 'Asia/Kolkata', continent: 'Asia'),
    CountryModel(id: 62, name: 'INDONESIA', code: 'ID', timezone: 'Asia/Jakarta', continent: 'Asia'),
    CountryModel(id: 84, name: 'VIETNAM', code: 'VN', timezone: 'Asia/Ho_Chi_Minh', continent: 'Asia'),
    CountryModel(id: 63, name: 'PHILIPPINES', code: 'PH', timezone: 'Asia/Manila', continent: 'Asia'),
    CountryModel(id: 90, name: 'TURKEY', code: 'TR', timezone: 'Europe/Istanbul', continent: 'Europe'),
    CountryModel(id: 7, name: 'RUSSIA', code: 'RU', timezone: 'Europe/Moscow', continent: 'Europe'),
    CountryModel(id: 966, name: 'SAUDI ARABIA', code: 'SA', timezone: 'Asia/Riyadh', continent: 'Middle East'),
    CountryModel(id: 971, name: 'UNITED ARAB EMIRATES', code: 'AE', timezone: 'Asia/Dubai', continent: 'Middle East'),
    CountryModel(id: 20, name: 'EGYPT', code: 'EG', timezone: 'Africa/Cairo', continent: 'Africa'),
    CountryModel(id: 27, name: 'SOUTH AFRICA', code: 'ZA', timezone: 'Africa/Johannesburg', continent: 'Africa'),
    CountryModel(id: 234, name: 'NIGERIA', code: 'NG', timezone: 'Africa/Lagos', continent: 'Africa'),
    CountryModel(id: 77, name: 'KAZAKHSTAN', code: 'KZ', timezone: 'Asia/Almaty', continent: 'Central Asia'),
  ];

  Future<List<CountryModel>> fetchCountries() async {
    try {
      final response = await _apiClient.get(
        '/category/countries',
        baseUrl: ApiConstants.metadataCdnUrl,
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true && data['cs'] is List) {
        final list = (data['cs'] as List)
            .map((e) => CountryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    try {
      final response = await _apiClient.get(
        '/category/countries',
        baseUrl: ApiConstants.baseUrl,
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true && data['cs'] is List) {
        final list = (data['cs'] as List)
            .map((e) => CountryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return defaultFallbackCountries;
  }

  static const List<CategoryModel> defaultFallbackCategories = [
    CategoryModel(id: 198, title: 'Ensino Fundamental I', shortTitle: 'EF1', order: 1, section: 'Estudantes'),
    CategoryModel(id: 199, title: 'Ensino Fundamental II', shortTitle: 'EF2', order: 2, section: 'Estudantes'),
    CategoryModel(id: 432, title: 'Ensino Médio – 1º ano', shortTitle: 'EM1', order: 3, section: 'Estudantes'),
    CategoryModel(id: 433, title: 'Ensino Médio – 2º ano', shortTitle: 'EM2', order: 4, section: 'Estudantes'),
    CategoryModel(id: 200, title: 'Ensino Médio – 3º ano (ENEM/Vestibular)', shortTitle: 'EM3-ENEM', order: 11, section: 'Estudantes'),
    CategoryModel(id: 434, title: 'Ensino Médio – 3º ano (ITA/IME)', shortTitle: 'EM3-ITA/IME', order: 11, section: 'Estudantes'),
    CategoryModel(id: 435, title: 'Repetente – ENEM/Vestibular', shortTitle: 'REP-ENEM', order: 12, section: 'Estudantes'),
    CategoryModel(id: 436, title: 'Repetente – ITA/IME', shortTitle: 'REP-ITA/IME', order: 13, section: 'Estudantes'),
    CategoryModel(id: 201, title: 'Estudante de Graduação', shortTitle: 'Graduação', order: 21, section: 'Universidade e Carreira'),
    CategoryModel(id: 438, title: 'Estudante de Pós-graduação', shortTitle: 'Pós-graduação', order: 22, section: 'Universidade e Carreira'),
    CategoryModel(id: 439, title: 'Concurso Público', shortTitle: 'Concurso', order: 31, section: 'Concursos Públicos'),
    CategoryModel(id: 440, title: 'Magistério', shortTitle: 'Magistério', order: 32, section: 'Concursos Públicos'),
    CategoryModel(id: 441, title: 'Ordem dos Advogados do Brasil', shortTitle: 'OAB', order: 41, section: 'Exames Profissionais'),
    CategoryModel(id: 442, title: 'Exame do CFC', shortTitle: 'CFC', order: 42, section: 'Exames Profissionais'),
    CategoryModel(id: 202, title: 'Estudo de Idiomas', shortTitle: 'Idiomas', order: 52, section: 'Outros'),
    CategoryModel(id: 443, title: 'Leitura', shortTitle: 'Leitura', order: 53, section: 'Outros'),
    CategoryModel(id: 444, title: 'Preparação para Certificação', shortTitle: 'Certificação', order: 54, section: 'Outros'),
    CategoryModel(id: 203, title: 'Outros', shortTitle: 'Outros', order: 55, section: 'Outros'),
  ];

  Future<List<CategoryModel>> fetchCategoriesByCountry({
    required int countryId,
    required String language,
  }) async {
    try {
      final response = await _apiClient.get(
        '/category/category-by-country',
        baseUrl: ApiConstants.metadataCdnUrl,
        queryParameters: {
          'country_id': countryId,
          'countryID': countryId,
          'language': language,
          'lang': language,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true && data['cs'] is List) {
        final list = (data['cs'] as List)
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      try {
        final response = await _apiClient.get(
          '/category/category-by-country',
          baseUrl: ApiConstants.baseUrl,
          queryParameters: {
            'country_id': countryId,
            'countryID': countryId,
            'language': language,
            'lang': language,
          },
        );
        final data = response.data;
        if (data is Map<String, dynamic> && data['s'] == true && data['cs'] is List) {
          final list = (data['cs'] as List)
              .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return defaultFallbackCategories;
  }

  Future<CountryModel> getSavedCountry() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final id = prefs.getInt(keyCountryId);
      if (id == null) return defaultCountry;

      return CountryModel(
        id: id,
        name: prefs.getString(keyCountryName) ?? defaultCountry.name,
        code: prefs.getString(keyCountryCode) ?? defaultCountry.code,
        timezone: prefs.getString(keyTimezone) ?? defaultCountry.timezone,
        continent: '',
        gmtOffset: prefs.getDouble(keyGmtOffset) ?? defaultCountry.gmtOffset,
        startTime: prefs.getString(keyStartTime) ?? defaultCountry.startTime,
      );
    } catch (_) {
      return defaultCountry;
    }
  }

  Future<void> saveCountry(CountryModel country) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt(keyCountryId, country.id);
      await prefs.setString(keyCountryName, country.name);
      await prefs.setString(keyCountryCode, country.code);
      await prefs.setString(keyTimezone, country.timezone);
      if (country.gmtOffset != null) {
        await prefs.setDouble(keyGmtOffset, country.gmtOffset!);
      }
      if (country.startTime != null) {
        await prefs.setString(keyStartTime, country.startTime!);
      }
    } catch (_) {}
  }

  String getInitialLanguage() {
    try {
      if (_prefs != null) {
        final saved = _prefs!.getString(keyLanguage);
        if (saved != null && saved.isNotEmpty) {
          return saved;
        }
      }
    } catch (_) {}

    return 'pt';
  }

  Future<String> getSavedLanguage() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final saved = prefs.getString(keyLanguage);
      if (saved != null && saved.isNotEmpty) {
        return saved;
      }
    } catch (_) {}

    return 'pt';
  }

  Future<void> saveLanguage(String languageCode) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(keyLanguage, languageCode);
    } catch (_) {}
  }

  Future<int> getDayResetHour() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getInt(keyDayResetHour) ?? 5;
    } catch (_) {
      return 5;
    }
  }

  Future<void> saveDayResetHour(int hour) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt(keyDayResetHour, hour);
    } catch (_) {}
  }

  Future<bool> getShowRestTime() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyShowRestTime) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveShowRestTime(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyShowRestTime, value);
    } catch (_) {}
  }

  Future<bool> getWakeNotifications() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyWakeNotifications) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveWakeNotifications(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyWakeNotifications, value);
    } catch (_) {}
  }

  Future<bool> getSoundEffects() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keySoundEffects) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveSoundEffects(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keySoundEffects, value);
    } catch (_) {}
  }

  /// Whether update checks should include pre-releases.
  ///
  /// When the user never touched the toggle, the default follows the running
  /// build: a pre-release build keeps the beta channel, a stable build does not.
  Future<bool> getBetaChannel() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyBetaChannel) ??
          UpdateChannel.defaultEnabledFor(AppConstants.appVersion);
    } catch (_) {
      return UpdateChannel.defaultEnabledFor(AppConstants.appVersion);
    }
  }

  Future<void> saveBetaChannel(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyBetaChannel, value);
    } catch (_) {}
  }

  Future<List<String>> getBlockedUsers() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getStringList(keyBlockedUsers) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBlockedUsers(List<String> users) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setStringList(keyBlockedUsers, users);
    } catch (_) {}
  }

  Future<bool> getDiscordRpcEnabled() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyDiscordRpc) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveDiscordRpcEnabled(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyDiscordRpc, value);
    } catch (_) {}
  }

  Future<bool> getObsOverlayMode() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyObsOverlayMode) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveObsOverlayMode(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyObsOverlayMode, value);
    } catch (_) {}
  }

  Future<String> getTimerBackground() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return normalizeTimerBackground(prefs.getString(keyTimerBackground));
    } catch (_) {
      return timerBackgroundTheme;
    }
  }

  Future<void> saveTimerBackground(String value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(keyTimerBackground, normalizeTimerBackground(value));
    } catch (_) {}
  }

  Future<String?> getTimerBackgroundImagePath() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final path = prefs.getString(keyTimerBackgroundImagePath)?.trim();
      return path == null || path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTimerBackgroundImagePath(String? path) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (path == null || path.trim().isEmpty) {
        await prefs.remove(keyTimerBackgroundImagePath);
      } else {
        await prefs.setString(keyTimerBackgroundImagePath, path.trim());
      }
    } catch (_) {}
  }

  Future<String> getTimerFont() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return normalizeTimerFont(prefs.getString(keyTimerFont));
    } catch (_) {
      return timerFontDigital;
    }
  }

  Future<void> saveTimerFont(String value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(keyTimerFont, normalizeTimerFont(value));
    } catch (_) {}
  }

  Future<bool> getClassicYptLook() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyClassicYptLook) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveClassicYptLook(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyClassicYptLook, value);
    } catch (_) {}
  }

  Future<double> getClassicUiScale() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getDouble(keyClassicUiScale) ?? 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> saveClassicUiScale(double value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setDouble(keyClassicUiScale, value);
    } catch (_) {}
  }

  Future<double> getMiniOpacity() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getDouble(keyMiniOpacity) ?? 0.95;
    } catch (_) {
      return 0.95;
    }
  }

  Future<void> saveMiniOpacity(double value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setDouble(keyMiniOpacity, value);
    } catch (_) {}
  }

  Future<({int study, int rest, bool show})> getDialStyle() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return (
        study: prefs.getInt(keyDialStudy) ?? 0xFFFF6B1A,
        rest: prefs.getInt(keyDialBreak) ?? 0xFF2F7CF6,
        show: prefs.getBool(keyDialShow) ?? true,
      );
    } catch (_) {
      return (study: 0xFFFF6B1A, rest: 0xFF2F7CF6, show: true);
    }
  }

  Future<void> saveDialStyle({required int study, required int rest, required bool show}) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt(keyDialStudy, study);
      await prefs.setInt(keyDialBreak, rest);
      await prefs.setBool(keyDialShow, show);
    } catch (_) {}
  }

  Future<bool> getOfflineMode() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(keyOfflineMode) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveOfflineMode(bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(keyOfflineMode, value);
    } catch (_) {}
  }

  Future<String> getThemePresetId() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getString(keyThemePreset) ?? 'amoled_lilac';
    } catch (_) {
      return 'amoled_lilac';
    }
  }

  String getInitialThemePresetId() {
    try {
      return _prefs?.getString(keyThemePreset) ?? 'amoled_lilac';
    } catch (_) {
      return 'amoled_lilac';
    }
  }

  Future<void> saveThemePresetId(String themeId) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(keyThemePreset, themeId);
    } catch (_) {}
  }

  Future<String> getDarkThemePresetId() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(keyDarkThemePreset) ?? 'amoled_lilac';
  }

  Future<String> getLightThemePresetId() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(keyLightThemePreset) ?? 'daylight_lilac';
  }

  Future<void> saveSystemThemePresetIds({
    required String darkId,
    required String lightId,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(keyDarkThemePreset, darkId);
    await prefs.setString(keyLightThemePreset, lightId);
  }
}
