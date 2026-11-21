import 'package:desky/features/statistics/stats_data.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _session(DateTime start, int minutes, String subject) => {
      'st': start.toUtc().toIso8601String(),
      'sm': minutes * 60000,
      'sb': subject,
    };

void main() {
  final day1 = DateTime(2026, 11, 16);
  final day2 = DateTime(2026, 11, 17);
  final data = StatsData.fromPayloads([
    {
      'ls': [
        {
          'dt': '2026-11-16',
          'sm': 150 * 60000,
          'ls': [
            _session(DateTime(2026, 11, 16, 9, 0), 60, 'GS1'),
            _session(DateTime(2026, 11, 16, 14, 0), 60, 'Essay'),
          ],
        },
        {
          'dt': '2026-11-17',
          'sm': 30 * 60000,
          'ls': [_session(DateTime(2026, 11, 17, 20, 30), 30, 'GS1')],
        },
      ],
    },
  ]);

  test('daily totals keep time the API reports without sessions', () {
    expect(data.msOn(day1), 150 * 60000);
    expect(data.subjectsOn(day1)[StatsData.unknownSubject], 30 * 60000);
    expect(data.totalBetween(day1, day2), 180 * 60000);
  });

  test('subject totals are sorted, largest first', () {
    final totals = data.subjectTotals(day1, day2);
    expect(totals.first.key, 'GS1');
    expect(totals.first.value, 90 * 60000);
  });

  test('span, max focus and study days', () {
    final span = data.spanOf(day1)!;
    expect(span.start, DateTime(2026, 11, 16, 9, 0));
    expect(span.end, DateTime(2026, 11, 16, 15, 0));
    expect(data.maxFocusMs(day1, day2), 60 * 60000);
    expect(data.studyDays(day1, day2), 2);
  });

  test('cumulative curve grows through the day', () {
    final curve = data.cumulativeByMinute(day1, stepMinutes: 60);
    expect(curve[9], 0);
    expect(curve[10], closeTo(60, 0.01));
    expect(curve.last, closeTo(120, 0.01));
  });

  test('formatting helpers', () {
    expect(formatHms((141 * 3600 + 40 * 60 + 47) * 1000), '141:40:47');
    expect(formatHm((4 * 60 + 50) * 60000), '4:50');
    expect(formatClock(DateTime(2026, 1, 1, 16, 59)), 'PM 4:59');
    expect(formatClock(DateTime(2026, 1, 1, 0, 5)), 'AM 12:05');
    expect(mondayOf(DateTime(2026, 11, 19)), DateTime(2026, 11, 16));
  });
}
