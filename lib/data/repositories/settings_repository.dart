import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
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
  static const String keyLanguage = 'selected_language';
  static const String keyDayResetHour = 'day_reset_hour';
  static const String keyShowRestTime = 'show_rest_time';
  static const String keyWakeNotifications = 'wake_notifications';
  static const String keySoundEffects = 'sound_effects';
  static const String keyBlockedUsers = 'blocked_users_list';
  static const String keyDiscordRpc = 'discord_rpc_enabled';

  static const CountryModel defaultCountry = CountryModel(
    id: 23,
    name: 'BRAZIL',
    code: 'BR',
    timezone: 'America/Sao_Paulo',
    continent: 'South America',
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
}
