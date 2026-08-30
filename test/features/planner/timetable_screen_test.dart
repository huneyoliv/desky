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

  FakeTimetableRepository({this.mockBlocks = const []});

  @override
  Future<List<TimetableBlock>> fetchTimetable() async => mockBlocks;
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
}
