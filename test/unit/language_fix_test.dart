import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDioWithQueryAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastQueryParams;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastQueryParams = options.queryParameters;
    return ResponseBody.fromString(
      '{"s": true, "cs": [{"id": 1, "name": "Concursos", "country_id": 23}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Language and Translation Fix Tests', () {
    test('AppTranslation normalizeCode formats language codes correctly', () {
      expect(AppTranslation.normalizeCode('pt'), 'pt');
      expect(AppTranslation.normalizeCode('en'), 'en');
      expect(AppTranslation.normalizeCode('zh_hans'), 'zh-CN');
      expect(AppTranslation.normalizeCode('zh-CN'), 'zh-CN');
      expect(AppTranslation.normalizeCode('zh_hant'), 'zh-TW');
      expect(AppTranslation.normalizeCode('zh-TW'), 'zh-TW');
    });

    test('AppTranslation tr replaces placeholder arguments', () {
      const translation = AppTranslation(
        languageCode: 'pt',
        translations: {
          'welcome_user': 'Bem-vindo, {}!',
          'study_summary': 'Estudou {} horas e {} minutos',
        },
      );

      expect(translation.tr('welcome_user', args: ['Gabriel']), 'Bem-vindo, Gabriel!');
      expect(translation.tr('study_summary', args: ['2', '30']), 'Estudou 2 horas e 30 minutos');
      expect(translation.tr('non_existing_key', fallback: 'Padrão'), 'Padrão');
    });

    test('SettingsRepository fetchCategoriesByCountry sends both lang and language query params', () async {
      final dio = Dio();
      final adapter = MockDioWithQueryAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = SettingsRepository(apiClient: apiClient);
      final result = await repo.fetchCategoriesByCountry(countryId: 23, language: 'ko');

      expect(result.length, 1);
      expect(adapter.lastQueryParams?['lang'], 'ko');
      expect(adapter.lastQueryParams?['language'], 'ko');
      expect(adapter.lastQueryParams?['countryID'], 23);
      expect(adapter.lastQueryParams?['country_id'], 23);
    });

    test('SettingsRepository saveLanguage and getSavedLanguage persist code', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository();

      await repo.saveLanguage('ja');
      final saved = await repo.getSavedLanguage();
      expect(saved, 'ja');
    });
  });
}
