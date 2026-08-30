import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_admin_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? postResponse;

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
  group('GroupAdminRepository Tests', () {
    late MockApiClient mockApiClient;
    late GroupAdminRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = GroupAdminRepository(apiClient: mockApiClient);
    });

    test('updateGroupName sends POST to /group/setting/name', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.updateGroupName(10, 'Novo Nome');
      expect(success, isTrue);
    });

    test('updateGroupGoal sends POST to /group/setting/goal-time', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.updateGroupGoal(10, 12);
      expect(success, isTrue);
    });

    test('updateGroupCapacity sends POST to /group/setting/max-member', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.updateGroupCapacity(10, 40);
      expect(success, isTrue);
    });

    test('updateGroupPassword sends POST to /group/setting/password', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.updateGroupPassword(10, '1234');
      expect(success, isTrue);
    });

    test('promoteGroup sends POST to /group/setting/promote', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.promoteGroup(10);
      expect(success, isTrue);
    });
  });
}
