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

    test('fetchAvailableChallenges le a chave `rs` devolvida pela API', () async {
      // A API real responde {"s": true, "rs": [...]}; a lista vinha vazia porque
      // o repositorio so olhava `challenges`/`c`.
      mockApiClient.getResponse = {
        's': true,
        'rs': [
          {'id': 9, 'name': 'Desafio YPT', 'flame_cost': 30},
        ],
      };

      final challenges = await repository.fetchAvailableChallenges();
      expect(challenges.length, equals(1));
      expect(challenges.first.name, equals('Desafio YPT'));
    });

    test('fetchAvailableChallenges devolve lista vazia quando rs vem vazia', () async {
      mockApiClient.getResponse = {'s': true, 'rs': <dynamic>[]};

      expect(await repository.fetchAvailableChallenges(), isEmpty);
    });

    // As rotas de escrita foram removidas do repositorio: /mission/challenge/my,
    // /join e /cancel respondem 404 na API e nao existem no APK oficial. A
    // ausencia e garantida em tempo de compilacao, entao nao ha teste a escrever
    // aqui; reintroduzi-las exigira confirmar o contrato primeiro.
  });
}
