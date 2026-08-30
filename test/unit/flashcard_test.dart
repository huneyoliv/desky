import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/flashcard_model.dart';
import 'package:desky/data/repositories/flashcard_repository.dart';
import 'package:desky/features/flashcards/flashcard_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = handler(options);
    final status = res['status'] as int? ?? 200;
    final data = res['data'] as String;
    return ResponseBody.fromString(
      data,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Flashcard Feature Tests', () {
    late FlashcardRepository repo;

    setUp(() {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path.contains('/card/book/list')) {
          return {
            'status': 200,
            'data': '{"s":true,"list":[{"id":1,"name":"Biologia Celular","color":4292557552,"card_count":5,"studied_today":0}]}',
          };
        }
        if (options.path.contains('/card/book/create')) {
          return {
            'status': 200,
            'data': '{"s":true,"book":{"id":2,"name":"Química Orgânica","color":4281775359,"card_count":0}}',
          };
        }
        if (options.path.contains('/card/book/delete')) {
          return {'status': 200, 'data': '{"s":true}'};
        }
        if (options.path.contains('/card/list')) {
          return {
            'status': 200,
            'data': '{"s":true,"list":[{"id":101,"book_id":1,"question":"O que é mitocôndria?","answer":"Organela responsável pela respiração celular e produção de ATP.","hint":"Energia","ease_factor":2}]}',
          };
        }
        if (options.path.contains('/card/create')) {
          return {
            'status': 200,
            'data': '{"s":true,"card":{"id":102,"book_id":1,"question":"O que é ribossomo?","answer":"Síntese proteica.","hint":null}}',
          };
        }
        if (options.path.contains('/card/delete')) {
          return {'status': 200, 'data': '{"s":true}'};
        }
        if (options.path.contains('/card/review')) {
          return {'status': 200, 'data': '{"s":true}'};
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      repo = FlashcardRepository(apiClient: ApiClient(customDio: dio));
    });

    test('FlashcardDeckModel and FlashcardModel serialization', () {
      final deck = FlashcardDeckModel(
        id: 1,
        title: 'Biologia',
        description: 'Genética',
        colorInt: 4292557552,
        cardCount: 10,
        createdAt: DateTime(2026, 8, 14),
      );

      final deckJson = deck.toJson();
      final fromJson = FlashcardDeckModel.fromJson(deckJson);

      expect(fromJson.id, 1);
      expect(fromJson.title, 'Biologia');
      expect(fromJson.description, 'Genética');
      expect(fromJson.cardCount, 10);

      final card = FlashcardModel(
        id: 10,
        deckId: 1,
        front: 'Pergunta',
        back: 'Resposta',
        hint: 'Dica',
        easeFactor: 3,
      );

      final cardJson = card.toJson();
      final cardFromJson = FlashcardModel.fromJson(cardJson);

      expect(cardFromJson.id, 10);
      expect(cardFromJson.front, 'Pergunta');
      expect(cardFromJson.back, 'Resposta');
      expect(cardFromJson.hint, 'Dica');
      expect(cardFromJson.easeFactor, 3);
    });

    test('FlashcardRepository operations (fetch, create, delete, review)', () async {
      final decks = await repo.fetchDecks();
      expect(decks.length, 1);
      expect(decks.first.title, 'Biologia Celular');

      final newDeck = await repo.createDeck(title: 'Química Orgânica', colorInt: 4281775359);
      expect(newDeck.id, 2);
      expect(newDeck.title, 'Química Orgânica');

      final cards = await repo.fetchCards(1);
      expect(cards.length, 1);
      expect(cards.first.front, 'O que é mitocôndria?');

      final newCard = await repo.createCard(
        deckId: 1,
        front: 'O que é ribossomo?',
        back: 'Síntese proteica.',
      );
      expect(newCard.id, 102);

      final reviewSuccess = await repo.submitReview(cardId: 101, easeFactor: 3);
      expect(reviewSuccess, true);

      final deleteSuccess = await repo.deleteCard(101);
      expect(deleteSuccess, true);

      final deleteDeckSuccess = await repo.deleteDeck(1);
      expect(deleteDeckSuccess, true);
    });

    test('FlashcardNotifier manages study flow, flip, and completion', () async {
      final notifier = FlashcardNotifier(repository: repo);
      await notifier.loadDecks();

      expect(notifier.state.decks.length, 1);

      await notifier.selectDeck(notifier.state.decks.first);
      expect(notifier.state.currentCards.length, 1);
      expect(notifier.state.activeCard?.front, 'O que é mitocôndria?');
      expect(notifier.state.isFlipped, false);

      notifier.flipCard();
      expect(notifier.state.isFlipped, true);

      await notifier.answerCard(3);
      expect(notifier.state.studiedCount, 1);
      expect(notifier.state.isSessionCompleted, true);

      notifier.restartSession();
      expect(notifier.state.currentCardIndex, 0);
      expect(notifier.state.isSessionCompleted, false);
      expect(notifier.state.isFlipped, false);
    });
  });
}
