import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDioWithRankAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final jsonResp = '''
    {
      "s": true,
      "ms": [
        {
          "gd": 0,
          "ud": 100,
          "n": "Bruno",
          "dl": {"sm": 3600000, "is": false, "ia": false}
        },
        {
          "gd": 377,
          "ud": 200,
          "n": "Alice",
          "dl": {"sm": 7200000, "is": true, "ia": false}
        }
      ]
    }
    ''';

    return ResponseBody.fromString(
      jsonResp,
      200,
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

  group('Group Ranking Fix Tests', () {
    test('GroupMemberModel.fromJson parses HAR rank item format correctly', () {
      final json = {
        'sd': 120,
        'ud': 8436253,
        'ct': 'Graduação',
        'n': '  Alia ⚖️',
        'dl': {
          'sm': 5400000,
          'is': true,
          'ia': false,
        },
      };

      final member = GroupMemberModel.fromJson(json);

      expect(member.userId, 8436253);
      expect(member.name, 'Alia ⚖️');
      expect(member.studiconId, 120);
      expect(member.studyMs, 5400000);
      expect(member.isStudying, true);
      expect(member.isPaused, false);
    });

    test('GroupMemberModel.fromJson parses st in seconds correctly to studyMs', () {
      final jsonSeconds = {
        'ud': 12345,
        'n': 'yuguro',
        'sd': 377,
        'st': 3720, // 3720 seconds = 1h 2m
      };

      final member = GroupMemberModel.fromJson(jsonSeconds);

      expect(member.name, 'yuguro');
      expect(member.studiconId, 377);
      expect(member.studyMs, 3720000); // Converted to ms (1h 2m)
    });

    test('GroupMemberModel.fromJson parses st: 0 correctly without error', () {
      final jsonZero = {
        'ud': 67890,
        'n': 'érica',
        'st': 0,
      };

      final member = GroupMemberModel.fromJson(jsonZero);

      expect(member.name, 'érica');
      expect(member.studyMs, 0);
    });

    test('GroupRepository.fetchGroupRanks includes isCam=false and sorts descending by studyMs', () async {
      final dio = Dio();
      final adapter = MockDioWithRankAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = GroupRepository(apiClient: apiClient);
      final ranks = await repo.fetchGroupRanks(6487271, period: 'day');

      expect(ranks.length, 2);
      expect(ranks[0].name, 'Alice');
      expect(ranks[0].studyMs, 7200000);
      expect(ranks[1].name, 'Bruno');
      expect(ranks[1].studyMs, 3600000);
      expect(adapter.lastOptions?.path, contains('isCam=false'));
      expect(adapter.lastOptions?.path, contains('groupID=6487271'));
    });
  });
}
