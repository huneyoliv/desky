import 'dart:io';
import 'dart:ui' as ui;

import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/planner/planner_screen.dart' show plannerRepositoryProvider;
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/todo/classic_todo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TodoItemModel _todo(int id, int subjectId, String title, bool done) => TodoItemModel(
      id: id,
      subjectId: subjectId,
      subjectTitle: '',
      subjectColorInt: 0xFFFF2D78,
      title: title,
      isCompleted: done,
      dateYmd: '2026-11-19',
      parentId: null,
      recurrenceRule: null,
      startAtRaw: '',
      startAt: null,
    );

class _Planner extends PlannerRepository {
  @override
  Future<List<TodoItemModel>> fetchTodos(String dateYmd, {required Duration gmtOffset, int resetHour = 5}) async => [
        _todo(1, 1, 'Read Ram Ahuja ch. 3', true),
        _todo(2, 1, 'Answer writing: 2 questions', false),
        _todo(3, 2, 'Essay outline: technology and ethics', false),
      ];
}

class _Subjects extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async =>
      const SubjectFetchResult(subjects: [
        SubjectModel(id: 1, title: 'Sociology', colorInt: 0xFFFF2D78),
        SubjectModel(id: 2, title: 'Essay', colorInt: 0xFF2F7CF6),
        SubjectModel(id: 3, title: 'GS1', colorInt: 0xFFFF5A1F),
      ], todayTotalMs: 0);
}

void main() {
  testWidgets('Classic To-Do groups tasks under their subjects', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        plannerRepositoryProvider.overrideWithValue(_Planner()),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
        timerRepositoryProvider.overrideWithValue(TimerRepository()),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const RepaintBoundary(key: ValueKey('shot'), child: ClassicTodoScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Answer writing: 2 questions'), findsOneWidget);
    expect(find.text('Sociology'), findsOneWidget);

    final dir = Platform.environment['DESKY_SCREENSHOTS'];
    if (dir != null) {
      await tester.runAsync(() async {
        await (FontLoader('Roboto')
              ..addFont(File('assets/fonts/Pretendard-Regular.otf').readAsBytes().then(ByteData.sublistView)))
            .load();
      });
      await tester.pump();
      await tester.runAsync(() async {
        final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
        final img = await b.toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/todo.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });
}
