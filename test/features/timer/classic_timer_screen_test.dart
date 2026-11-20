import 'dart:io';
import 'dart:ui' as ui;

import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/features/planner/planner_screen.dart' show plannerRepositoryProvider;
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/classic_timer_screen.dart';
import 'package:desky/features/timer/focus_mode_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Timer extends TimerRepository {
  @override
  Future<bool> startStudy({required String subjectTitle, required int subjectId, required DateTime startAt}) async =>
      true;

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async =>
      {'s': true};
}

class _Planner extends PlannerRepository {
  @override
  Future<List<TodoItemModel>> fetchTodos(String dateYmd, {required Duration gmtOffset, int resetHour = 5}) async => [
        TodoItemModel(
          id: 1,
          subjectId: 3,
          subjectTitle: 'GS1',
          subjectColorInt: 0xFFFF5A1F,
          title: 'Read chapter 4',
          isCompleted: false,
          dateYmd: dateYmd,
          parentId: null,
          recurrenceRule: null,
          startAtRaw: '',
          startAt: null,
        ),
      ];
}

class _Subjects extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async =>
      const SubjectFetchResult(
        subjects: [
          SubjectModel(id: 1, title: 'Revision & Anki', colorInt: 0xFF2F7CF6, studyMs: 32000),
          SubjectModel(id: 2, title: 'CSAT', colorInt: 0xFFFFD60A, studyMs: 15000),
          SubjectModel(id: 3, title: 'GS1', colorInt: 0xFFFF5A1F),
          SubjectModel(id: 4, title: 'Sociology', colorInt: 0xFFFF2D78),
        ],
        todayTotalMs: 47000,
      );
}

Future<ByteData> _file(String path) async => ByteData.sublistView(await File(path).readAsBytes());

Future<void> _fonts() async {
  await (FontLoader('SF-Pro-Text')..addFont(_file('assets/fonts/SF-Pro-Text-Regular.otf'))).load();
  await (FontLoader('Roboto')..addFont(_file('assets/fonts/Pretendard-Regular.otf'))).load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['DESKY_SCREENSHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await b.toImage();
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('Classic timer: subject list, then studying, then Pomodoro', (tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        timerRepositoryProvider.overrideWithValue(_Timer()),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
        plannerRepositoryProvider.overrideWithValue(_Planner()),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const RepaintBoundary(key: ValueKey('shot'), child: ClassicTimerScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Revision & Anki'), findsOneWidget);
    expect(find.text('0:00:47'), findsWidgets);
    expect(find.text('Read chapter 4'), findsOneWidget); // wide: the To-Do pane
    expect(find.byKey(const ValueKey('classic-edit-subject')), findsOneWidget);
    await _shot(tester, 'classic_idle');

    // One OBS crop for every state: the timer box never moves or resizes.
    final area = find.byKey(const ValueKey('classic-timer-area'));
    final idleRect = tester.getRect(area);
    expect(idleRect.size, kClassicTimerAreaSize);

    final container = ProviderScope.containerOf(tester.element(find.byType(ClassicTimerScreen)));
    container.read(timerNotifierProvider.notifier).setTimerMode(TimerMode.pomodoro);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('0:25:00'), findsOneWidget);
    expect(tester.getRect(area), idleRect, reason: 'Pomodoro');
    await _shot(tester, 'classic_pomodoro');

    container.read(timerNotifierProvider.notifier).setTimerMode(TimerMode.stopwatch);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('GS1'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('classic-focus-time')), findsOneWidget);
    expect(tester.getRect(area), idleRect, reason: 'studying');
    await _shot(tester, 'classic_running');

    container.read(timerNotifierProvider.notifier).pauseStudy();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(container.read(timerNotifierProvider).isPaused, isTrue);
    expect(tester.getRect(area), idleRect, reason: 'break');
    await _shot(tester, 'classic_break');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Focus mode and mini player use the minimal Focusing view', (tester) async {
    tester.view.physicalSize = const Size(360, 208);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final focus = FocusModeNotifier()..state = const FocusModeState(isMiniPlayer: true, isStrictFocus: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        timerRepositoryProvider.overrideWithValue(_Timer()),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
        plannerRepositoryProvider.overrideWithValue(_Planner()),
        focusModeProvider.overrideWith((ref) => focus),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: const MaterialApp(home: ClassicTimerScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('classic-focusing-time')), findsOneWidget);
    expect(find.byKey(const ValueKey('classic-edit-subject')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tall 9:16 window gets one centred column without overflow', (tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(540, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        timerRepositoryProvider.overrideWithValue(_Timer()),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
        plannerRepositoryProvider.overrideWithValue(_Planner()),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const RepaintBoundary(key: ValueKey('shot'), child: ClassicTimerScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Read chapter 4'), findsNothing); // the To-Do pane is wide-only
    expect(find.byKey(const ValueKey('classic-timer-area')), findsOneWidget);
    await _shot(tester, 'classic_portrait');
    await tester.pumpWidget(const SizedBox());
  });
}
