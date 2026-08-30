import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/timetable_model.dart';
import 'package:desky/data/repositories/timetable_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;
  Map<String, dynamic>? deleteResponse;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
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
  group('TimetableBlock Model Tests', () {
    test('fromJson and toJson parse attributes accurately', () {
      final json = {
        'id': 1,
        'subject_id': 101,
        'subject_title': 'Física Quântica',
        'color': 4292557552,
        'day_of_week': 2,
        'start_hour': 14,
        'end_hour': 16,
      };

      final block = TimetableBlock.fromJson(json);
      expect(block.id, equals(1));
      expect(block.subjectId, equals(101));
      expect(block.subjectTitle, equals('Física Quântica'));
      expect(block.dayOfWeek, equals(2));
      expect(block.startHour, equals(14));
      expect(block.endHour, equals(16));

      final exported = block.toJson();
      expect(exported['id'], equals(1));
      expect(exported['subject_id'], equals(101));
      expect(exported['subject_title'], equals('Física Quântica'));
    });
  });

  group('TimetableRepository Tests', () {
    late MockApiClient mockApiClient;
    late TimetableRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = TimetableRepository(apiClient: mockApiClient);
    });

    test('fetchTimetable parses API response successfully', () async {
      mockApiClient.getResponse = {
        's': true,
        'timetables': [
          {
            'id': 1,
            'subject_id': 10,
            'subject_title': 'Direito Constitucional',
            'color': 4292557552,
            'day_of_week': 1,
            'start_hour': 8,
            'end_hour': 10,
          },
          {
            'id': 2,
            'subject_id': 20,
            'subject_title': 'Administração Pública',
            'color': 4284388597,
            'day_of_week': 3,
            'start_hour': 19,
            'end_hour': 21,
          },
        ]
      };

      final blocks = await repository.fetchTimetable();
      expect(blocks.length, equals(2));
      expect(blocks.first.subjectTitle, equals('Direito Constitucional'));
      expect(blocks.last.startHour, equals(19));
    });

    test('createBlock sends POST and parses returned TimetableBlock', () async {
      mockApiClient.postResponse = {
        's': true,
        'timetable': {
          'id': 99,
          'subject_id': 12,
          'subject_title': 'Química Geral',
          'color': 4292557552,
          'day_of_week': 4,
          'start_hour': 10,
          'end_hour': 12,
        }
      };

      final block = await repository.createBlock(
        subjectId: 12,
        subjectTitle: 'Química Geral',
        colorInt: 4292557552,
        dayOfWeek: 4,
        startHour: 10,
        endHour: 12,
      );

      expect(block, isNotNull);
      expect(block!.id, equals(99));
      expect(block.subjectTitle, equals('Química Geral'));
      expect(block.dayOfWeek, equals(4));
    });

    test('deleteBlock sends DELETE request', () async {
      mockApiClient.deleteResponse = {'s': true};
      final success = await repository.deleteBlock(99);
      expect(success, isTrue);
    });
  });
}
