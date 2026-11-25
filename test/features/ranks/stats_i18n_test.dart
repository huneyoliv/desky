import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/ranks/stats_derivations.dart';
import 'package:desky/features/ranks/widgets/cumulative_and_quarter.dart';
import 'package:desky/features/ranks/widgets/stats_summary_cards.dart';

const _locales = [
  'pt',
  'en',
  'es',
  'ko',
  'ja',
  'zh-CN',
  'zh-TW',
  'fr',
  'de',
  'it',
  'ru',
];

const _today = {
  'pt': 'Hoje vs ontem',
  'en': 'Today vs yesterday',
  'es': 'Hoy vs ayer',
  'ko': '오늘 vs 어제',
  'ja': '今日 vs 昨日',
  'zh-CN': '今天 vs 昨天',
  'zh-TW': '今天 vs 昨天',
  'fr': 'Aujourd’hui vs hier',
  'de': 'Heute vs gestern',
  'it': 'Oggi vs ieri',
  'ru': 'Сегодня vs вчера',
};

const _week = {
  'pt': 'Esta semana vs anterior',
  'en': 'This week vs last week',
  'es': 'Esta semana vs anterior',
  'ko': '이번 주 vs 지난주',
  'ja': '今週 vs 先週',
  'zh-CN': '本周 vs 上周',
  'zh-TW': '本週 vs 上週',
  'fr': 'Cette semaine vs précédente',
  'de': 'Diese Woche vs letzte Woche',
  'it': 'Questa settimana vs precedente',
  'ru': 'Эта неделя vs предыдущая',
};

const _month = {
  'pt': 'Este mês vs anterior',
  'en': 'This month vs last month',
  'es': 'Este mes vs anterior',
  'ko': '이번 달 vs 지난달',
  'ja': '今月 vs 先月',
  'zh-CN': '本月 vs 上月',
  'zh-TW': '本月 vs 上月',
  'fr': 'Ce mois vs précédent',
  'de': 'Dieser Monat vs letzter Monat',
  'it': 'Questo mese vs precedente',
  'ru': 'Этот месяц vs предыдущий',
};

String _dateLocale(String code) => switch (code) {
      'zh-CN' => 'zh_CN',
      'zh-TW' => 'zh_TW',
      _ => code,
    };

Future<void> _pump(
  WidgetTester tester,
  String locale,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(locale),
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = AppTranslation(languageCode: locale),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('stats comparison keys resolve in all eleven languages', () {
    for (final locale in _locales) {
      final t = AppTranslation(languageCode: locale);
      expect(
        t.tr('stats_compare_today', fallback: 'sentinel'),
        _today[locale],
        reason: locale,
      );
      expect(
        t.tr('stats_compare_week', fallback: 'sentinel'),
        _week[locale],
        reason: locale,
      );
      expect(
        t.tr('stats_compare_month', fallback: 'sentinel'),
        _month[locale],
        reason: locale,
      );
    }
  });

  testWidgets('comparison card uses the selected locale', (tester) async {
    await _pump(
      tester,
      'en',
      StatsComparisonCard(
        comparisons: StatsDerivations.comparePeriods(
          {'2026-11-23': 3600000, '2026-11-22': 1800000},
          now: DateTime(2026, 11, 23),
        ),
      ),
    );

    expect(find.text('Today vs yesterday'), findsOneWidget);
    expect(find.text('This week vs last week'), findsOneWidget);
    expect(find.text('This month vs last month'), findsOneWidget);
  });

  testWidgets('quarter month labels use DateFormat for every locale',
      (tester) async {
    for (final locale in _locales) {
      await _pump(
        tester,
        locale,
        QuarterlyCalendar(
          quarterDays: StatsDerivations.quarterDays(
            {'2026-02-10': 3600000},
            month: DateTime(2026, 2),
          ),
          month: DateTime(2026, 2),
          onMonthChanged: (_) {},
        ),
      );

      final expected =
          DateFormat('MMM', _dateLocale(locale)).format(DateTime(2026, 2));
      expect(find.text(expected), findsOneWidget, reason: locale);
    }
  });
}
