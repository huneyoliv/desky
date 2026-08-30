import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;

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
}

void main() {
  group('GroupRepository Tests', () {
    late MockApiClient mockApiClient;
    late GroupRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = GroupRepository(apiClient: mockApiClient);
    });

    test('fetchMembers parses members list', () async {
      mockApiClient.getResponse = {
        's': true,
        'ms': [
          {
            'ud': 1,
            'n': 'Membro Alpha',
            'sd': 5,
            'dl': {'is': true, 'sm': 7200000},
          }
        ]
      };

      final members = await repository.fetchMembers(100);
      expect(members.length, equals(1));
      expect(members.first.name, equals('Membro Alpha'));
      expect(members.first.isStudying, isTrue);
    });

    test('shakeMember sends POST and returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.shakeMember(groupId: 100, targetUserId: 1);
      expect(result, isTrue);
    });

    test('fetchChatMessages parses messages list', () async {
      mockApiClient.getResponse = {
        's': true,
        'm': [
          {
            'idx': 1,
            'uid': 55,
            'nn': 'Pedro',
            'msg': 'Oi pessoal!',
          }
        ]
      };

      final messages = await repository.fetchChatMessages(100);
      expect(messages.length, equals(1));
      expect(messages.first.message, equals('Oi pessoal!'));
    });

    test('sendMessage posts message and returns ChatMessageModel', () async {
      mockApiClient.postResponse = {
        's': true,
        'idx': 99,
        'uid': 55,
        'nn': 'Pedro',
        'msg': 'Mensagem de teste',
      };

      final msg = await repository.sendMessage(
        groupId: 100,
        userId: 55,
        nickname: 'Pedro',
        message: 'Mensagem de teste',
      );

      expect(msg.id, equals(99));
      expect(msg.message, equals('Mensagem de teste'));
    });

    test('joinGroup sends join request', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.joinGroup(100, nickname: 'Pedro');
      expect(result, isTrue);
    });

    test('leaveGroup sends leave request', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.leaveGroup(100);
      expect(result, isTrue);
    });
  });
}
