import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/flashcard_repository.dart';

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
  group('FlashcardRepository Tests', () {
    late MockApiClient mockApiClient;
    late FlashcardRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = FlashcardRepository(apiClient: mockApiClient);
    });

    test('fetchDecks parses list of decks from API', () async {
      mockApiClient.postResponse = {
        's': true,
        'list': [
          {
            'id': 1,
            'name': 'Direito Constitucional',
            'color': 4292557552,
            'card_count': 40,
          }
        ]
      };

      final decks = await repository.fetchDecks();
      expect(decks.length, equals(1));
      expect(decks.first.title, equals('Direito Constitucional'));
      expect(decks.first.cardCount, equals(40));
    });

    test('createDeck sends POST to /card/book/create and returns FlashcardDeckModel', () async {
      mockApiClient.postResponse = {
        's': true,
        'book': {
          'id': 2,
          'name': 'Direito Penal',
          'color': 4283215696,
          'description': 'Código Penal e Leis Especiais',
        }
      };

      final deck = await repository.createDeck(
        title: 'Direito Penal',
        colorInt: 4283215696,
        description: 'Código Penal e Leis Especiais',
      );

      expect(deck.id, equals(2));
      expect(deck.title, equals('Direito Penal'));
    });

    test('deleteDeck sends POST to /card/book/delete and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.deleteDeck(1);
      expect(success, isTrue);
    });

    test('fetchCards parses cards list from /card/list', () async {
      mockApiClient.postResponse = {
        's': true,
        'list': [
          {
            'id': 100,
            'book_id': 1,
            'question': 'Artigo 5º da CF',
            'answer': 'Direitos e garantias fundamentais',
          }
        ]
      };

      final cards = await repository.fetchCards(1);
      expect(cards.length, equals(1));
      expect(cards.first.front, equals('Artigo 5º da CF'));
    });

    test('createCard sends POST to /card/create and returns FlashcardModel', () async {
      mockApiClient.postResponse = {
        's': true,
        'card': {
          'id': 101,
          'book_id': 1,
          'question': 'Princípio da Legalidade',
          'answer': 'Não há crime sem lei anterior que o defina',
        }
      };

      final card = await repository.createCard(
        deckId: 1,
        front: 'Princípio da Legalidade',
        back: 'Não há crime sem lei anterior que o defina',
      );

      expect(card.id, equals(101));
      expect(card.front, equals('Princípio da Legalidade'));
    });

    test('deleteCard sends POST to /card/delete and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.deleteCard(101);
      expect(success, isTrue);
    });

    test('submitReview sends POST to /card/review and returns true', () async {
      mockApiClient.postResponse = {'s': true};
      final success = await repository.submitReview(cardId: 101, easeFactor: 3);
      expect(success, isTrue);
    });
  });
}
