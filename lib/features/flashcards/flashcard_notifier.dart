import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/flashcard_model.dart';
import '../../data/repositories/flashcard_repository.dart';

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return FlashcardRepository();
});

class FlashcardState {
  final List<FlashcardDeckModel> decks;
  final FlashcardDeckModel? selectedDeck;
  final List<FlashcardModel> currentCards;
  final int currentCardIndex;
  final bool isFlipped;
  final bool isLoading;
  final int studiedCount;
  final bool isSessionCompleted;
  final String? errorMessage;

  const FlashcardState({
    this.decks = const [],
    this.selectedDeck,
    this.currentCards = const [],
    this.currentCardIndex = 0,
    this.isFlipped = false,
    this.isLoading = false,
    this.studiedCount = 0,
    this.isSessionCompleted = false,
    this.errorMessage,
  });

  FlashcardModel? get activeCard {
    if (currentCards.isNotEmpty && currentCardIndex < currentCards.length) {
      return currentCards[currentCardIndex];
    }
    return null;
  }

  FlashcardState copyWith({
    List<FlashcardDeckModel>? decks,
    FlashcardDeckModel? selectedDeck,
    List<FlashcardModel>? currentCards,
    int? currentCardIndex,
    bool? isFlipped,
    bool? isLoading,
    int? studiedCount,
    bool? isSessionCompleted,
    String? errorMessage,
  }) {
    return FlashcardState(
      decks: decks ?? this.decks,
      selectedDeck: selectedDeck ?? this.selectedDeck,
      currentCards: currentCards ?? this.currentCards,
      currentCardIndex: currentCardIndex ?? this.currentCardIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      isLoading: isLoading ?? this.isLoading,
      studiedCount: studiedCount ?? this.studiedCount,
      isSessionCompleted: isSessionCompleted ?? this.isSessionCompleted,
      errorMessage: errorMessage,
    );
  }
}

class FlashcardNotifier extends StateNotifier<FlashcardState> {
  final FlashcardRepository _repository;

  FlashcardNotifier({required FlashcardRepository repository})
      : _repository = repository,
        super(const FlashcardState()) {
    loadDecks();
  }

  Future<void> loadDecks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final decks = await _repository.fetchDecks();
      state = state.copyWith(decks: decks, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> selectDeck(FlashcardDeckModel deck) async {
    state = state.copyWith(
      selectedDeck: deck,
      isLoading: true,
      currentCards: [],
      currentCardIndex: 0,
      isFlipped: false,
      studiedCount: 0,
      isSessionCompleted: false,
    );

    try {
      final cards = await _repository.fetchCards(deck.id);
      state = state.copyWith(
        currentCards: cards,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createDeck({
    required String title,
    required int colorInt,
    String? description,
  }) async {
    try {
      final newDeck = await _repository.createDeck(
        title: title,
        colorInt: colorInt,
        description: description,
      );
      state = state.copyWith(decks: [...state.decks, newDeck]);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteDeck(int deckId) async {
    try {
      final success = await _repository.deleteDeck(deckId);
      if (success) {
        state = state.copyWith(
          decks: state.decks.where((d) => d.id != deckId).toList(),
          selectedDeck: state.selectedDeck?.id == deckId ? null : state.selectedDeck,
        );
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createCard({
    required String front,
    required String back,
    String? hint,
  }) async {
    final deck = state.selectedDeck;
    if (deck == null) return false;

    try {
      final newCard = await _repository.createCard(
        deckId: deck.id,
        front: front,
        back: back,
        hint: hint,
      );
      final updatedCards = [...state.currentCards, newCard];
      final updatedDecks = state.decks.map((d) {
        if (d.id == deck.id) {
          return d.copyWith(cardCount: d.cardCount + 1);
        }
        return d;
      }).toList();

      state = state.copyWith(
        currentCards: updatedCards,
        decks: updatedDecks,
        selectedDeck: deck.copyWith(cardCount: deck.cardCount + 1),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteCard(int cardId) async {
    try {
      final success = await _repository.deleteCard(cardId);
      if (success) {
        final updatedCards = state.currentCards.where((c) => c.id != cardId).toList();
        state = state.copyWith(
          currentCards: updatedCards,
          currentCardIndex: state.currentCardIndex >= updatedCards.length
              ? (updatedCards.isEmpty ? 0 : updatedCards.length - 1)
              : state.currentCardIndex,
        );
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  void flipCard() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  Future<void> answerCard(int easeFactor) async {
    final active = state.activeCard;
    if (active != null) {
      _repository.submitReview(cardId: active.id, easeFactor: easeFactor);
    }

    final nextIndex = state.currentCardIndex + 1;
    final isCompleted = nextIndex >= state.currentCards.length;

    state = state.copyWith(
      currentCardIndex: nextIndex,
      isFlipped: false,
      studiedCount: state.studiedCount + 1,
      isSessionCompleted: isCompleted,
    );
  }

  void restartSession() {
    state = state.copyWith(
      currentCardIndex: 0,
      isFlipped: false,
      studiedCount: 0,
      isSessionCompleted: false,
    );
  }
}

final flashcardNotifierProvider =
    StateNotifierProvider<FlashcardNotifier, FlashcardState>((ref) {
  final repo = ref.watch(flashcardRepositoryProvider);
  return FlashcardNotifier(repository: repo);
});
