import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/ranks/widgets/heatmap_grid.dart';
import 'package:desky/features/ranks/widgets/study_calendar.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/settings_state.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/core/utils/study_day_helper.dart';
import 'package:desky/core/theme/theme_palette.dart';

class _DaySettingsNotifier extends SettingsNotifier {
  _DaySettingsNotifier(super.repository);

  @override
  Future<void> init() async {}
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required Map<String, int> dailyTimes,
  required DateTime month,
  required ValueChanged<DateTime> onMonthChanged,
  SettingsNotifier? settings,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
        if (settings != null)
          settingsNotifierProvider.overrideWith((ref) => settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyCalendar(
              dailyStudyTimeMs: dailyTimes,
              month: month,
              onMonthChanged: onMonthChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
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

  testWidgets('StudyCalendar renders the requested month and its study times',
      (tester) async {
    final dailyTimes = {
      '2026-08-10': 7200000,
      '2026-08-15': 14400000,
    };

    await _pumpCalendar(
      tester,
      dailyTimes: dailyTimes,
      month: DateTime(2026, 8),
      onMonthChanged: (_) {},
    );

    expect(find.byType(StudyCalendar), findsOneWidget);
    expect(find.text('Seg'), findsOneWidget);
    expect(find.text('Dom'), findsOneWidget);
    // Times come from the requested month, not from "today".
    expect(find.text('2h 0m'), findsOneWidget);
    expect(find.text('4h 0m'), findsOneWidget);
  });

  testWidgets('StudyCalendar requests the previous month', (tester) async {
    DateTime? requested;

    await _pumpCalendar(
      tester,
      dailyTimes: const {},
      month: DateTime(2026, 8),
      onMonthChanged: (month) => requested = month,
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(requested, isNotNull);
    expect(requested!.year, equals(2026));
    expect(requested!.month, equals(7));
  });

  testWidgets('StudyCalendar never navigates past the current month',
      (tester) async {
    DateTime? requested;
    final now = DateTime.now();

    await _pumpCalendar(
      tester,
      dailyTimes: const {},
      month: now,
      onMonthChanged: (month) => requested = month,
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(requested, isNull,
        reason: 'no mes corrente o avanco fica desabilitado');

    // On an older month forward navigation is available again.
    await _pumpCalendar(
      tester,
      dailyTimes: const {},
      month: DateTime(now.year, now.month - 1),
      onMonthChanged: (month) => requested = month,
    );
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(requested, isNotNull);
    expect(requested!.year, equals(now.year));
    expect(requested!.month, equals(now.month));
  });

  testWidgets('StudyCalendar highlights the effective country study day',
      (tester) async {
    const country = CountryModel(
      id: 144,
      name: 'SRI LANKA',
      code: 'LK',
      timezone: 'Asia/Colombo',
      continent: 'Asia',
      gmtOffset: 5.5,
      startTime: '12 AM',
    );
    final settings = _DaySettingsNotifier(SettingsRepository())
      ..state = const SettingsState(
        selectedCountry: country,
        dayResetHour: 0,
      );
    final expectedDay = DateTime.parse(
      StudyDayHelper.todayYmd(
        gmtOffset: const Duration(hours: 5, minutes: 30),
        resetHour: 0,
      ),
    );

    await _pumpCalendar(
      tester,
      dailyTimes: const {},
      month: expectedDay,
      onMonthChanged: (_) {},
      settings: settings,
    );

    final cell = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('${expectedDay.day}'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = cell.decoration as BoxDecoration;
    expect(
      decoration.border?.top.color,
      DeskyThemePalette.amoledLilac.primary,
    );
  });
}
