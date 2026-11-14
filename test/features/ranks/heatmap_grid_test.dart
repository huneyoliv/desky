import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/ranks/widgets/heatmap_grid.dart';
import 'package:desky/features/ranks/widgets/study_calendar.dart';

void main() {
  group('Stats Widgets Tests', () {
    testWidgets('HeatmapGrid renders without crashing', (tester) async {
      final hourlyLogs = {
        '2026-08-11': List.generate(24, (i) => i * 2),
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HeatmapGrid(hourlyLogs: hourlyLogs),
            ),
          ),
        ),
      );

      expect(find.text('Mapa de Calor de Estudos (24h x 30d)'), findsOneWidget);
    });

    testWidgets('HeatmapGrid renders an extra column for the overflow day',
        (tester) async {
      // Uma sessao das 23:50 com 30 min deixa 10 min na hora 23 do primeiro dia
      // e 20 min na hora 0 do dia seguinte. O dia de transbordo precisa aparecer
      // como coluna propria, mesmo sem log proprio na API.
      final firstDay = List.filled(24, 0)..[23] = 10;
      final overflowDay = List.filled(24, 0)..[0] = 20;
      final hourlyLogs = {
        '2026-11-07': firstDay,
        '2026-11-08': overflowDay,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HeatmapGrid(hourlyLogs: hourlyLogs),
              ),
            ),
          ),
        ),
      );

      // 2 dias x 24 horas.
      expect(find.byType(Tooltip), findsNWidgets(48));

      final messages = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((widget) => widget.message)
          .whereType<String>()
          .toList();

      expect(
        messages.any((m) =>
            m.startsWith('2026-11-08') && m.contains('00:00') && m.contains('20')),
        isTrue,
        reason: 'o dia de transbordo precisa renderizar os 20 min na hora 0',
      );
      expect(
        messages.any((m) =>
            m.startsWith('2026-11-07') && m.contains('23:00') && m.contains('10')),
        isTrue,
        reason: 'o dia original mantem os 10 min antes da meia-noite',
      );
    });

    testWidgets('StudyCalendar renders without crashing', (tester) async {
      final dailyMs = {
        '2026-08-11': 14400000, // 4 hours
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StudyCalendar(
                  dailyStudyTimeMs: dailyMs,
                  month: DateTime(2026, 8),
                  onMonthChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Calendário de Presença'), findsOneWidget);
    });
  });
}
