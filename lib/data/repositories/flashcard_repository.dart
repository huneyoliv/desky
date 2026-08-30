import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/constants/api_constants.dart';
import '../models/flashcard_model.dart';

class FlashcardRepository {
  final ApiClient _apiClient;

  FlashcardRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<FlashcardDeckModel>> fetchDecks({
    String language = ApiConstants.defaultLanguage,
  }) async {
    final response = await _apiClient.post(
      '/card/book/list',
      data: {'language': language},
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == true) {
      final list = data['list'] ?? data['books'] ?? [];
      if (list is List) {
        return list
            .map((item) => FlashcardDeckModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<FlashcardDeckModel> createDeck({
    required String title,
    required int colorInt,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/card/book/create',
      data: {
        'name': title,
        'color': colorInt,
        'description': description ?? '',
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == true) {
      final bookJson = data['book'] ?? data['data'] ?? data;
      return FlashcardDeckModel.fromJson(bookJson is Map<String, dynamic> ? bookJson : {
        'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch,
        'name': title,
        'color': colorInt,
        'description': description,
      });
    }

    if (data is Map<String, dynamic> && data['m'] != null) {
      throw ApiException(data['m'].toString());
    }
    throw const ApiException('Falha ao criar baralho');
  }

  Future<bool> deleteDeck(int deckId) async {
    try {
      final response = await _apiClient.post(
        '/card/book/delete',
        data: {'id': deckId, 'book_id': deckId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<FlashcardModel>> fetchCards(int deckId) async {
    final response = await _apiClient.post(
      '/card/list',
      data: {'book_id': deckId},
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == true) {
      final list = data['list'] ?? data['cards'] ?? [];
      if (list is List) {
        return list
            .map((item) => FlashcardModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<FlashcardModel> createCard({
    required int deckId,
    required String front,
    required String back,
    String? hint,
  }) async {
    final response = await _apiClient.post(
      '/card/create',
      data: {
        'book_id': deckId,
        'question': front,
        'answer': back,
        'hint': hint ?? '',
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == true) {
      final cardJson = data['card'] ?? data['data'] ?? data;
      return FlashcardModel.fromJson(cardJson is Map<String, dynamic> ? cardJson : {
        'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch,
        'book_id': deckId,
        'question': front,
        'answer': back,
        'hint': hint,
      });
    }

    if (data is Map<String, dynamic> && data['m'] != null) {
      throw ApiException(data['m'].toString());
    }
    throw const ApiException('Falha ao criar flashcard');
  }

  Future<bool> deleteCard(int cardId) async {
    try {
      final response = await _apiClient.post(
        '/card/delete',
        data: {'id': cardId, 'card_id': cardId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitReview({
    required int cardId,
    required int easeFactor,
  }) async {
    try {
      final response = await _apiClient.post(
        '/card/review',
        data: {
          'id': cardId,
          'card_id': cardId,
          'ease_factor': easeFactor,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {
      return false;
    }
  }
}
