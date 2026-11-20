import 'dart:io';
import 'dart:ui' as ui;

import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
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
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        timerRepositoryProvider.overrideWithValue(_Timer()),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
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
    expect(find.text('0:00:47'), findsOneWidget);
    expect(find.byKey(const ValueKey('classic-edit-subject')), findsOneWidget);
    await _shot(tester, 'classic_idle');

    final container = ProviderScope.containerOf(tester.element(find.byType(ClassicTimerScreen)));
    container.read(timerNotifierProvider.notifier).setTimerMode(TimerMode.pomodoro);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining(RegExp('Focus time', caseSensitive: false)), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    await _shot(tester, 'classic_pomodoro');

    container.read(timerNotifierProvider.notifier).setTimerMode(TimerMode.stopwatch);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('GS1'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Current focus time'), findsOneWidget);
    expect(find.byKey(const ValueKey('classic-focus-time')), findsOneWidget);
    await _shot(tester, 'classic_running');
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
}
