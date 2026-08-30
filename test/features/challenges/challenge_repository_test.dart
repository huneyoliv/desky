import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/challenge_model.dart';
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

    test('ChallengeModel.fromJson parses JSON correctly', () {
      final json = {
        'id': 1,
        'name': 'Desafio 5 AM',
        'description': 'Acorde cedo e estude',
        'flame_cost': 100,
        'participants_count': 42,
      };

      final model = ChallengeModel.fromJson(json);

      expect(model.id, 1);
      expect(model.name, 'Desafio 5 AM');
      expect(model.flameCost, 100);
      expect(model.participantCount, 42);
    });

    test('fetchAvailableChallenges parses response list correctly', () async {
      mockApiClient.getResponse = {
        's': true,
        'challenges': [
          {
            'id': 1,
            'name': 'Desafio Maratona',
            'flame_cost': 50,
          }
        ]
      };

      final list = await repository.fetchAvailableChallenges();

      expect(list.length, 1);
      expect(list.first.name, 'Desafio Maratona');
    });

    test('joinChallenge returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.joinChallenge(1, 50);
      expect(result, isTrue);
    });
  });
}
