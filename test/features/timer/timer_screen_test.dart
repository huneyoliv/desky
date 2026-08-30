import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/features/timer/widgets/timer_display.dart';

class FakeTimerRepository extends TimerRepository {
  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
  }) async => true;

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async => {'s': true};
}

class FakeSubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String? language,
    String? timezone,
    int? version,
  }) async {
    return const SubjectFetchResult(
      subjects: [
        SubjectModel(id: 1, title: 'Biologia', colorInt: 4292557552),
      ],
      todayTotalMs: 3600000,
    );
  }
}

class EmptySubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String? language,
    String? timezone,
    int? version,
  }) async {
    return const SubjectFetchResult(
      subjects: [],
      todayTotalMs: 0,
    );
  }
}

void main() {
  testWidgets('TimerScreen renders study and rest headers and clean timer display', (tester) async {
    final timerRepo = FakeTimerRepository();
    final subjectRepo = FakeSubjectRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const TimerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tempo Total de Hoje'), findsOneWidget);
    expect(find.text('Tempo de Descanso'), findsNothing);
    expect(find.text('DESCANSO'), findsNothing);
    expect(find.byType(TimerDisplay), findsOneWidget);
    expect(find.text('INICIAR'), findsOneWidget);
    expect(find.textContaining('INICIAR ('), findsNothing);

    // Verify start button is enabled when subject is selected
    final startButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'INICIAR'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('TimerScreen start button is disabled when no subject is selected', (tester) async {
    final timerRepo = FakeTimerRepository();
    final emptyRepo = EmptySubjectRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(emptyRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          timerNotifierProvider.overrideWith((ref) {
            return TimerNotifier(
              timerRepository: timerRepo,
              subjectRepository: emptyRepo,
            );
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const TimerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final startButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'INICIAR'),
    );
    expect(startButton.onPressed, isNull);
  });
}
