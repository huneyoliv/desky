import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/utils/study_date_helper.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;

  /// Records every request as `METHOD path` plus the decoded body, so the
  /// tests assert the real contract and not just the parsed result.
  final List<Map<String, dynamic>> calls = [];

  Map<String, dynamic>? bodyOf(String method, String pathPart) {
    for (final call in calls) {
      if (call['method'] == method &&
          (call['path'] as String).contains(pathPart)) {
        return call['body'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
    calls.add({'method': 'GET', 'path': path, 'body': null});
    return Response(
      requestOptions: RequestOptions(path: path),
      data: getResponse,
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    calls.add({
      'method': 'POST',
      'path': path,
      'body': data is Map<String, dynamic> ? data : null,
    });
    return Response(
      requestOptions: RequestOptions(path: path),
      data: postResponse,
      statusCode: 200,
    );
  }
}

void main() {
  group('D-Day Model & Calculation Tests', () {
    test('future date generates D-X label correctly', () {
      final studyToday = StudyDateHelper.getStudyDate();
      final targetDate = studyToday.add(const Duration(days: 15));

      final dday = DDayModel(
        id: 1,
        title: 'Exame Final',
        targetDate: targetDate,
        colorInt: 4294948685,
      );

      expect(dday.daysRemaining, equals(15));
      expect(dday.label, equals('D-15'));
    });

    test('today target date generates D-DAY label', () {
      final studyToday = StudyDateHelper.getStudyDate();

      final dday = DDayModel(
        id: 2,
        title: 'Dia da Prova',
        targetDate: studyToday,
        colorInt: 4294948685,
      );

      expect(dday.daysRemaining, equals(0));
      expect(dday.label, equals('D-DAY'));
    });

    test('past target date generates D+X label', () {
      final studyToday = StudyDateHelper.getStudyDate();
      final pastDate = studyToday.subtract(const Duration(days: 7));

      final dday = DDayModel(
        id: 3,
        title: 'Início do Semestre',
        targetDate: pastDate,
        colorInt: 4294948685,
      );

      expect(dday.daysRemaining, equals(-7));
      expect(dday.label, equals('D+7'));
    });

    test('fromJson reads the compact live keys tt and dt', () {
      // Exact shape observed from POST /user/d-day/create.
      final model = DDayModel.fromJson({
        'id': 9369115,
        'tt': 'QA',
        'dt': '2026-12-01',
        'st': null,
      });

      expect(model.id, equals(9369115));
      expect(model.title, equals('QA'));
      expect(model.targetDate, equals(DateTime(2026, 12, 1)));
    });

    test('fromJson still accepts the verbose keys', () {
      final model = DDayModel.fromJson({
        'id': 10,
        'title': 'Ano Novo',
        'targetDate': DateTime(2026, 12, 31).toIso8601String(),
        'color': 4284388597,
      });

      expect(model.id, equals(10));
      expect(model.title, equals('Ano Novo'));
      expect(model.colorInt, equals(4284388597));

      final exported = model.toJson();
      expect(exported['id'], equals(10));
      expect(exported['title'], equals('Ano Novo'));
      expect(exported['color'], equals(4284388597));
    });

    test('fromJson tolerates a missing id and missing date', () {
      final model = DDayModel.fromJson({'tt': 'Sem Id'});
      expect(model.id, equals(0));
      expect(model.title, equals('Sem Id'));
      expect(model.targetDate, isA<DateTime>());
    });
  });

  group('PlannerRepository D-Day CRUD Tests', () {
    late MockApiClient mockApiClient;
    late PlannerRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = PlannerRepository(apiClient: mockApiClient);
    });

    test('createDDay posts to /user/d-day/create with title and date', () async {
      mockApiClient.postResponse = {
        's': true,
        'd': {'id': 42, 'tt': 'Concurso Público', 'dt': '2026-11-20', 'st': null},
      };

      final result = await repository.createDDay(
        title: 'Concurso Público',
        targetDate: DateTime(2026, 11, 20),
        colorInt: 4294948685,
      );

      expect(result, isNotNull);
      expect(result!.id, equals(42));
      expect(result.title, equals('Concurso Público'));

      final body = mockApiClient.bodyOf('POST', '/user/d-day/create');
      expect(body, isNotNull);
      expect(body!['title'], equals('Concurso Público'));
      expect(body['date'], equals('2026-11-20'));
      // The live contract requires `date`; `targetDate` is silently rejected.
      expect(body.containsKey('targetDate'), isFalse);
    });

    test('createDDay pads a single-digit month and day', () async {
      mockApiClient.postResponse = {'s': true};
      await repository.createDDay(
        title: 'Prova',
        targetDate: DateTime(2027, 3, 7),
        colorInt: 4294948685,
      );
      final body = mockApiClient.bodyOf('POST', '/user/d-day/create');
      expect(body!['date'], equals('2027-03-07'));
    });

    test('createDDay returns null when the server refuses', () async {
      mockApiClient.postResponse = {'s': false};
      final result = await repository.createDDay(
        title: 'Prova',
        targetDate: DateTime(2026, 11, 20),
        colorInt: 4294948685,
      );
      expect(result, isNull);
    });

    test('deleteDDay posts the id to /user/d-day/delete', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.deleteDDay(42);
      expect(result, isTrue);

      final body = mockApiClient.bodyOf('POST', '/user/d-day/delete');
      expect(body, isNotNull);
      expect(body!['id'], equals(42));
    });

    test('deleteDDay returns false when the server refuses', () async {
      mockApiClient.postResponse = {'s': false};
      expect(await repository.deleteDDay(42), isFalse);
    });

    test('fetchDDays reads the list defensively from /user/d-day/get',
        () async {
      mockApiClient.getResponse = {
        's': true,
        'ddays': [
          {'id': 7, 'tt': 'Enem', 'dt': '2026-12-01'},
        ],
      };

      final result = await repository.fetchDDays();

      expect(result, hasLength(1));
      expect(result.first.id, equals(7));
      expect(result.first.title, equals('Enem'));
      expect(mockApiClient.calls.any((c) =>
              c['method'] == 'GET' &&
              (c['path'] as String).contains('/user/d-day/get')),
          isTrue);
    });

    test('fetchDDays returns an empty list when the payload has no key',
        () async {
      // `GET /user/d-day/get` really answers a bare {"s": true}.
      mockApiClient.getResponse = {'s': true};
      expect(await repository.fetchDDays(), isEmpty);
    });
  });
}
