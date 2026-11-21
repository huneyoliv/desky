import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/statistics/statistics_screen.dart';
import 'package:desky/features/statistics/stats_data.dart';
import 'package:desky/features/statistics/stats_provider.dart';
import 'package:desky/features/statistics/study_calendar_screen.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Subjects extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async =>
      const SubjectFetchResult(
        subjects: [
          SubjectModel(id: 1, title: 'GS1', colorInt: 0xFFFF6B6B),
          SubjectModel(id: 2, title: 'Essay', colorInt: 0xFF4DABF7),
          SubjectModel(id: 3, title: 'Prelims', colorInt: 0xFF69DB7C),
        ],
        todayTotalMs: 0,
      );
}

/// ~70 days of plausible sessions ending on [today].
StatsData fakeData(DateTime today) {
  final rnd = math.Random(4);
  const subjects = ['GS1', 'Essay', 'Prelims', 'Sociology'];
  final logs = <Map<String, dynamic>>[];
  for (var i = 70; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    if (rnd.nextInt(7) == 0) continue;
    final sessions = <Map<String, dynamic>>[];
    var at = day.add(Duration(hours: 7 + rnd.nextInt(4), minutes: rnd.nextInt(60)));
    var total = 0;
    for (var k = 0; k < 2 + rnd.nextInt(4); k++) {
      final minutes = 25 + rnd.nextInt(110);
      sessions.add({
        'st': at.toUtc().toIso8601String(),
        'sm': minutes * 60000,
        'sb': subjects[rnd.nextInt(subjects.length)],
      });
      total += minutes * 60000;
      at = at.add(Duration(minutes: minutes + 20 + rnd.nextInt(90)));
    }
    logs.add({
      'dt': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      'sm': total,
      'ls': sessions,
    });
  }
  return StatsData.fromPayloads([
    {'ls': logs},
  ]);
}

Future<ByteData> _file(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

Future<void> _loadFonts() async {
  await (FontLoader('SF-Pro-Text')..addFont(_file('assets/fonts/SF-Pro-Text-Regular.otf'))).load();
  final loader = FontLoader('Roboto')
    ..addFont(_file('assets/fonts/Pretendard-Regular.otf'))
    ..addFont(_file('assets/fonts/Pretendard-SemiBold.otf'));
  await loader.load();
}

/// Set DESKY_SCREENSHOTS to a directory to save PNGs of each tab for a visual check.
Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['DESKY_SCREENSHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  final today = DateTime(2026, 11, 19);

  Widget app(Widget home) => ProviderScope(
        overrides: [
          statisticsDataProvider.overrideWith((ref) async => fakeData(today)),
          subjectRepositoryProvider.overrideWithValue(_Subjects()),
          timerRepositoryProvider.overrideWithValue(TimerRepository()),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(key: const ValueKey('shot'), child: home),
        ),
      );

  testWidgets('every Statistics tab renders without layout errors', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(StatisticsScreen(now: today)));
    await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

    for (final tab in StatsTab.values) {
      await tester.tap(find.byKey(ValueKey('stats-tab-${tab.name}')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: tab.name);
      await _shot(tester, 'stats_${tab.name}');
    }
    expect(find.text('Total study time'), findsNothing); // on Trend now
  });

  testWidgets('Calendar tab shows daily study chips', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const StudyCalendarScreen()));
    await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await _shot(tester, 'calendar');
  });
}
