import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/flashcard_model.dart';

void main() {
  group('Flashcard Models Tests', () {
    test('FlashcardDeckModel parses JSON accurately', () {
      final json = {
        'id': 10,
        'name': 'Fisiologia Humana',
        'description': 'Resumo do sistema cardiovascular',
        'color': 4292557552,
        'card_count': 25,
        'studied_today': 10,
        'created_at': 1700000000000,
      };

      final deck = FlashcardDeckModel.fromJson(json);
      expect(deck.id, equals(10));
      expect(deck.title, equals('Fisiologia Humana'));
      expect(deck.description, equals('Resumo do sistema cardiovascular'));
      expect(deck.colorInt, equals(4292557552));
      expect(deck.cardCount, equals(25));
      expect(deck.studiedTodayCount, equals(10));

      final exported = deck.toJson();
      expect(exported['id'], equals(10));
      expect(exported['name'], equals('Fisiologia Humana'));
      expect(exported['color'], equals(4292557552));
    });

    test('FlashcardModel parses front, back, hint and reviews accurately', () {
      final json = {
        'id': 500,
        'book_id': 10,
        'question': 'O que é sístole?',
        'answer': 'Fase de contração do músculo cardíaco.',
        'hint': 'Contração',
        'review_count': 4,
        'ease_factor': 3,
        'is_mastered': false,
        'last_reviewed_at': 1700000000000,
      };

      final card = FlashcardModel.fromJson(json);
      expect(card.id, equals(500));
      expect(card.deckId, equals(10));
      expect(card.front, equals('O que é sístole?'));
      expect(card.back, equals('Fase de contração do músculo cardíaco.'));
      expect(card.hint, equals('Contração'));
      expect(card.reviewCount, equals(4));
      expect(card.easeFactor, equals(3));
      expect(card.isMastered, isFalse);

      final exported = card.toJson();
      expect(exported['id'], equals(500));
      expect(exported['question'], equals('O que é sístole?'));
      expect(exported['answer'], equals('Fase de contração do músculo cardíaco.'));
    });
  });
}
