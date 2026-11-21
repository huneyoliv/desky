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

  @override
  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    calls.add({
      'method': 'DELETE',
      'path': path,
      'body': data is Map<String, dynamic> ? data : null,
    });
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

    test('createBlock posts to the detail route with compact keys', () async {
      mockApiClient.getResponse = {
        's': true,
        'rt': [{'id': 5323504, 't': 'teste'}],
      };
      mockApiClient.postResponse = {'s': false};

      final block = await repository.createBlock(
        subjectId: 12,
        subjectTitle: 'Química Geral',
        colorInt: 4292557552,
        dayOfWeek: 4,
        startHour: 10,
        endHour: 12,
      );

      final body = mockApiClient.bodyOf('POST', '/timetable/detail/v70630');
      expect(body, isNotNull);
      expect(body!['ttid'], equals(5323504));
      // The server validates the title as `t`; sending `title` is rejected
      // with "title is required".
      expect(body['t'], equals('Química Geral'));
      expect(body['lw'], equals(4));
      expect(body['st'], equals('10:00:00'));
      expect(body['et'], equals('12:00:00'));
      expect(body['scid'], equals(12));
      expect(body.containsKey('title'), isFalse);
      expect(body.containsKey('subject_title'), isFalse);
      // Creation is unproven live, so the repository must not invent a block.
      expect(block, isNull);
    });

    test('createBlock returns null when no timetable exists', () async {
      mockApiClient.getResponse = {'s': true, 'rt': []};
      final block = await repository.createBlock(
        subjectId: 12,
        subjectTitle: 'Química Geral',
        colorInt: 4292557552,
        dayOfWeek: 4,
        startHour: 10,
        endHour: 12,
      );
      expect(block, isNull);
      expect(mockApiClient.bodyOf('POST', '/timetable/detail/v70630'), isNull);
    });

    test('deleteBlock sends the id in the JSON body', () async {
      mockApiClient.deleteResponse = {'s': true};
      final success = await repository.deleteBlock(99);
      expect(success, isTrue);
      final body = mockApiClient.bodyOf('DELETE', '/timetable/detail/v70630');
      expect(body, isNotNull);
      expect(body!['id'], equals(99));
    });
  });
}
