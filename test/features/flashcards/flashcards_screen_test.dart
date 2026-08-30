import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/flashcard_model.dart';
import 'package:desky/data/repositories/flashcard_repository.dart';
import 'package:desky/features/flashcards/flashcard_notifier.dart';
import 'package:desky/features/flashcards/flashcards_screen.dart';

class FakeFlashcardRepository extends FlashcardRepository {
  final List<FlashcardDeckModel> mockDecks;

  FakeFlashcardRepository({this.mockDecks = const []});

  @override
  Future<List<FlashcardDeckModel>> fetchDecks({String language = 'pt'}) async => mockDecks;

  @override
  Future<List<FlashcardModel>> fetchCards(int deckId) async => [];
}

void main() {
  testWidgets('FlashcardsScreen renders deck list properly', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final decks = [
      FlashcardDeckModel(
        id: 1,
        title: 'Biologia Celular',
        description: 'Mitocôndrias e respiração',
        colorInt: 4292557552,
        cardCount: 15,
        studiedTodayCount: 5,
        createdAt: DateTime.now(),
      ),
    ];

    final fakeRepo = FakeFlashcardRepository(mockDecks: decks);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardRepositoryProvider.overrideWithValue(fakeRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const FlashcardsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Biologia Celular'), findsOneWidget);
    expect(find.text('Mitocôndrias e respiração'), findsOneWidget);
  });
}
