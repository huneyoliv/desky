import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  String? lastGetPath;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
    lastGetPath = path;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: getResponse,
      statusCode: 200,
    );
  }
}

void main() {
  group('GroupRepository fetchGroupRanks Date and Sorting Tests', () {
    late MockApiClient mockApiClient;
    late GroupRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = GroupRepository(apiClient: mockApiClient);
      mockApiClient.getResponse = {
        's': true,
        'ms': [
          {'ud': 101, 'n': 'Alice', 'sm': 1800000}, // 30m
          {'ud': 102, 'n': 'Bob', 'sm': 7200000},   // 2h
          {'ud': 103, 'n': 'Carol', 'sm': 3600000}, // 1h
        ],
      };
    });

    test('fetchGroupRanks with period=day generates date without zero-padding', () async {
      final sampleDate = DateTime(2026, 5, 4, 14, 0); // May 4th (single digit month & day)
      await repository.fetchGroupRanks(123, period: 'day', referenceDate: sampleDate);

      expect(mockApiClient.lastGetPath, contains('date=2026-5-4'));
      expect(mockApiClient.lastGetPath, isNot(contains('date=2026-05-04')));
      expect(mockApiClient.lastGetPath, contains('type=day'));
      expect(mockApiClient.lastGetPath, contains('groupID=123'));
    });

    test('fetchGroupRanks with period=week generates Monday date without zero-padding', () async {
      // 2026-10-23 is Friday. Monday of that week was 2026-10-19.
      final sampleFriday = DateTime(2026, 10, 23);
      await repository.fetchGroupRanks(123, period: 'week', referenceDate: sampleFriday);

      expect(mockApiClient.lastGetPath, contains('date=2026-10-19'));
      expect(mockApiClient.lastGetPath, contains('type=week'));
    });

    test('fetchGroupRanks with period=month generates 1st of month without zero-padding', () async {
      // 2026-09-17 should produce 2026-9-1
      final sampleDate = DateTime(2026, 9, 17);
      await repository.fetchGroupRanks(123, period: 'month', referenceDate: sampleDate);

      expect(mockApiClient.lastGetPath, contains('date=2026-9-1'));
      expect(mockApiClient.lastGetPath, isNot(contains('date=2026-09-01')));
      expect(mockApiClient.lastGetPath, contains('type=month'));
    });

    test('fetchGroupRanks always returns members sorted by studyMs descending', () async {
      final members = await repository.fetchGroupRanks(123, period: 'day');

      expect(members.length, equals(3));
      expect(members[0].name, equals('Bob')); // 7200000 ms
      expect(members[1].name, equals('Carol')); // 3600000 ms
      expect(members[2].name, equals('Alice')); // 1800000 ms
      expect(members[0].studyMs, greaterThan(members[1].studyMs));
      expect(members[1].studyMs, greaterThan(members[2].studyMs));
    });
  });
}
