import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/utils/study_date_helper.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? postResponse;
  Map<String, dynamic>? deleteResponse;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: postResponse,
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: deleteResponse,
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

    test('fromJson and toJson work symmetrically', () {
      final targetDate = DateTime(2026, 12, 31);
      final json = {
        'id': 10,
        'title': 'Ano Novo',
        'targetDate': targetDate.toIso8601String(),
        'color': 4284388597,
      };

      final model = DDayModel.fromJson(json);
      expect(model.id, equals(10));
      expect(model.title, equals('Ano Novo'));
      expect(model.colorInt, equals(4284388597));

      final exported = model.toJson();
      expect(exported['id'], equals(10));
      expect(exported['title'], equals('Ano Novo'));
      expect(exported['color'], equals(4284388597));
    });
  });

  group('PlannerRepository D-Day CRUD Tests', () {
    late MockApiClient mockApiClient;
    late PlannerRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = PlannerRepository(apiClient: mockApiClient);
    });

    test('createDDay sends POST to /planner/dday and parses result', () async {
      mockApiClient.postResponse = {
        's': true,
        'dday': {
          'id': 42,
          'title': 'Concurso Público',
          'targetDate': '2026-11-20T00:00:00.000Z',
          'color': 4294948685,
        }
      };

      final result = await repository.createDDay(
        title: 'Concurso Público',
        targetDate: DateTime(2026, 11, 20),
        colorInt: 4294948685,
      );

      expect(result, isNotNull);
      expect(result!.id, equals(42));
      expect(result.title, equals('Concurso Público'));
    });

    test('deleteDDay sends DELETE to /planner/dday/:id', () async {
      mockApiClient.deleteResponse = {'s': true};
      final result = await repository.deleteDDay(42);
      expect(result, isTrue);
    });
  });
}
