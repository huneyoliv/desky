import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/timetable_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timetable_repository.dart';
import 'package:desky/features/planner/timetable_screen.dart';

class FakeTimetableRepository extends TimetableRepository {
  final List<TimetableBlock> mockBlocks;
  final TimetableBlock? createResponse;
  final bool deleteResponse;
  final bool failFetch;

  FakeTimetableRepository({
    this.mockBlocks = const [],
    this.createResponse,
    this.deleteResponse = true,
    this.failFetch = false,
  });

  @override
  Future<List<TimetableBlock>> fetchTimetable() async {
    if (failFetch) throw Exception('fetch failed');
    return mockBlocks;
  }

  @override
  Future<TimetableBlock?> createBlock({
    required int subjectId,
    required String subjectTitle,
    required int colorInt,
    required int dayOfWeek,
    required int startHour,
    required int endHour,
    int? timetableId,
  }) async =>
      createResponse;

  @override
  Future<bool> deleteBlock(int blockId) async => deleteResponse;
}

class FakeSubjectRepository extends SubjectRepository {
  final List<SubjectModel> mockSubjects;

  FakeSubjectRepository({this.mockSubjects = const []});

  @override
  Future<List<SubjectModel>> fetchSubjects({
    String? language,
    String? timezone,
    int? version,
  }) async => mockSubjects;
}

void main() {
  testWidgets('TimetableScreen renders day columns and timetable blocks', (tester) async {
    final blocks = [
      const TimetableBlock(
        id: 1,
        subjectId: 10,
        subjectTitle: 'História do Brasil',
        colorInt: 4292557552,
        dayOfWeek: 1,
        startHour: 8,
        endHour: 10,
      ),
    ];

    final subjects = [
      const SubjectModel(id: 10, title: 'História do Brasil', colorInt: 4292557552),
    ];

    final timetableRepo = FakeTimetableRepository(mockBlocks: blocks);
    final subjectRepo = FakeSubjectRepository(mockSubjects: subjects);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableRepositoryProvider.overrideWithValue(timetableRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const TimetableScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('História do Brasil'), findsWidgets);
  });

  testWidgets('shows an error when loading fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableRepositoryProvider.overrideWithValue(
            FakeTimetableRepository(failFetch: true),
          ),
          subjectRepositoryProvider.overrideWithValue(FakeSubjectRepository()),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o horário.'), findsOneWidget);
  });

  testWidgets('failed creation shows error and does not insert a local block',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableRepositoryProvider.overrideWithValue(FakeTimetableRepository()),
          subjectRepositoryProvider.overrideWithValue(
            FakeSubjectRepository(mockSubjects: const [
              SubjectModel(id: 10, title: 'Matemática', colorInt: 4292557552),
            ]),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo Horário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar a alteração no horário.'),
      findsOneWidget,
    );
    expect(find.text('Matemática'), findsNothing);
  });

  testWidgets('successful creation adds the block returned by the API',
      (tester) async {
    const created = TimetableBlock(
      id: 99,
      subjectId: 10,
      subjectTitle: 'Novo Bloco',
      colorInt: 4292557552,
      dayOfWeek: 1,
      startHour: 8,
      endHour: 10,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableRepositoryProvider.overrideWithValue(
            FakeTimetableRepository(createResponse: created),
          ),
          subjectRepositoryProvider.overrideWithValue(
            FakeSubjectRepository(mockSubjects: const [
              SubjectModel(id: 10, title: 'Matemática', colorInt: 4292557552),
            ]),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo Horário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Novo Bloco'), findsOneWidget);
  });

  testWidgets('failed deletion preserves the block and shows an error',
      (tester) async {
    const block = TimetableBlock(
      id: 1,
      subjectId: 10,
      subjectTitle: 'História do Brasil',
      colorInt: 4292557552,
      dayOfWeek: 1,
      startHour: 8,
      endHour: 10,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timetableRepositoryProvider.overrideWithValue(
            FakeTimetableRepository(
              mockBlocks: const [block],
              deleteResponse: false,
            ),
          ),
          subjectRepositoryProvider.overrideWithValue(
            FakeSubjectRepository(mockSubjects: const [
              SubjectModel(id: 10, title: 'Matemática', colorInt: 4292557552),
            ]),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('História do Brasil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('História do Brasil'), findsOneWidget);
    expect(
      find.text('Não foi possível salvar a alteração no horário.'),
      findsOneWidget,
    );
  });
}
