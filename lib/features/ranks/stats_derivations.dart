import 'dart:math' as math;

/// Derived statistics that only need the daily totals (`dt` + `sm`) or the
/// per-subject daily totals (`dt` + `sb` + `sm`).
///
/// Everything here is pure so the numbers can be tested without a widget or an
/// API call. Callers pass a map keyed by 'yyyy-MM-dd'.
class StatsDerivations {
  StatsDerivations._();

  /// Reserved key used by the subject series for time with no subject.
  static const String otherSubjectsKey = '__others__';

  /// Sentinel used when the caller wants the "unknown subject" bucket merged.
  static const String unknownSubjectKey = '__unknown__';

  /// Sum of every day inside [start]..[end] (inclusive, day granularity).
  static int sumBetween(
    Map<String, int> byDayMs,
    DateTime start,
    DateTime end,
  ) {
    var total = 0;
    for (final entry in byDayMs.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null) continue;
      final d = DateTime(day.year, day.month, day.day);
      if (d.isBefore(DateTime(start.year, start.month, start.day))) continue;
      if (d.isAfter(DateTime(end.year, end.month, end.day))) continue;
      total += entry.value;
    }
    return total;
  }

  /// Monday of the week that contains [value].
  static DateTime weekStart(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Today against yesterday, this week against last week and this month
  /// against last month. Days without data contribute zero, so a comparison is
  /// still meaningful when one of the periods is empty.
  static List<PeriodComparison> comparePeriods(
    Map<String, int> byDayMs, {
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final thisWeekStart = weekStart(today);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

    final thisMonthStart = DateTime(today.year, today.month, 1);
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = DateTime(today.year, today.month, 0);

    return [
      PeriodComparison(
        key: 'today',
        currentMs: sumBetween(byDayMs, today, today),
        previousMs: sumBetween(byDayMs, yesterday, yesterday),
      ),
      PeriodComparison(
        key: 'week',
        currentMs: sumBetween(byDayMs, thisWeekStart, today),
        previousMs: sumBetween(byDayMs, lastWeekStart, lastWeekEnd),
      ),
      PeriodComparison(
        key: 'month',
        currentMs: sumBetween(byDayMs, thisMonthStart, today),
        previousMs: sumBetween(byDayMs, lastMonthStart, lastMonthEnd),
      ),
    ];
  }

  /// Highest single day, highest calendar week and highest calendar month.
  ///
  /// Windows that are still in progress are included as they are; the label in
  /// the UI makes clear they are partial.
  static StatsMaxima maxima(Map<String, int> byDayMs) {
    String? bestDayKey;
    var bestDayMs = 0;
    final byWeek = <String, int>{};
    final byMonth = <String, int>{};

    for (final entry in byDayMs.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null || entry.value <= 0) continue;
      if (entry.value > bestDayMs) {
        bestDayMs = entry.value;
        bestDayKey = entry.key;
      }
      final week = weekStart(day);
      final weekKey =
          '${week.year}-${_two(week.month)}-${_two(week.day)}';
      byWeek[weekKey] = (byWeek[weekKey] ?? 0) + entry.value;
      final monthKey = '${day.year}-${_two(day.month)}';
      byMonth[monthKey] = (byMonth[monthKey] ?? 0) + entry.value;
    }

    return StatsMaxima(
      bestDayKey: bestDayKey,
      bestDayMs: bestDayMs,
      bestWeekKey: _bestKey(byWeek),
      bestWeekMs: _bestValue(byWeek),
      bestMonthKey: _bestKey(byMonth),
      bestMonthMs: _bestValue(byMonth),
      dayCount: byDayMs.values.where((ms) => ms > 0).length,
    );
  }

  /// Running total per subject, one point per day, keeping the [topSubjects]
  /// largest subjects and folding the rest into a single bucket.
  ///
  /// Returns the ordered day keys and, for each subject, the cumulative
  /// milliseconds at every day (same length as the day list).
  static CumulativeSeries cumulativeBySubject(
    Map<String, Map<String, int>> byDaySubjectMs, {
    int topSubjects = 4,
  }) {
    final days = byDaySubjectMs.keys.toList()..sort();
    if (days.isEmpty) {
      return const CumulativeSeries(
        days: [],
        subjects: [],
        totals: {},
        totalsBySubject: {},
      );
    }

    final totalsBySubject = <String, int>{};
    for (final perSubject in byDaySubjectMs.values) {
      perSubject.forEach((subject, ms) {
        if (subject.isEmpty || ms <= 0) return;
        final key = subject == unknownSubjectKey ? otherSubjectsKey : subject;
        totalsBySubject[key] = (totalsBySubject[key] ?? 0) + ms;
      });
    }

    final ranked = totalsBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final kept = ranked.take(topSubjects).map((e) => e.key).toSet();
    final hasOthers = ranked.length > kept.length;

    final series = <String, List<int>>{};
    for (final subject in kept) {
      series[subject] = List.filled(days.length, 0);
    }
    if (hasOthers) series[otherSubjectsKey] = List.filled(days.length, 0);

    final running = <String, int>{};
    for (var i = 0; i < days.length; i++) {
      byDaySubjectMs[days[i]]!.forEach((subject, ms) {
        if (subject.isEmpty || ms <= 0) return;
        final key = subject == unknownSubjectKey ? otherSubjectsKey : subject;
        final bucket = kept.contains(key) ? key : otherSubjectsKey;
        running[bucket] = (running[bucket] ?? 0) + ms;
      });
      for (final subject in series.keys) {
        series[subject]![i] = running[subject] ?? 0;
      }
    }

    return CumulativeSeries(
      days: days,
      subjects: series.keys.toList(),
      totals: series,
      totalsBySubject: totalsBySubject,
    );
  }

  /// Daily totals keyed 'yyyy-MM-dd' for every day of the quarter that holds
  /// [month], so a calendar can render empty days as zero.
  static Map<String, int> quarterDays(
    Map<String, int> byDayMs, {
    required DateTime month,
  }) {
    final firstMonthOfQuarter = ((month.month - 1) ~/ 3) * 3 + 1;
    final out = <String, int>{};
    for (var offset = 0; offset < 3; offset++) {
      final m = firstMonthOfQuarter + offset;
      final first = DateTime(month.year, m, 1);
      final daysInMonth = DateTime(month.year, m + 1, 0).day;
      for (var d = 1; d <= daysInMonth; d++) {
        final key = '${first.year}-${_two(first.month)}-${_two(d)}';
        out[key] = byDayMs[key] ?? 0;
      }
    }
    return out;
  }

  /// Highest value across the quarter, used to scale the colour intensity.
  static int quarterPeak(Map<String, int> quarterDays) =>
      quarterDays.values.fold<int>(0, math.max);

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String? _bestKey(Map<String, int> values) {
    String? key;
    var best = 0;
    values.forEach((k, v) {
      if (v > best) {
        best = v;
        key = k;
      }
    });
    return key;
  }

  static int _bestValue(Map<String, int> values) =>
      values.values.fold<int>(0, math.max);
}

