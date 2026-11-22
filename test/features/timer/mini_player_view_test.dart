import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/focus_mode_notifier.dart';
import 'package:desky/features/timer/mini_player_view.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Timer extends TimerRepository {
  @override
  Future<bool> startStudy({required String subjectTitle, required int subjectId, required DateTime startAt, int? taskId}) async =>
      true;
}

class _Subjects extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async =>
      const SubjectFetchResult(
        subjects: [SubjectModel(id: 1, title: 'newspaper', colorInt: 0xFFFF5A1F)],
        todayTotalMs: 0,
      );
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['DESKY_SCREENSHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    await (FontLoader('Roboto')
          ..addFont(File('assets/fonts/Pretendard-Regular.otf').readAsBytes().then(ByteData.sublistView)))
        .load();
  });
  await tester.pump();
  await tester.runAsync(() async {
    final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('mini player: play, expand to today/week, opacity is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(prefs: prefs);
    tester.view.physicalSize = kMiniExpandedSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        timerRepositoryProvider.overrideWithValue(_Timer()),
        subjectRepositoryProvider.overrideWithValue(_Subjects()),
        settingsNotifierProvider.overrideWith((ref) => SettingsNotifier(settings)),
        miniWeekFocusProvider.overrideWith((ref) async => 3 * 3600000),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          backgroundColor: Color(0xFF138A8A),
          body: RepaintBoundary(key: ValueKey('shot'), child: MiniPlayerView()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('mini-time')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mini-primary')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final container = ProviderScope.containerOf(tester.element(find.byType(MiniPlayerView)));
    expect(container.read(timerNotifierProvider).isRunning, isTrue);
    expect(find.text('newspaper'), findsOneWidget);
    await _shot(tester, 'mini_compact');

    await tester.tap(find.byKey(const ValueKey('mini-expand')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(focusModeProvider).miniExpanded, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('3h 0m'), findsOneWidget);
    await _shot(tester, 'mini_expanded');

    await tester.tap(find.byKey(const ValueKey('mini-more')));
    await tester.pump(const Duration(milliseconds: 400));
    final slider = find.byKey(const ValueKey('mini-opacity'));
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(settingsNotifierProvider).miniOpacity, closeTo(0.3, 0.01));
    expect(await settings.getMiniOpacity(), closeTo(0.3, 0.01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
