import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/ranks/widgets/heatmap_grid.dart';
import 'package:desky/features/ranks/widgets/study_calendar.dart';

void main() {
  testWidgets('HeatmapGrid renders hourly logs cleanly', (tester) async {
    final logs = {
      '2026-08-16': List.generate(24, (i) => i * 2),
      '2026-08-17': List.generate(24, (i) => i * 3),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeatmapGrid(hourlyLogs: logs),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(HeatmapGrid), findsOneWidget);
    expect(find.text('00h'), findsOneWidget);
    expect(find.text('23h'), findsOneWidget);
  });

  testWidgets('StudyCalendar renders monthly calendar days and study times', (tester) async {
    final dailyTimes = {
      '2026-08-10': 7200000,
      '2026-08-15': 14400000,
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudyCalendar(dailyStudyTimeMs: dailyTimes),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(StudyCalendar), findsOneWidget);
    expect(find.text('Seg'), findsOneWidget);
    expect(find.text('Dom'), findsOneWidget);
  });
}