/// One comparison line: a period against the previous equivalent period.
class PeriodComparison {
  const PeriodComparison({
    required this.key,
    required this.currentMs,
    required this.previousMs,
  });

  final String key;
  final int currentMs;
  final int previousMs;

  int get deltaMs => currentMs - previousMs;

  bool get hasPrevious => previousMs > 0;

  /// Growth as a fraction of the previous period, or `null` when there is
  /// nothing to compare against (division by zero).
  double? get growth =>
      previousMs <= 0 ? null : (currentMs - previousMs) / previousMs;

  bool get hasAnyData => currentMs > 0 || previousMs > 0;
}

class StatsMaxima {
  const StatsMaxima({
    required this.bestDayKey,
    required this.bestDayMs,
    required this.bestWeekKey,
    required this.bestWeekMs,
    required this.bestMonthKey,
    required this.bestMonthMs,
    required this.dayCount,
  });

  final String? bestDayKey;
  final int bestDayMs;
  final String? bestWeekKey;
  final int bestWeekMs;
  final String? bestMonthKey;
  final int bestMonthMs;

  /// How many days actually carry time, so the UI can tell "no data" from
  /// "zero".
  final int dayCount;

  bool get hasData => bestDayMs > 0;
}

class CumulativeSeries {
  const CumulativeSeries({
    required this.days,
    required this.subjects,
    required this.totals,
    required this.totalsBySubject,
  });

  final List<String> days;
  final List<String> subjects;

  /// Subject -> cumulative value per day (same length as [days]).
  final Map<String, List<int>> totals;

  final Map<String, int> totalsBySubject;

  bool get hasData => days.isNotEmpty && totalsBySubject.isNotEmpty;
}