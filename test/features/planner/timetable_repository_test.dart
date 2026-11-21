import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/timetable_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;
  Map<String, dynamic>? deleteResponse;

  /// Records every request so the tests can assert the real contract.
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

    test('fetchTimetable parses the compact rt response', () async {
      mockApiClient.getResponse = {
        's': true,
        'rt': [
          {
            'id': 7,
            't': 'Teste',
            'no': false,
            'sd': '2026-01-01',
            'ed': '2026-12-31',
            'st': '08:00:00',
            'rt': null,
            'lw': 5,
            'et': '10:00:00',
            'ca': '2026-01-01T00:00:00.000Z',
            'scid': null,
          }
        ]
      };

      final blocks = await repository.fetchTimetable();

      expect(blocks, hasLength(1));
      expect(blocks.single.subjectTitle, 'Teste');
      expect(blocks.single.dayOfWeek, 5);
      expect(blocks.single.startHour, 8);
      expect(blocks.single.endHour, 10);
    });

    test('createBlock posts to /timetable/detail/v70630 with ttid', () async {
      // The response shape for a created block is still unproven, so the test
      // asserts the request contract only.
      mockApiClient.getResponse = {
        's': true,
        'rt': [
          {'id': 5323504, 't': 'teste', 'lw': 5, 'st': '08:00:00', 'et': '23:55:00',
           'sd': '2026-01-01', 'ed': '2026-12-31'}
        ],
      };
      mockApiClient.postResponse = {'s': false};

      final block = await repository.createBlock(
        subjectId: 101,
        subjectTitle: 'Química',
        colorInt: 4292557552,
        dayOfWeek: 4,
        startHour: 13,
        endHour: 15,
      );

      final body = mockApiClient.bodyOf('POST', '/timetable/detail/v70630');
      expect(body, isNotNull);
      expect(body!['ttid'], equals(5323504));
      // The title travels under the compact key `t`: the server rejects
      // `title` with "title is required".
      expect(body['t'], equals('Química'));
      expect(body['lw'], equals(4));
      expect(body['st'], equals('13:00:00'));
      expect(body['et'], equals('15:00:00'));
      expect(body['scid'], equals(101));
      expect(body['sd'], equals('2026-01-01'));
      expect(body['ed'], equals('2026-12-31'));
      expect(body['c'], equals(4292557552));
      // `s: false` means the server refused, so no block is reported.
      expect(block, isNull);
    });

    test('createBlock parses rs after the live-verified c/sd/ed contract', () async {
      mockApiClient.getResponse = {
        's': true,
        'rt': [
          {'id': 5323504, 'sd': '2026-01-01', 'ed': '2026-12-31'}
        ],
      };
      mockApiClient.postResponse = {
        's': true,
        'rs': {
          'id': 99, 't': 'Química', 'scid': 101, 'c': 4292557552,
          'lw': 4, 'st': '13:00:00', 'et': '15:00:00',
        },
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
      expect(block!.id, 99);
      expect(mockApiClient.bodyOf('POST', '/timetable/detail/v70630')!['c'],
          4292557552);
    });

    test('deleteBlock sends the id in the JSON body, not the path', () async {
      mockApiClient.deleteResponse = {'s': true};

      final result = await repository.deleteBlock(5);

      expect(result, isTrue);
      final body = mockApiClient.bodyOf('DELETE', '/timetable/detail/v70630');
      expect(body, isNotNull);
      expect(body!['id'], equals(5));
      // The id must not be appended to the path.
      final call = mockApiClient.calls.firstWhere(
          (c) => c['method'] == 'DELETE');
      expect((call['path'] as String).contains('/5'), isFalse);
    });

    test('deleteBlock returns false when the server refuses', () async {
      mockApiClient.deleteResponse = {'s': false, 'm': 'already removed'};
      expect(await repository.deleteBlock(999999999), isFalse);
    });
  });
}
