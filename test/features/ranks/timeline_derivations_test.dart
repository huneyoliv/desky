import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/ranks/session_derivations.dart';
import 'package:desky/features/ranks/timeline_derivations.dart';

StudySession _session(int start, int minutes, {String day = '2026-11-21'}) {
  return StudySession(
    day: day,
    startMinute: start,
    durationMs: minutes * 60000,
  );
}

void main() {
  test('orders sessions, filters the API day and calculates total and gaps', () {
    final summary = summarizeTimelineDay([
      _session(9 * 60, 15),
      _session(8 * 60, 30),
      _session(10, 5, day: '2026-11-20'),
    ], '2026-11-21');

    expect(summary.sessions.map((s) => s.startMinute), [480, 540]);
    expect(summary.totalStudyMs, 45 * 60000);
    expect(summary.gaps.single.startMinute, 510);
    expect(summary.gaps.single.endMinute, 540);
    expect(summary.totalGapMinutes, 30);
  });

  test('keeps a session crossing midnight on the API day without clipping', () {
    final summary = summarizeTimelineDay(
      [_session(23 * 60 + 50, 30)],
      '2026-11-21',
    );

    expect(summary.sessions.single.startMinute, 1430);
    expect(summary.sessions.single.endMinute, 1460);
    expect(formatMinuteOfDay(summary.sessions.single.endMinute), '24:20');
    expect(summary.totalStudyMs, 30 * 60000);
    expect(summarizeTimelineDay(summary.sessions, '2026-11-22').sessions, isEmpty);
  });

  test('empty and overlapping sessions never produce negative gaps', () {
    final empty = summarizeTimelineDay([], '2026-11-21');
    expect(empty.sessions, isEmpty);
    expect(empty.gaps, isEmpty);
    expect(empty.totalStudyMs, 0);

    final overlap = summarizeTimelineDay([
      _session(600, 90),
      _session(630, 15),
      _session(700, 10),
    ], '2026-11-21');
    expect(overlap.gaps.single.startMinute, 690);
    expect(overlap.gaps.single.endMinute, 700);
    expect(overlap.gaps.single.durationMinutes, 10);
    expect(overlap.totalStudyMs, 115 * 60000);
  });

  test('parser preserves subject, converts offset and keeps dt authoritative', () {
    final sessions = StudySessionParser.parse({
      'ls': [
        {
          'dt': '2026-11-20',
          'ls': [
            {
              'sb': 'Física',
              'sm': 1800000,
              'st': '2026-11-20T05:30:00+05:30',
              'ia': false,
              'ad': false,
            },
          ],
        },
      ],
    });

    expect(sessions.single.day, '2026-11-20');
    expect(sessions.single.subject, 'Física');
    final local = DateTime.parse('2026-11-20T05:30:00+05:30').toLocal();
    expect(sessions.single.startMinute, local.hour * 60 + local.minute);
    expect(sessions.single.durationMs, 1800000);
  });
}
