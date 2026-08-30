import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/constants/api_constants.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/data/repositories/rank_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/flashcard_repository.dart';
import 'package:desky/data/repositories/auth_repository.dart';
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
    final data = res['data'] is String ? res['data'] as String : jsonEncode(res['data']);
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Etapa 0 - Dynamic API Parameters & Hardcoded Values Fix', () {
    test('GroupRepository.fetchMembers sends dynamic countryId and version', () async {
      String? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        requestedUri = options.uri.toString();
        return {'status': 200, 'data': {'s': true, 'ms': []}};
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = GroupRepository(apiClient: apiClient);
      await repo.fetchMembers(12345, countryId: 99, version: 999999);

      expect(requestedUri, contains('groupID=12345'));
      expect(requestedUri, contains('countryID=99'));
      expect(requestedUri, contains('version=999999'));
    });

    test('GroupRepository.fetchGroupRanks sends dynamic countryId and categoryId', () async {
      String? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        requestedUri = options.uri.toString();
        return {'status': 200, 'data': {'s': true, 'ms': []}};
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = GroupRepository(apiClient: apiClient);
      await repo.fetchGroupRanks(12345, period: 'month', countryId: 55, categoryId: 10);

      expect(requestedUri, contains('countryID=55'));
      expect(requestedUri, contains('categoryID=10'));
      expect(requestedUri, contains('type=month'));
    });

    test('RankRepository.fetchGlobalRanks sends dynamic countryId', () async {
      String? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        requestedUri = options.uri.toString();
        return {'status': 200, 'data': {'s': true, 'ms': []}};
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = RankRepository(apiClient: apiClient);
      await repo.fetchGlobalRanks(period: 'week', categoryId: 7, countryId: 44, page: 2);

      expect(requestedUri, contains('countryID=44'));
      expect(requestedUri, contains('categoryID=7'));
      expect(requestedUri, contains('type=week'));
      expect(requestedUri, contains('page=2'));
    });

    test('TimerRepository.logManualStudy sends dynamic language and deviceModel', () async {
      Map<String, dynamic>? postedData;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        postedData = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : jsonDecode(options.data.toString()) as Map<String, dynamic>;
        return {'status': 200, 'data': {'s': true}};
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = TimerRepository(apiClient: apiClient);
      final start = DateTime(2026, 8, 16, 10, 0);
      final stop = DateTime(2026, 8, 16, 11, 0);

      await repo.logManualStudy(
        subjectId: 101,
        subjectTitle: 'Cálculo',
        startAt: start,
        stopAt: stop,
        language: 'en',
        deviceModel: 'MacBook',
      );

      expect(postedData?['language'], equals('en'));
      expect(postedData?['deviceModel'], equals('MacBook'));
      expect(postedData?['subject_id'], equals(101));
      expect(postedData?['study_ms'], equals(3600000));
    });

    test('SubjectRepository.fetchSubjectsData sends dynamic language and timezone', () async {
      Map<String, dynamic>? postedData;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        postedData = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : jsonDecode(options.data.toString()) as Map<String, dynamic>;
        return {'status': 200, 'data': {'s': true, 'ss': []}};
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = SubjectRepository(apiClient: apiClient);
      await repo.fetchSubjectsData(
        language: 'es',
        timezone: 'Europe/Madrid',
        version: 820000,
      );

      expect(postedData?['language'], equals('es'));
      expect(postedData?['timezone'], equals('Europe/Madrid'));
      expect(postedData?['version'], equals(820000));
      expect(postedData?['deviceModel'], equals(ApiConstants.defaultDeviceModel));
    });

    test('FlashcardRepository.fetchDecks sends dynamic language', () async {
      Map<String, dynamic>? postedData;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        postedData = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : jsonDecode(options.data.toString()) as Map<String, dynamic>;
        return {'status': 200, 'data': {'s': true, 'list': []}};
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = FlashcardRepository(apiClient: apiClient);
      await repo.fetchDecks(language: 'ja');

      expect(postedData?['language'], equals('ja'));
    });

    test('AuthRepository.signInWithEmail sends dynamic language', () async {
      Map<String, dynamic>? signInPayload;
      Map<String, dynamic>? splashPayload;
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter((options) {
        final body = options.data is Map<String, dynamic>
            ? options.data as Map<String, dynamic>
            : jsonDecode(options.data.toString()) as Map<String, dynamic>;

        if (options.path.contains(ApiConstants.signInJwt)) {
          signInPayload = body;
          return {
            'status': 200,
            'data': {
              's': true,
              'jwt': 'fake_jwt_token',
              'id': 1,
              'n': 'Tester',
              'e': 'test@example.com',
            }
          };
        } else {
          splashPayload = body;
          return {
            'status': 200,
            'data': {'s': true, 'gs': []}
          };
        }
      });

      final apiClient = ApiClient(customDio: dio);
      final repo = AuthRepository(apiClient: apiClient);
      await repo.signInWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
        language: 'fr',
      );

      expect(signInPayload?['language'], equals('fr'));
      expect(signInPayload?['email'], equals('test@example.com'));
      expect(splashPayload?['language'], equals('fr'));
    });
  });
}
