import 'dart:math' as math;

/// One study session, already normalised.
///
/// `day` is the API's `dt` (the day the session is grouped under), [startMinute]
/// is the wall-clock minute of that day in the device timezone, and
/// [durationMs] is `sm`.
class StudySession {
  const StudySession({
    required this.day,
    required this.startMinute,
    required this.durationMs,
  });

  final String day;
  final int startMinute;
  final int durationMs;

  /// Minute of the day when the session ended, as reported by the API.
  int get endMinute => startMinute + (durationMs / 60000).round();
}

/// Single place that turns the raw `/logs/range/days` payload into sessions.
///
/// Several callers used to read `dt`, `st` and `sm` on their own, each with its
/// own quirks. New code goes through here so the rules stay in one place:
/// the day comes from `dt`, the hour from `st` converted to the device
/// timezone, and a session without a parseable start is dropped.
class StudySessionParser {
  StudySessionParser._();

  static List<StudySession> parse(Map<String, dynamic> userStats) {
    final out = <StudySession>[];
    final rawLogs = userStats['ls'];
    if (rawLogs is! List) return out;

    for (final log in rawLogs) {
      if (log is! Map<String, dynamic>) continue;
      final day = _normalizeDay(log['dt'] as String? ?? '');
      if (day.isEmpty) continue;

      final sessions = log['ls'];
      if (sessions is! List) continue;
      for (final session in sessions) {
        if (session is! Map<String, dynamic>) continue;
        final ms = session['sm'] as int? ?? 0;
        if (ms <= 0) continue;
        final start = DateTime.tryParse(session['st'] as String? ?? '')?.toLocal();
        if (start == null) continue;
        out.add(StudySession(
          day: day,
          startMinute: start.hour * 60 + start.minute,
          durationMs: ms,
        ));
      }
    }
    out.sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : a.startMinute.compareTo(b.startMinute);
    });
    return out;
  }

  static String _normalizeDay(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}'
        '-${parsed.day.toString().padLeft(2, '0')}';
  }
}

/// Time-of-day statistics derived from the sessions.
class TimeOfDayStats {
  const TimeOfDayStats({
    required this.sessionCount,
    required this.avgStartMinute,
    required this.avgEndMinute,
    required this.startStdDevMinutes,
    required this.earliestStartMinute,
    required this.latestStartMinute,
  });

  final int sessionCount;
  final int? avgStartMinute;
  final int? avgEndMinute;

  /// Spread of the start times. Zero means every session started at the same
  /// minute; a small value means a steady routine.
  final int? startStdDevMinutes;

  final int? earliestStartMinute;
  final int? latestStartMinute;

  bool get hasData => sessionCount > 0;

  static const TimeOfDayStats empty = TimeOfDayStats(
    sessionCount: 0,
    avgStartMinute: null,
    avgEndMinute: null,
    startStdDevMinutes: null,
    earliestStartMinute: null,
    latestStartMinute: null,
  );

  /// Averages are taken on the minute of the day. Sessions are attributed to
  /// `dt`, so a session that runs past midnight contributes a start near 23:5x
  /// and an end above 24:00; the end is therefore not wrapped back to zero,
  /// otherwise "average end" would collapse for a late-night routine.
  static TimeOfDayStats fromSessions(List<StudySession> sessions) {
    if (sessions.isEmpty) return empty;

    var startSum = 0;
    var endSum = 0;
    var earliest = 24 * 60;
    var latest = 0;
    for (final session in sessions) {
      startSum += session.startMinute;
      endSum += session.endMinute;
      earliest = math.min(earliest, session.startMinute);
      latest = math.max(latest, session.startMinute);
    }

    final mean = startSum / sessions.length;
    final variance = sessions.fold<double>(
          0,
          (acc, session) => acc + math.pow(session.startMinute - mean, 2).toDouble(),
        ) /
        sessions.length;

    return TimeOfDayStats(
      sessionCount: sessions.length,
      avgStartMinute: (startSum / sessions.length).round(),
      avgEndMinute: (endSum / sessions.length).round(),
      startStdDevMinutes: math.sqrt(variance).round(),
      earliestStartMinute: earliest,
      latestStartMinute: latest,
    );
  }
}

/// Start against end for every session, one point per session.
class SessionScatterPoint {
  const SessionScatterPoint({
    required this.startMinute,
    required this.endMinute,
    required this.day,
  });

  final int startMinute;
  final int endMinute;
  final String day;
}

List<SessionScatterPoint> scatterPoints(List<StudySession> sessions) {
  return [
    for (final session in sessions)
      SessionScatterPoint(
        startMinute: session.startMinute,
        endMinute: session.endMinute,
        day: session.day,
      ),
  ];
}

/// 'HH:mm' for a minute of the day, tolerating values past 24:00.
String formatMinuteOfDay(int minute) {
  final normalized = minute < 0 ? 0 : minute;
  final h = normalized ~/ 60;
  final m = normalized % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// How regular the routine is, in words, from the start-time deviation.
String regularityLabel(int? stdDevMinutes) {
  if (stdDevMinutes == null) return '—';
  if (stdDevMinutes <= 30) return 'muito regular';
  if (stdDevMinutes <= 90) return 'regular';
  if (stdDevMinutes <= 180) return 'irregular';
  return 'muito irregular';
}