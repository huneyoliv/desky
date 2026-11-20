import 'dart:math' as math;

/// One study session with its subject, as the Statistics screen needs it.
class StatSession {
  const StatSession({
    required this.day,
    required this.start,
    required this.ms,
    required this.subject,
  });

  /// Study day the API groups the session under (`dt`, date only).
  final DateTime day;

  /// Wall-clock start in the device timezone.
  final DateTime start;
  final int ms;
  final String subject;

  DateTime get end => start.add(Duration(milliseconds: ms));
}

/// Date-only value (local midnight).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d].
DateTime mondayOf(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// Every study session and daily total of a date window.
///
/// Built once from the `/logs/range/days` payload; every chart of the
/// Statistics screen is a pure function of this object, so it is easy to test.
class StatsData {
  StatsData._(this.sessions, this.dailyMs, this.dailySubjectMs);

  static final StatsData empty = StatsData._(const [], const {}, const {});

  /// Subject used for time the API reports without per-session detail.
  static const String unknownSubject = '—';

  final List<StatSession> sessions;
  final Map<DateTime, int> dailyMs;
  final Map<DateTime, Map<String, int>> dailySubjectMs;

  factory StatsData.fromPayloads(Iterable<Map<String, dynamic>> payloads) {
    final sessions = <StatSession>[];
    final daily = <DateTime, int>{};
    final dailySubject = <DateTime, Map<String, int>>{};

    for (final payload in payloads) {
      final logs = payload['ls'];
      if (logs is! List) continue;
      for (final log in logs) {
        if (log is! Map) continue;
        final parsedDay = DateTime.tryParse('${log['dt'] ?? ''}');
        if (parsedDay == null) continue;
        final day = DateTime(parsedDay.year, parsedDay.month, parsedDay.day);
        var attributed = 0;
        final raw = log['ls'];
        if (raw is List) {
          for (final s in raw) {
            if (s is! Map) continue;
            final ms = s['sm'] is int ? s['sm'] as int : 0;
            if (ms <= 0) continue;
            final subject = '${s['sb'] ?? ''}'.trim();
            final name = subject.isEmpty ? unknownSubject : subject;
            final buckets = dailySubject.putIfAbsent(day, () => {});
            buckets[name] = (buckets[name] ?? 0) + ms;
            attributed += ms;
            final start = DateTime.tryParse('${s['st'] ?? ''}')?.toLocal();
            if (start != null) {
              sessions.add(StatSession(day: day, start: start, ms: ms, subject: name));
            }
          }
        }
        final logMs = log['sm'] is int ? log['sm'] as int : 0;
        final total = math.max(attributed, logMs);
        if (total > 0) daily[day] = (daily[day] ?? 0) + total;
        if (logMs > attributed) {
          final buckets = dailySubject.putIfAbsent(day, () => {});
          buckets[unknownSubject] = (buckets[unknownSubject] ?? 0) + logMs - attributed;
        }
      }
    }
    sessions.sort((a, b) => a.start.compareTo(b.start));
    return StatsData._(sessions, daily, dailySubject);
  }

  int msOn(DateTime day) => dailyMs[dateOnly(day)] ?? 0;

  /// Total between [from] and [to], both inclusive (date only).
  int totalBetween(DateTime from, DateTime to) {
    final a = dateOnly(from), b = dateOnly(to);
    var sum = 0;
    dailyMs.forEach((d, ms) {
      if (!d.isBefore(a) && !d.isAfter(b)) sum += ms;
    });
    return sum;
  }

  List<StatSession> sessionsBetween(DateTime from, DateTime to) {
    final a = dateOnly(from), b = dateOnly(to);
    return sessions.where((s) => !s.day.isBefore(a) && !s.day.isAfter(b)).toList();
  }

  /// Subject totals of the window, largest first.
  List<MapEntry<String, int>> subjectTotals(DateTime from, DateTime to) {
    final a = dateOnly(from), b = dateOnly(to);
    final totals = <String, int>{};
    dailySubjectMs.forEach((d, buckets) {
      if (d.isBefore(a) || d.isAfter(b)) return;
      buckets.forEach((s, ms) => totals[s] = (totals[s] ?? 0) + ms);
    });
    final list = totals.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    return list;
  }

  Map<String, int> subjectsOn(DateTime day) => dailySubjectMs[dateOnly(day)] ?? const {};

  /// Longest single session of a window.
  int maxFocusMs(DateTime from, DateTime to) =>
      sessionsBetween(from, to).fold(0, (m, s) => math.max(m, s.ms));

  /// Number of days with any study in the window.
  int studyDays(DateTime from, DateTime to) {
    final a = dateOnly(from), b = dateOnly(to);
    return dailyMs.entries
        .where((e) => e.value > 0 && !e.key.isBefore(a) && !e.key.isAfter(b))
        .length;
  }

  /// First start and last end of a study day (null when nothing was logged).
  ({DateTime start, DateTime end})? spanOf(DateTime day) {
    final list = sessionsBetween(day, day);
    if (list.isEmpty) return null;
    var end = list.first.end;
    for (final s in list) {
      if (s.end.isAfter(end)) end = s.end;
    }
    return (start: list.first.start, end: end);
  }

  /// Cumulative minutes studied by each minute-of-day of [day], sampled every
  /// [stepMinutes]. Used by the "Up to now vs yesterday" step chart.
  List<double> cumulativeByMinute(DateTime day, {int stepMinutes = 30}) {
    final list = sessionsBetween(day, day);
    final base = dateOnly(day);
    final out = <double>[];
    for (var m = 0; m <= 24 * 60; m += stepMinutes) {
      final at = base.add(Duration(minutes: m));
      var sum = 0.0;
      for (final s in list) {
        if (!s.start.isBefore(at)) continue;
        final until = s.end.isBefore(at) ? s.end : at;
        sum += until.difference(s.start).inSeconds / 60.0;
      }
      out.add(sum);
    }
    return out;
  }

  /// Average session length (minutes) by the hour the session started.
  List<double> avgFocusByHour(DateTime from, DateTime to) {
    final sum = List<double>.filled(24, 0), count = List<int>.filled(24, 0);
    for (final s in sessionsBetween(from, to)) {
      sum[s.start.hour] += s.ms / 60000.0;
      count[s.start.hour]++;
    }
    return [for (var h = 0; h < 24; h++) count[h] == 0 ? 0 : sum[h] / count[h]];
  }

  /// Average session length (minutes) per weekday, Monday first.
  List<double> avgFocusByWeekday(DateTime from, DateTime to) {
    final sum = List<double>.filled(7, 0), count = List<int>.filled(7, 0);
    for (final s in sessionsBetween(from, to)) {
      sum[s.day.weekday - 1] += s.ms / 60000.0;
      count[s.day.weekday - 1]++;
    }
    return [for (var d = 0; d < 7; d++) count[d] == 0 ? 0 : sum[d] / count[d]];
  }
}

/// "141:40:47" style: hours are not wrapped at 24.
String formatHms(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// "4:50" style (hours:minutes), used inside calendar cells.
String formatHm(int ms) {
  final totalMin = ms ~/ 60000;
  return '${totalMin ~/ 60}:${(totalMin % 60).toString().padLeft(2, '0')}';
}

/// "11h 32m" style.
String formatHourMin(int ms) {
  final totalMin = ms ~/ 60000;
  final h = totalMin ~/ 60, m = totalMin % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// "PM 4:59" style, the way YPT prints clock times.
String formatClock(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${t.hour < 12 ? 'AM' : 'PM'} $h12:${t.minute.toString().padLeft(2, '0')}';
}
