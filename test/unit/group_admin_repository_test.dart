import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_admin_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? postResponse;
  String? lastPath;
  dynamic lastData;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    lastPath = path;
    lastData = data;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: postResponse,
      statusCode: 200,
    );
  }
}

void main() {
  group('GroupAdminRepository Tests', () {
    late MockApiClient mockApiClient;
    late GroupAdminRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      mockApiClient.postResponse = {'s': true};
      repository = GroupAdminRepository(apiClient: mockApiClient);
    });

    test('every group setting update posts to /group/info/edit keyed by id', () async {
      await repository.updateGroupName(10, 'Novo Nome');
      expect(mockApiClient.lastPath, equals('/group/info/edit'));
      expect(mockApiClient.lastData, equals({'id': 10, 't': 'Novo Nome'}));

      await repository.updateGroupCategory(10, 7);
      expect(mockApiClient.lastPath, equals('/group/info/edit'));
      expect(mockApiClient.lastData, equals({'id': 10, 'cid': 7}));

      await repository.updateGroupCapacity(10, 40);
      expect(mockApiClient.lastPath, equals('/group/info/edit'));
      expect(mockApiClient.lastData, equals({'id': 10, 'mc': 40}));

      await repository.updateGroupGoal(10, 12);
      expect(mockApiClient.lastPath, equals('/group/info/edit'));
      expect(mockApiClient.lastData, equals({'id': 10, 'gt': 12}));

      await repository.updateGroupPassword(10, '1234');
      expect(mockApiClient.lastPath, equals('/group/info/edit'));
      expect(mockApiClient.lastData, equals({'id': 10, 'pw': '1234'}));

      await repository.updateNotice(10, 'aviso');
      expect(mockApiClient.lastPath, equals('/group/info/edit'));
      expect(mockApiClient.lastData, equals({'id': 10, 'nt': 'aviso'}));
    });

    test('updates report success only when the API answers s: true', () async {
      mockApiClient.postResponse = {'s': false};
      expect(await repository.updateGroupName(10, 'Novo Nome'), isFalse);

      mockApiClient.postResponse = {'s': true};
      expect(await repository.updateGroupName(10, 'Novo Nome'), isTrue);
    });

    test('promoteGroup still reports failure for the unconfirmed endpoint', () async {
      // shortcut: /group/setting/promote answers 404 and no replacement is confirmed,
      // so promotion keeps failing until the endpoint is verified against the live API.
      mockApiClient.postResponse = {'s': false};
      expect(await repository.promoteGroup(10), isFalse);
    });
  });
}
