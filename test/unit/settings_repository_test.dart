import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/category_model.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = handler(options);
    final status = res['status'] as int? ?? 200;
    final data = res['data'] as String;
    return ResponseBody.fromString(
      data,
      status,
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

  group('CountryModel & CategoryModel Tests', () {
    test('CountryModel.fromJson parses complete data correctly', () {
      final json = {
        'id': 1,
        't': 'SOUTH KOREA',
        'c': 'KR',
        'tz': 'Asia/Seoul',
        'con': 'Asia',
        'g': 9.0,
        'st': '5 AM KST',
      };
      final country = CountryModel.fromJson(json);
      expect(country.id, 1);
      expect(country.name, 'SOUTH KOREA');
      expect(country.formattedName, 'South Korea');
      expect(country.code, 'KR');
      expect(country.timezone, 'Asia/Seoul');
      expect(country.continent, 'Asia');
      expect(country.gmtOffset, 9.0);
      expect(country.gmtDisplay, 'GMT+9');
      expect(country.startTime, '5 AM KST');
    });

    test('CountryModel.fromJson applies default values for missing fields', () {
      final country = CountryModel.fromJson({});
      expect(country.id, 0);
      expect(country.name, '');
      expect(country.code, 'BR');
      expect(country.timezone, 'America/Sao_Paulo');
      expect(country.continent, '');
    });

    test('CategoryModel.fromJson parses correctly', () {
      final json = {
        'id': 439,
        'tt': 'Concurso',
        't': 'CC',
        'o': 10,
        'sc': 'Geral',
      };
      final category = CategoryModel.fromJson(json);
      expect(category.id, 439);
      expect(category.title, 'Concurso');
      expect(category.shortTitle, 'CC');
      expect(category.order, 10);
      expect(category.section, 'Geral');
    });
  });

  group('SettingsRepository Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('fetchCountries parses API response successfully', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, contains('/category/countries'));
        return {
          'status': 200,
          'data': '{"s":true,"cs":[{"id":23,"t":"BRAZIL","c":"BR","tz":"America/Sao_Paulo","con":"South America"}]}',
        };
      });

      final repo = SettingsRepository(
        apiClient: ApiClient(customDio: dio),
        prefs: prefs,
      );

      final countries = await repo.fetchCountries();
      expect(countries.length, 1);
      expect(countries.first.name, 'BRAZIL');
      expect(countries.first.code, 'BR');
    });

    test('fetchCategoriesByCountry parses API response successfully', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, contains('/category/category-by-country'));
        expect(options.queryParameters['country_id'], 23);
        expect(options.queryParameters['language'], 'pt');
        return {
          'status': 200,
          'data': '{"s":true,"cs":[{"id":198,"tt":"Ensino Fundamental","t":"EF","o":1,"sc":"Estudantes"}]}',
        };
      });

      final repo = SettingsRepository(
        apiClient: ApiClient(customDio: dio),
        prefs: prefs,
      );

      final categories = await repo.fetchCategoriesByCountry(
        countryId: 23,
        language: 'pt',
      );
      expect(categories.length, 1);
      expect(categories.first.title, 'Ensino Fundamental');
      expect(categories.first.id, 198);
    });

    test('fetchCountries returns fallback countries on server error', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        return {
          'status': 500,
          'data': '{"s":false,"m":"Erro interno no servidor"}',
        };
      });

      final repo = SettingsRepository(
        apiClient: ApiClient(customDio: dio),
        prefs: prefs,
      );

      final countries = await repo.fetchCountries();
      expect(countries.isNotEmpty, true);
      expect(countries.any((c) => c.code == 'BR'), true);
    });

    test('saveCountry and getSavedCountry persist correctly', () async {
      final repo = SettingsRepository(prefs: prefs);
      const newCountry = CountryModel(
        id: 2,
        name: 'JAPAN',
        code: 'JP',
        timezone: 'Asia/Tokyo',
        continent: 'Asia',
      );

      await repo.saveCountry(newCountry);
      final saved = await repo.getSavedCountry();

      expect(saved.id, 2);
      expect(saved.name, 'JAPAN');
      expect(saved.code, 'JP');
      expect(saved.timezone, 'Asia/Tokyo');
    });

    test('saveLanguage and getSavedLanguage persist correctly', () async {
      final repo = SettingsRepository(prefs: prefs);
      await repo.saveLanguage('ja');
      final saved = await repo.getSavedLanguage();
      expect(saved, 'ja');
    });
  });
}
