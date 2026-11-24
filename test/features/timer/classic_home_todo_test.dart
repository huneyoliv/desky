import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/planner/planner_screen.dart' show plannerRepositoryProvider;
import 'package:desky/features/timer/classic_timer_screen.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TodoItemModel _todo(int id, String title, String day, {bool done = false}) => TodoItemModel(
      id: id,
      subjectTitle: '',
      subjectColorInt: 0xFFFF5A1F,
      title: title,
      isCompleted: done,
      dateYmd: day,
    );

class _Planner extends PlannerRepository {
  final created = <(String, String)>[];
  String? today;

  @override
  Future<List<TodoItemModel>> fetchTodos(String dateYmd, {required Duration gmtOffset, int resetHour = 5}) async =>
      [_todo(9, 'Ticked today', dateYmd, done: true)];

  @override
  Future<List<TodoItemModel>> fetchOpenTodos(String fromYmd, String toYmd,
      {required Duration gmtOffset, int resetHour = 5}) async {
    today = toYmd;
    return [
      _todo(1, 'Old open task', fromYmd),
      _todo(2, 'Open today', toYmd),
      for (final c in created) _todo(100, c.$1, c.$2),
    ];
  }

  @override
  Future<TodoItemModel?> createTodo({
    required String title,
    required String dateYmd,
    required Duration gmtOffset,
    int resetHour = 5,
    int? subjectId,
    RecurrenceRuleModel? recurrenceRule,
  }) async {
    created.add((title, dateYmd));
    return _todo(100, title, dateYmd);
  }
}

class _Subjects extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async =>
      const SubjectFetchResult(subjects: [SubjectModel(id: 1, title: 'misc.', colorInt: 0xFF2F7CF6)], todayTotalMs: 0);
}

void main() {
  testWidgets('home To-Do: carries open tasks, hides ticked ones, + adds to today', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final planner = _Planner();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        plannerRepositoryProvider.overrideWithValue(planner),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
        timerRepositoryProvider.overrideWithValue(TimerRepository()),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const ClassicTimerScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Old open task'), findsOneWidget);
    expect(find.text('Open today'), findsOneWidget);
    expect(find.text('Ticked today'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('classic-home-todo-add')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('classic-home-todo-field')), 'Revise polity');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(planner.created, [('Revise polity', planner.today)]);
    expect(find.text('Revise polity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
