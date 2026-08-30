import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/challenge_repository.dart';

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
  group('ChallengeRepository Tests', () {
    late MockApiClient mockApiClient;
    late ChallengeRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = ChallengeRepository(apiClient: mockApiClient);
    });

    test('fetchAvailableChallenges parses API response list', () async {
      mockApiClient.getResponse = {
        'challenges': [
          {
            'id': 1,
            'name': 'Desafio Matinal',
            'description': 'Estude 2h antes das 10h',
            'flame_cost': 30,
            'is_joined': false,
          }
        ]
      };

      final challenges = await repository.fetchAvailableChallenges();
      expect(challenges.length, equals(1));
      expect(challenges.first.name, equals('Desafio Matinal'));
      expect(challenges.first.flameCost, equals(30));
    });

    test('fetchMyChallenges parses user enrolled challenges', () async {
      mockApiClient.getResponse = {
        'challenges': [
          {
            'id': 2,
            'name': 'Desafio Noturno',
            'flame_cost': 50,
            'is_joined': true,
          }
        ]
      };

      final challenges = await repository.fetchMyChallenges();
      expect(challenges.length, equals(1));
      expect(challenges.first.name, equals('Desafio Noturno'));
      expect(challenges.first.isJoined, isTrue);
    });

    test('joinChallenge sends POST to /mission/challenge/join and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.joinChallenge(1, 30);
      expect(result, isTrue);
    });

    test('cancelParticipation sends POST to /mission/challenge/cancel and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.cancelParticipation(1);
      expect(result, isTrue);
    });
  });
}
