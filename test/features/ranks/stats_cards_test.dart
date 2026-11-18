import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/ranks/stats_derivations.dart';
import 'package:desky/features/ranks/widgets/cumulative_and_quarter.dart';
import 'package:desky/features/ranks/widgets/stats_summary_cards.dart';

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
  group('StatsComparisonCard', () {
    testWidgets('mostra estado vazio claro sem nenhum dado', (tester) async {
      await _pump(
        tester,
        StatsComparisonCard(
          comparisons: StatsDerivations.comparePeriods({}, now: DateTime(2026, 11, 11)),
        ),
      );

      expect(find.text('Comparações'), findsOneWidget);
      expect(find.text('Sem dados nos períodos comparados.'), findsOneWidget);
    });

    testWidgets('mostra as tres comparacoes quando ha dados', (tester) async {
      final byDay = {
        '2026-11-11': 60 * _min,
        '2026-11-10': 30 * _min,
      };

      await _pump(
        tester,
        StatsComparisonCard(
          comparisons: StatsDerivations.comparePeriods(byDay, now: DateTime(2026, 11, 11)),
        ),
      );

      expect(find.text('Hoje vs ontem'), findsOneWidget);
      expect(find.text('Esta semana vs anterior'), findsOneWidget);
      expect(find.text('Este mês vs anterior'), findsOneWidget);
      expect(find.text('Sem dados nos períodos comparados.'), findsNothing);
      // 60min contra 30min -> +100%.
      expect(find.text('+100%'), findsWidgets);
    });
  });

  group('StatsMaximaCard', () {
    testWidgets('mostra estado vazio sem dia com estudo', (tester) async {
      await _pump(
        tester,
        StatsMaximaCard(maxima: StatsDerivations.maxima({})),
      );

      expect(find.text('Recordes'), findsOneWidget);
      expect(
        find.text('Ainda não há um dia com estudo para calcular recordes.'),
        findsOneWidget,
      );
    });

    testWidgets('mostra os recordes quando ha dados', (tester) async {
      await _pump(
        tester,
        StatsMaximaCard(
          maxima: StatsDerivations.maxima({'2026-11-10': 200 * _min}),
        ),
      );

      expect(find.text('Melhor dia'), findsOneWidget);
      expect(find.text('2026-11-10'), findsOneWidget);
      expect(find.textContaining('Dias com estudo'), findsOneWidget);
    });
  });

  group('CumulativeSubjectCard', () {
    testWidgets('mostra estado vazio sem materias', (tester) async {
      await _pump(
        tester,
        CumulativeSubjectCard(
          series: StatsDerivations.cumulativeBySubject({}),
        ),
      );

      expect(find.text('Tempo acumulado por matéria'), findsOneWidget);
      expect(
        find.text('Sem sessões no período para acumular por matéria.'),
        findsOneWidget,
      );
    });

    testWidgets('renderiza a serie quando ha materias', (tester) async {
      await _pump(
        tester,
        CumulativeSubjectCard(
          series: StatsDerivations.cumulativeBySubject({
            '2026-11-09': {'Matemática': 30 * _min},
            '2026-11-10': {'Matemática': 30 * _min},
          }),
        ),
      );

      expect(find.text('Tempo acumulado por matéria'), findsOneWidget);
      expect(
        find.text('Sem sessões no período para acumular por matéria.'),
        findsNothing,
      );
      expect(find.text('Matemática'), findsOneWidget);
    });
  });

  group('QuarterlyCalendar', () {
    testWidgets('mostra estado vazio em trimestre sem dados', (tester) async {
      await _pump(
        tester,
        QuarterlyCalendar(
          quarterDays: StatsDerivations.quarterDays({}, month: DateTime(2026, 11)),
          month: DateTime(2026, 11),
          onMonthChanged: (_) {},
        ),
      );

      expect(find.text('Calendário trimestral'), findsOneWidget);
      expect(find.text('Nenhum dia com estudo neste trimestre.'), findsOneWidget);
      expect(find.text('T4 2026'), findsOneWidget);
    });

    testWidgets('navega entre trimestres', (tester) async {
      DateTime? changed;
      await _pump(
        tester,
        QuarterlyCalendar(
          quarterDays: StatsDerivations.quarterDays(
            {'2026-11-11': 30 * _min},
            month: DateTime(2026, 11),
          ),
          month: DateTime(2026, 11),
          onMonthChanged: (month) => changed = month,
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(changed, isNotNull);
      expect(changed!.month, equals(2));
      expect(changed!.year, equals(2027));
    });
  });
}