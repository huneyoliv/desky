import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/rank_entry_model.dart';
import 'package:desky/data/repositories/rank_repository.dart';
import 'package:desky/features/ranks/ranks_screen.dart';

class FakeRankRepository extends RankRepository {
  final List<RankEntryModel> mockRanks;
  final int? mockMyRank;

  FakeRankRepository({
    this.mockRanks = const [],
    this.mockMyRank = 15,
  });

  @override
  Future<List<RankEntryModel>> fetchGlobalRanks({
    String period = 'day',
    int categoryId = 0,
    int countryId = 23,
    int page = 1,
  }) async => mockRanks;

  @override
  Future<int?> fetchMyCategoryRank({
    int categoryId = 0,
    int countryId = 23,
  }) async => mockMyRank;

  @override
  Future<Map<String, dynamic>> fetchUserStats({
    required int userId,
    required String startDate,
    required String endDate,
  }) async => {'s': true, 'ls': [], 'ss': []};
}

void main() {
  testWidgets('RanksScreen renders top podium and ranks list', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ranks = [
      const RankEntryModel(
        rank: 1,
        userId: 101,
        userName: 'Primeiro Lugar',
        studiconId: 1,
        studyMs: 36000000,
        categoryName: 'Medicina',
      ),
      const RankEntryModel(
        rank: 2,
        userId: 102,
        userName: 'Segundo Lugar',
        studiconId: 2,
        studyMs: 28800000,
        categoryName: 'Medicina',
      ),
      const RankEntryModel(
        rank: 3,
        userId: 103,
        userName: 'Terceiro Lugar',
        studiconId: 3,
        studyMs: 25200000,
        categoryName: 'Medicina',
      ),
      const RankEntryModel(
        rank: 4,
        userId: 104,
        userName: 'Quarto Lugar',
        studiconId: 4,
        studyMs: 21600000,
        categoryName: 'Medicina',
      ),
    ];

    final repo = FakeRankRepository(mockRanks: ranks, mockMyRank: 15);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RanksScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Primeiro Lugar'), findsOneWidget);
    expect(find.text('Segundo Lugar'), findsOneWidget);
    expect(find.text('Terceiro Lugar'), findsOneWidget);
    expect(find.text('Quarto Lugar'), findsOneWidget);
  });

  testWidgets('RanksScreen scope toggle switches between category and region', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeRankRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RanksScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Minha Categoria'), findsOneWidget);
    expect(find.text('Região'), findsOneWidget);

    // Tap on 'Região'
    await tester.tap(find.text('Região'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on 'Esta Semana'
    await tester.tap(find.text('Esta Semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Esta Semana'), findsOneWidget);
  });
}

