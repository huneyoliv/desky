import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/rank_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;
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
}

void main() {
  group('RankRepository Tests', () {
    late MockApiClient mockApiClient;
    late RankRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = RankRepository(apiClient: mockApiClient);
      mockApiClient.getResponse = {
        's': true,
        'ms': [
          {'ud': 101, 'n': 'Lara', 'gd': 0, 'ct': 'ENEM', 'dl': {'sm': 36000000}},
          {'ud': 102, 'n': 'Lucas', 'gd': 0, 'ct': 'ENEM', 'dl': {'sm': 32400000}},
        ]
      };
    });

    test('fetchGlobalRanks with type=day uses today date without zero-padding', () async {
      await repository.fetchGlobalRanks(period: 'day');

      final now = DateTime.now();
      final expectedDate = '${now.year}-${now.month}-${now.day}';

      expect(mockApiClient.lastGetPath, contains('date=$expectedDate'));
      expect(mockApiClient.lastGetPath, contains('type=day'));
    });

    test('fetchGlobalRanks with type=week uses Monday of current week without zero-padding', () async {
      await repository.fetchGlobalRanks(period: 'week');

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final expectedDate = '${monday.year}-${monday.month}-${monday.day}';

      expect(mockApiClient.lastGetPath, contains('date=$expectedDate'));
      expect(mockApiClient.lastGetPath, contains('type=week'));
    });

    test('fetchGlobalRanks with type=month uses first day of month without zero-padding', () async {
      await repository.fetchGlobalRanks(period: 'month');

      final now = DateTime.now();
      final expectedDate = '${now.year}-${now.month}-1';

      expect(mockApiClient.lastGetPath, contains('date=$expectedDate'));
      expect(mockApiClient.lastGetPath, contains('type=month'));
    });

    test('fetchGlobalRanks URL does NOT contain zero-padded date', () async {
      await repository.fetchGlobalRanks(period: 'day');

      expect(mockApiClient.lastGetPath, isNot(matches(RegExp(r'date=\d{4}-\d{2}-\d{2}'))));
    });

    test('fetchGlobalRanks URL includes groupID=0 and isCam=false', () async {
      await repository.fetchGlobalRanks(period: 'day');

      expect(mockApiClient.lastGetPath, contains('groupID=0'));
      expect(mockApiClient.lastGetPath, contains('isCam=false'));
    });

    test('fetchGlobalRanks returns parsed RankEntryModel list', () async {
      final ranks = await repository.fetchGlobalRanks(period: 'day', categoryId: 1);
      expect(ranks.length, equals(2));
      expect(ranks[0].userName, equals('Lara'));
      expect(ranks[0].rank, equals(1));
      expect(ranks[0].studyMs, equals(36000000));
      expect(ranks[1].userName, equals('Lucas'));
      expect(ranks[1].rank, equals(2));
    });

    test('fetchGlobalRanks returns empty list when s=false', () async {
      mockApiClient.getResponse = {'s': false};
      final ranks = await repository.fetchGlobalRanks(period: 'day');
      expect(ranks, isEmpty);
    });

    test('fetchGlobalRanks returns empty list on null response', () async {
      mockApiClient.getResponse = null;
      final ranks = await repository.fetchGlobalRanks(period: 'day');
      expect(ranks, isEmpty);
    });

    test('fetchGlobalRanks falls back to ranks key if ms is absent', () async {
      mockApiClient.getResponse = {
        's': true,
        'ranks': [
          {'ud': 200, 'n': 'Ana', 'gd': 0, 'ct': 'Medicina', 'dl': {'sm': 10000000}},
        ]
      };
      final ranks = await repository.fetchGlobalRanks(period: 'week');
      expect(ranks.length, equals(1));
      expect(ranks[0].userName, equals('Ana'));
    });

    test('fetchMyCategoryRank returns user current rank integer', () async {
      mockApiClient.getResponse = {'s': true, 'mr': 42};
      final rank = await repository.fetchMyCategoryRank(categoryId: 1);
      expect(rank, equals(42));
    });

    test('fetchUserStats sends POST to /logs/range/days and returns logs', () async {
      mockApiClient.postResponse = {
        's': true,
        'ls': [
          {'dt': '2026-08-10', 'sm': 18000000, 'sb': 'Matematica'},
        ],
        'ss': [],
      };

      final stats = await repository.fetchUserStats(
        userId: 101,
        startDate: '2026-08-01',
        endDate: '2026-08-31',
      );

      expect(stats['s'], isTrue);
      expect((stats['ls'] as List).length, equals(1));
    });
  });
}
