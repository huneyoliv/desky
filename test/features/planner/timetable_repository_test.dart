import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
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
  group('TimetableRepository Tests', () {
    late MockApiClient mockApiClient;
    late TimetableRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = TimetableRepository(apiClient: mockApiClient);
    });

    test('fetchTimetable parses blocks list correctly', () async {
      mockApiClient.getResponse = {
        's': true,
        'timetables': [
          {
            'id': 1,
            'subject_id': 100,
            'subject_title': 'Física',
            'color': 4292557552,
            'day_of_week': 2,
            'start_hour': 9,
            'end_hour': 11,
          }
        ]
      };

      final list = await repository.fetchTimetable();

      expect(list.length, 1);
      expect(list.first.subjectTitle, 'Física');
      expect(list.first.dayOfWeek, 2);
    });

    test('createBlock creates and parses block', () async {
      mockApiClient.postResponse = {
        's': true,
        'timetable': {
          'id': 5,
          'subject_id': 101,
          'subject_title': 'Química',
          'color': 4292557552,
          'day_of_week': 4,
          'start_hour': 13,
          'end_hour': 15,
        }
      };

      final block = await repository.createBlock(
        subjectId: 101,
        subjectTitle: 'Química',
        colorInt: 4292557552,
        dayOfWeek: 4,
        startHour: 13,
        endHour: 15,
      );

      expect(block, isNotNull);
      expect(block!.id, 5);
      expect(block.subjectTitle, 'Química');
    });

    test('deleteBlock returns true on success', () async {
      mockApiClient.deleteResponse = {'s': true};

      final result = await repository.deleteBlock(5);

      expect(result, isTrue);
    });
  });
}
