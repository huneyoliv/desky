import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/ranks/session_derivations.dart';
import 'package:desky/features/ranks/widgets/time_of_day_cards.dart';

const int _min = 60000;

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('AvgTimesCard', () {
    testWidgets('mostra estado vazio sem sessoes', (tester) async {
      await _pump(tester, AvgTimesCard(stats: TimeOfDayStats.empty));

      expect(find.text('Horários médios'), findsOneWidget);
      expect(
        find.text('Sem sessões no período para calcular horários.'),
        findsOneWidget,
      );
    });

    testWidgets('mostra inicio, fim e regularidade com dados', (tester) async {
      final stats = TimeOfDayStats.fromSessions(const [
        StudySession(day: '2026-11-09', startMinute: 9 * 60, durationMs: 60 * _min),
        StudySession(day: '2026-11-10', startMinute: 9 * 60 + 30, durationMs: 30 * _min),
      ]);

      await _pump(tester, AvgTimesCard(stats: stats));

      expect(find.text('Início médio'), findsOneWidget);
      expect(find.text('09:15'), findsOneWidget);
      expect(find.text('Término médio'), findsOneWidget);
      expect(find.text('Regularidade'), findsOneWidget);
      expect(find.textContaining('Sessões consideradas'), findsOneWidget);
      expect(
        find.text('Sem sessões no período para calcular horários.'),
        findsNothing,
      );
    });
  });

  group('SessionScatterCard', () {
    testWidgets('mostra estado vazio sem pontos', (tester) async {
      await _pump(tester, const SessionScatterCard(points: []));

      expect(find.text('Início × término das sessões'), findsOneWidget);
      expect(
        find.text('Sem sessões no período para cruzar início e término.'),
        findsOneWidget,
      );
    });

    testWidgets('renderiza o grafico quando ha pontos', (tester) async {
      final points = scatterPoints(const [
        StudySession(day: '2026-11-09', startMinute: 9 * 60, durationMs: 60 * _min),
      ]);

      await _pump(tester, SessionScatterCard(points: points));

      expect(
        find.text('Sem sessões no período para cruzar início e término.'),
        findsNothing,
      );
      expect(find.byType(ScatterChart), findsOneWidget);
    });
  });
}