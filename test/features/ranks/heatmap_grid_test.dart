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

    testWidgets('StudyCalendar renders without crashing', (tester) async {
      final dailyMs = {
        '2026-08-11': 14400000, // 4 hours
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StudyCalendar(dailyStudyTimeMs: dailyMs),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Calendário de Presença'), findsOneWidget);
    });
  });
}
