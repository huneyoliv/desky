import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_admin_repository.dart';

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
  group('GroupAdminRepository Tests', () {
    late MockApiClient mockApiClient;
    late GroupAdminRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = GroupAdminRepository(apiClient: mockApiClient);
    });

    test('updateGroupName returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.updateGroupName(1, 'Novo Nome');
      expect(success, isTrue);
    });

    test('warnMember returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.warnMember(1, 100);
      expect(success, isTrue);
    });

    test('kickMember returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.kickMember(1, 100);
      expect(success, isTrue);
    });

    test('banMember returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.banMember(1, 100);
      expect(success, isTrue);
    });

    test('fetchBannedList returns users list', () async {
      mockApiClient.getResponse = {
        's': true,
        'users': [
          {'id': 100, 'name': 'Usuario Banido'}
        ]
      };
      final list = await repository.fetchBannedList(1);
      expect(list.length, 1);
      expect(list.first['name'], 'Usuario Banido');
    });

    test('approveRequest returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.approveRequest(1, 50);
      expect(success, isTrue);
    });

    test('disbandGroup returns true on success', () async {
      mockApiClient.deleteResponse = {'s': true};
      final success = await repository.disbandGroup(1);
      expect(success, isTrue);
    });
  });
}
