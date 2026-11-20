import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/cdn/cdn_resolver.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../auth/auth_notifier.dart';
import '../timer/timer_notifier.dart';
import 'stats_data.dart';
import 'stats_provider.dart';
import 'widgets/stat_charts.dart';

enum StatsTab { day, week, month, period, trend }

/// Statistics in the YPT desktop layout: Day / Week / Month / Period / Trend,
/// each a two-column grid of cards.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key, this.now});

  /// Injectable clock for tests.
  final DateTime? now;

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  StatsTab _tab = StatsTab.day;
  late DateTime _today = dateOnly(widget.now ?? DateTime.now());
  late DateTime _day = _today;
  late DateTime _week = mondayOf(_today);
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _calendarMonth = DateTime(_today.year, _today.month);
  late int _quarterYear = _today.year;
  late int _quarter = (_today.month - 1) ~/ 3;
  int _periodDays = 28;
  String? _trendSubject;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final async = ref.watch(statisticsDataProvider);
    final subjects = ref.watch(timerNotifierProvider.select((s) => s.subjects));
    final colors = SubjectColors({for (final s in subjects) s.title: Color(s.colorInt)});
    _today = dateOnly(widget.now ?? DateTime.now());

    String label(StatsTab tab) => switch (tab) {
          StatsTab.day => t.tr('stats_tab_day', fallback: 'Day'),
          StatsTab.week => t.tr('stats_tab_week', fallback: 'Week'),
          StatsTab.month => t.tr('stats_tab_month', fallback: 'Month'),
          StatsTab.period => t.tr('stats_tab_period', fallback: 'Period'),
          StatsTab.trend => t.tr('stats_tab_trend', fallback: 'Trend'),
        };

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                for (final tab in StatsTab.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('stats-tab-${tab.name}'),
                      label: Text(label(tab)),
                      selected: _tab == tab,
                      showCheckmark: false,
                      selectedColor: kStatOrange,
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _tab == tab ? Colors.white : palette.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: t.tr('refresh', fallback: 'Refresh'),
                  icon: Icon(Icons.refresh_rounded, size: 18, color: palette.textSecondary),
                  onPressed: () => ref.invalidate(statisticsDataProvider),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: kStatOrange)),
              error: (e, _) => Center(
                child: Text(t.tr('stats_load_failed', fallback: 'Could not load statistics'),
                    style: TextStyle(color: palette.textSecondary)),
              ),
              data: (data) => _StatsViews(
                state: this,
                data: data,
                colors: colors,
                t: t,
              ).build(context),
            ),
          ),
        ],
      ),
    );
  }

  void update(VoidCallback fn) => setState(fn);
}

/// Builds the cards of the selected tab. Pure function of the state fields
/// and [data]; split from the State so the layout code stays readable.
class _StatsViews {
  _StatsViews({required this.state, required this.data, required this.colors, required this.t});

  final _StatisticsScreenState state;
  final StatsData data;
  final SubjectColors colors;
  final AppTranslation t;

  DateTime get today => state._today;
  String tr(String key, String fallback) => t.tr(key, fallback: fallback);

  Widget build(BuildContext context) {
    final (left, right) = switch (state._tab) {
      StatsTab.day => _day(context),
      StatsTab.week => _week(context),
      StatsTab.month => _month(context),
      StatsTab.period => _period(context),
      StatsTab.trend => _trend(context),
    };
    return LayoutBuilder(builder: (context, c) {
      Widget column(List<Widget> cards) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 10)],
            ],
          );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: c.maxWidth < 820
            ? column([...left, ...right])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column(left)),
                  const SizedBox(width: 10),
                  Expanded(child: column(right)),
                ],
              ),
      );
    });
  }

  // ---------------------------------------------------------------- shared

  /// Up to today: a period in the future only counts the days already lived.
  DateTime clampEnd(DateTime end) => end.isAfter(today) ? today : end;

  List<Slice> subjectSlices(DateTime from, DateTime to) => [
        for (final e in data.subjectTotals(from, to))
          if (e.value > 0) Slice(e.key, e.value, colors.of(e.key)),
      ];

  /// Study vs everything else in the elapsed part of the window.
  List<Slice> studyOther(DateTime from, DateTime to) {
    final end = clampEnd(to);
    final study = data.totalBetween(from, end);
    final days = end.difference(from).inDays + 1;
    var available = days * 86400000;
    if (!end.isBefore(today)) {
      final now = DateTime.now();
      available -= dateOnly(now).add(const Duration(days: 1)).difference(now).inMilliseconds;
    }
    return [
      Slice(tr('stats_study', 'Study'), study, kStatOrange),
      Slice(tr('stats_other', 'Other'), math.max(0, available - study), kStatGray),
    ];
  }

  List<DateTime> days(DateTime from, DateTime to) => [
        for (var d = dateOnly(from); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) d,
      ];

  /// Orange daily bars with the start (white) and end (grey) clock overlaid.
  Widget startEndBars(DateTime from, DateTime to, {int labelEvery = 1, String Function(DateTime)? fmt}) {
    final list = days(from, to);
    double? minuteOf(DateTime? t, DateTime day) =>
        t == null ? null : math.min(1440.0, t.difference(day).inMinutes.toDouble());
    final spans = [for (final d in list) data.spanOf(d)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubjectLegend(items: [
          (tr('stats_start_time', 'Start time'), Colors.white),
          (tr('stats_end_time', 'End time'), kStatGray),
        ]),
        const SizedBox(height: 4),
        BarsChart(
          height: 150,
          labelEvery: labelEvery,
          groups: [
            for (final d in list)
              BarGroup((fmt ?? (d) => '${d.month}/${d.day}')(d),
                  [(data.msOn(d) / 3600000, kStatOrange)],
                  highlight: d == today),
          ],
          overlays: [
            OverlayLine([for (var i = 0; i < list.length; i++) minuteOf(spans[i]?.start, list[i])],
                Colors.white, 1440),
            OverlayLine([for (var i = 0; i < list.length; i++) minuteOf(spans[i]?.end, list[i])],
                kStatGray, 1440),
          ],
        ),
      ],
    );
  }

  /// Stacked bars per day by subject, with a legend.
  Widget subjectBars(DateTime from, DateTime to, {int labelEvery = 1, String Function(DateTime)? fmt}) {
    final list = days(from, to);
    final top = data.subjectTotals(from, to).take(12).map((e) => e.key).toList();
    final maxMs = list.fold<int>(0, (m, d) => math.max(m, data.msOn(d)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarsChart(
          height: 140,
          labelEvery: labelEvery,
          maxLabel: '${tr('stats_daily_max', 'Daily max')}: ${formatHourMin(maxMs)}',
          groups: [
            for (final d in list)
              BarGroup((fmt ?? (d) => '${d.month}/${d.day}')(d), [
                for (final s in top) ((data.subjectsOn(d)[s] ?? 0) / 3600000, colors.of(s)),
              ]),
          ],
        ),
        const SizedBox(height: 6),
        SubjectLegend(items: [for (final s in top) (s, colors.of(s))]),
      ],
    );
  }

  Widget cumulative(DateTime from, DateTime to, {double? reference}) {
    final list = days(from, clampEnd(to));
    final top = data.subjectTotals(from, to).take(10).map((e) => e.key).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CumulativeAreaChart(
          reference: reference,
          layers: [
            for (final s in top)
              (colors.of(s), [for (final d in list) (data.subjectsOn(d)[s] ?? 0) / 3600000]),
          ],
        ),
        const SizedBox(height: 6),
        SubjectLegend(items: [for (final s in top) (s, colors.of(s))]),
      ],
    );
  }

  Widget startEndScatter(DateTime from, DateTime to) {
    final starts = <Offset>[], ends = <Offset>[];
    var sumStart = 0, sumEnd = 0, n = 0;
    for (final d in days(from, clampEnd(to))) {
      final span = data.spanOf(d);
      if (span == null) continue;
      final hours = data.msOn(d) / 3600000;
      final s = span.start.difference(d).inMinutes, e = span.end.difference(d).inMinutes;
      starts.add(Offset(s.toDouble(), hours));
      ends.add(Offset(math.min(1440, e).toDouble(), hours));
      sumStart += s;
      sumEnd += e;
      n++;
    }
    String avg(int sum) => n == 0 ? '—' : formatClock(today.add(Duration(minutes: sum ~/ n)));
    return ScatterChart(
      series: [(kStatOrange, starts), (kStatGray, ends)],
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _caption('${tr('stats_avg_start', 'Avg start')}\n${avg(sumStart)}'),
            _caption('${tr('stats_avg_end', 'Avg end')}\n${avg(sumEnd)}'),
          ],
        ),
      ),
    );
  }

  Widget _caption(String s) => Text(s,
      textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white60));

  /// "Up to now ±h:mm:ss" header plus the step chart.
  Widget compare(String refLabel, List<double> current, List<double> reference, int currentMs, int refMs) {
    final diff = currentMs - refMs;
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('stats_up_to_now', 'Up to now'),
                  style: const TextStyle(fontSize: 10, color: Colors.white60)),
              Text('${diff >= 0 ? '+' : '-'}${formatHms(diff.abs())}',
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 14, height: 2, color: kStatOrange),
                const SizedBox(width: 4),
                Text(tr('stats_today', 'Today'), style: const TextStyle(fontSize: 10, color: Colors.white60)),
              ]),
              Row(children: [
                Container(width: 14, height: 8, color: const Color(0xFFD1D1D6)),
                const SizedBox(width: 4),
                Text(refLabel, style: const TextStyle(fontSize: 10, color: Colors.white60)),
              ]),
            ],
          ),
        ),
        Expanded(child: StepCompareChart(current: current, reference: reference)),
      ],
    );
  }

  /// Cumulative hours by day for a window, cut at today.
  List<double> cumulativeDays(DateTime from, DateTime to, {bool cutAtToday = true}) {
    var acc = 0.0;
    return [
      for (final d in days(from, cutAtToday ? clampEnd(to) : to)) acc += data.msOn(d) / 3600000,
    ];
  }

  Widget navHeader(String title, VoidCallback prev, VoidCallback? next) => Row(
        children: [
          IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white70),
              onPressed: prev),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
          IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.chevron_right, size: 18, color: next == null ? Colors.white24 : Colors.white70),
              onPressed: next),
        ],
      );

  // ------------------------------------------------------------------- Day

  (List<Widget>, List<Widget>) _day(BuildContext context) {
    final day = state._day;
    final yesterday = day.subtract(const Duration(days: 1));
    final span = data.spanOf(day);
    final ms = data.msOn(day);
    final sessions = data.sessionsBetween(day, day);
    final user = state.ref.read(authStateProvider).user;
    final isToday = day == today;
    final nowStep = isToday ? (DateTime.now().hour * 2 + DateTime.now().minute ~/ 30) : 48;
    final current = data.cumulativeByMinute(day).take(nowStep + 1).toList();
    final reference = data.cumulativeByMinute(yesterday);
    final refMs = (reference.length > nowStep ? reference[nowStep] : reference.last) * 60000;

    final left = <Widget>[
      StatCard(child: _monthCalendar(context)),
      StatCard(
        title: DateFormat('EEE, MMM d, y').format(day),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                children: [
                  StudiconAvatar(
                    studiconId: user?.studiconId ?? -1,
                    pose: CdnResolver.resolvePose(isStudying: true, studyMs: ms),
                    size: 110,
                  ),
                  const SizedBox(height: 8),
                  Text(formatHms(ms), style: const TextStyle(fontSize: 18, color: kStatOrange)),
                ],
              ),
            ),
            SizedBox(width: 160, child: HourGrid(sessions: sessions, colorOf: colors.of)),
          ],
        ),
      ),
    ];

    final right = <Widget>[
      StatCard(
        title: DateFormat('EEE, MMM d').format(day),
        child: Column(children: [
          StatPair(items: [
            (tr('stats_total_study_time', 'Total study time'), formatHms(ms)),
            (tr('stats_max_focus_time', 'Max focus time'), formatHms(data.maxFocusMs(day, day))),
          ]),
          const SizedBox(height: 12),
          StatPair(items: [
            (tr('stats_start_time', 'Start time'), span == null ? '—' : formatClock(span.start)),
            (tr('stats_end_time', 'End time'), span == null ? '—' : formatClock(span.end)),
          ]),
        ]),
      ),
      StatCard(
        child: compare(tr('stats_yesterday', 'Yesterday'), current, reference, ms, refMs.round()),
      ),
      StatCard(
        title: tr('stats_ratio_by_subject', 'Ratio by subject'),
        child: DonutWithLegend(slices: subjectSlices(day, day)),
      ),
      StatCard(
        title: tr('stats_study_other_ratio', 'Study/other ratio'),
        child: DonutWithLegend(slices: studyOther(day, day)),
      ),
      StatCard(
        title: tr('stats_timeline', 'Timeline'),
        child: Column(
          children: [
            if (sessions.isEmpty)
              Text(tr('stats_no_sessions', 'No study sessions'),
                  style: const TextStyle(fontSize: 11, color: Colors.white38)),
            for (final s in sessions.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 3, height: 26, color: colors.of(s.subject)),
                title: Text(s.subject, style: const TextStyle(fontSize: 12, color: Colors.white)),
                subtitle: Text('${formatClock(s.start)} ~ ${formatClock(s.end)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white54)),
                trailing: Text(formatHourMin(s.ms),
                    style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ),
          ],
        ),
      ),
    ];
    return (left, right);
  }

  Widget _monthCalendar(BuildContext context) {
    final month = state._calendarMonth;
    final first = DateTime(month.year, month.month);
    final start = mondayOf(first);
    final last = DateTime(month.year, month.month + 1, 0);
    final cells = days(start, last.add(Duration(days: 7 - last.weekday)));
    final maxMs = cells.fold<int>(0, (m, d) => math.max(m, data.msOn(d)));
    final monthTotal = data.totalBetween(first, last);
    return Column(
      children: [
        navHeader(
          DateFormat('MMM y').format(month),
          () => state.update(() => state._calendarMonth = DateTime(month.year, month.month - 1)),
          month.year == today.year && month.month == today.month
              ? null
              : () => state.update(() => state._calendarMonth = DateTime(month.year, month.month + 1)),
        ),
        Row(children: [
          for (final w in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            Expanded(
              child: Center(child: Text(w, style: const TextStyle(fontSize: 9, color: Colors.white54))),
            ),
        ]),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          children: [
            for (final d in cells)
              GestureDetector(
                key: ValueKey('stats-day-${d.month}-${d.day}'),
                onTap: d.isAfter(today) ? null : () => state.update(() => state._day = d),
                child: Container(
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: d.month == month.month ? heatColor(data.msOn(d), maxMs) : const Color(0xFF1F1F21),
                    border: d == state._day ? Border.all(color: Colors.white70, width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${d.day}',
                          style: TextStyle(
                              fontSize: 10, color: d.month == month.month ? Colors.white : Colors.white30)),
                      if (data.msOn(d) > 0)
                        Text(formatHm(data.msOn(d)),
                            style: TextStyle(
                                fontSize: 9,
                                color: d.month == month.month ? Colors.white70 : Colors.white24)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${DateFormat('MMM').format(month)}: ${formatHourMin(monthTotal)}',
                style: const TextStyle(fontSize: 9, color: Colors.white38)),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ Week

  (List<Widget>, List<Widget>) _week(BuildContext context) {
    final from = state._week;
    final to = from.add(const Duration(days: 6));
    final prevFrom = from.subtract(const Duration(days: 7));
    final year = state._quarterYear, q = state._quarter;
    final qStart = mondayOf(DateTime(year, q * 3 + 1, 1));
    final qEnd = DateTime(year, q * 3 + 4, 0);
    final weeks = <DateTime>[
      for (var w = qStart; !w.isAfter(qEnd); w = w.add(const Duration(days: 7))) w,
    ];
    final total = data.totalBetween(from, to);
    final elapsed = clampEnd(to).difference(from).inDays + 1;
    final current = cumulativeDays(from, to);
    final reference = cumulativeDays(prevFrom, prevFrom.add(const Duration(days: 6)), cutAtToday: false);
    final refMs = data.totalBetween(prevFrom, prevFrom.add(Duration(days: current.length - 1)));
    String wd(DateTime d) => DateFormat('E').format(d);

    final left = <Widget>[
      StatCard(
        child: Column(children: [
          navHeader(
            '$year Q${q + 1}',
            () => state.update(() {
              if (q == 0) {
                state._quarter = 3;
                state._quarterYear--;
              } else {
                state._quarter--;
              }
            }),
            (year == today.year && q == (today.month - 1) ~/ 3)
                ? null
                : () => state.update(() {
                      if (q == 3) {
                        state._quarter = 0;
                        state._quarterYear++;
                      } else {
                        state._quarter++;
                      }
                    }),
          ),
          PeriodGrid(
            columns: 5,
            tiles: [
              for (final w in weeks)
                ('${w.month}/${w.day} ~', data.totalBetween(w, w.add(const Duration(days: 6))), w == from,
                    !w.isAfter(today)),
            ],
            onTap: (i) => state.update(() => state._week = weeks[i]),
          ),
        ]),
      ),
      StatCard(title: tr('stats_start_end_distribution', 'Study start/end time distribution'),
          child: startEndScatter(from, to)),
      StatCard(title: tr('stats_study_time_by_subject', 'Study time by subject'),
          child: subjectBars(from, to, fmt: wd)),
      StatCard(title: tr('stats_cumulative_study_time', 'Cumulative study time'),
          child: cumulative(from, to, reference: refMs / 3600000)),
    ];
    final right = <Widget>[
      StatCard(
        title: '${DateFormat('EEE, MMM d').format(from)} ~ ${DateFormat('EEE, MMM d').format(to)}',
        child: StatPair(items: [
          (tr('stats_total_time', 'Total time'), formatHms(total)),
          (tr('stats_daily_average', 'Daily average'), formatHms(total ~/ math.max(1, elapsed))),
        ]),
      ),
      StatCard(child: compare(tr('stats_last_week', 'Last week'), current, reference, total, refMs)),
      StatCard(child: startEndBars(from, to, fmt: wd)),
      StatCard(title: tr('stats_ratio_by_subject', 'Ratio by subject'),
          child: DonutWithLegend(slices: subjectSlices(from, to))),
      StatCard(title: tr('stats_study_other_ratio', 'Study/other ratio'),
          child: DonutWithLegend(slices: studyOther(from, to))),
    ];
    return (left, right);
  }

  // ----------------------------------------------------------------- Month

  (List<Widget>, List<Widget>) _month(BuildContext context) {
    final from = state._month;
    final to = DateTime(from.year, from.month + 1, 0);
    final prevFrom = DateTime(from.year, from.month - 1);
    final prevTo = DateTime(from.year, from.month, 0);
    final total = data.totalBetween(from, to);
    final elapsed = clampEnd(to).difference(from).inDays + 1;
    final current = cumulativeDays(from, to);
    final reference = cumulativeDays(prevFrom, prevTo, cutAtToday: false);
    final refEnd = DateTime(prevFrom.year, prevFrom.month, math.min(current.length, prevTo.day));
    final refMs = data.totalBetween(prevFrom, refEnd);
    String dayFmt(DateTime d) => '${d.month}/${d.day}';
    final year = from.year;

    final left = <Widget>[
      StatCard(
        child: Column(children: [
          navHeader(
            '$year',
            () => state.update(() => state._month = DateTime(year - 1, 12)),
            year >= today.year ? null : () => state.update(() => state._month = DateTime(year + 1, 1)),
          ),
          PeriodGrid(
            columns: 4,
            tiles: [
              for (var m = 1; m <= 12; m++)
                (
                  DateFormat('MMM').format(DateTime(year, m)),
                  data.totalBetween(DateTime(year, m), DateTime(year, m + 1, 0)),
                  m == from.month,
                  !DateTime(year, m).isAfter(today),
                ),
            ],
            onTap: (i) => state.update(() => state._month = DateTime(year, i + 1)),
          ),
        ]),
      ),
      StatCard(child: startEndBars(from, to, labelEvery: 7, fmt: dayFmt)),
      StatCard(title: tr('stats_ratio_by_subject', 'Ratio by subject'),
          child: DonutWithLegend(slices: subjectSlices(from, to))),
      StatCard(title: tr('stats_cumulative_study_time', 'Cumulative study time'),
          child: cumulative(from, to, reference: refMs / 3600000)),
    ];
    final right = <Widget>[
      StatCard(
        title: DateFormat('MMM y').format(from),
        child: StatPair(items: [
          (tr('stats_total_time', 'Total time'), formatHms(total)),
          (tr('stats_daily_average', 'Daily average'), formatHms(total ~/ math.max(1, elapsed))),
        ]),
      ),
      StatCard(child: compare(tr('stats_last_month', 'Last month'), current, reference, total, refMs)),
      StatCard(title: tr('stats_start_end_distribution', 'Study start/end time distribution'),
          child: startEndScatter(from, to)),
      StatCard(title: tr('stats_study_time_by_subject', 'Study time by subject'),
          child: subjectBars(from, to, labelEvery: 7, fmt: dayFmt)),
      StatCard(title: tr('stats_study_other_ratio', 'Study/other ratio'),
          child: DonutWithLegend(slices: studyOther(from, to))),
    ];
    return (left, right);
  }

  // ---------------------------------------------------------------- Period

  (List<Widget>, List<Widget>) _period(BuildContext context) {
    final n = state._periodDays;
    final to = today;
    final from = today.subtract(Duration(days: n - 1));
    final total = data.totalBetween(from, to);
    final list = days(from, to);
    final maxMs = list.fold<int>(0, (m, d) => math.max(m, data.msOn(d)));
    String dayFmt(DateTime d) => '${d.month}/${d.day}';
    final every = n <= 14 ? 1 : (n <= 31 ? 4 : 14);
    final byHour = data.avgFocusByHour(from, to);
    final byWeekday = data.avgFocusByWeekday(from, to);

    final left = <Widget>[
      StatCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<int>(
              value: n,
              dropdownColor: context.palette.card,
              underline: const SizedBox.shrink(),
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
              items: [
                for (final v in const [7, 14, 28, 90])
                  DropdownMenuItem(value: v, child: Text(tr('stats_last_n_days', 'Last {n} days').replaceAll('{n}', '$v'))),
              ],
              onChanged: (v) => state.update(() => state._periodDays = v ?? 28),
            ),
            Text('${DateFormat('M/d').format(from)} ~ ${DateFormat('M/d').format(to)} (${n}d)',
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final d in list)
                  Tooltip(
                    message: '${dayFmt(d)}  ${formatHm(data.msOn(d))}',
                    child: Container(
                      width: 22,
                      height: 18,
                      color: heatColor(data.msOn(d), maxMs),
                      alignment: Alignment.center,
                      child: Text('${d.day}', style: const TextStyle(fontSize: 8, color: Colors.white70)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      StatCard(title: tr('stats_subject_time_per_day', 'Subject time per day'),
          child: subjectBars(from, to, labelEvery: every, fmt: dayFmt)),
      StatCard(title: tr('stats_cumulative_by_subject', 'Cumulative time by subject'),
          child: cumulative(from, to)),
      StatCard(
        title: tr('stats_avg_focus_by_hour', 'Avg. focus time (min)'),
        child: BarsChart(
          height: 120,
          labelEvery: 3,
          valueLabel: null,
          groups: [
            for (var h = 0; h < 24; h++) BarGroup('$h', [(byHour[h], const Color(0xFF8A3A12))]),
          ],
        ),
      ),
      StatCard(title: tr('stats_consistency', 'Consistency'), child: startEndScatter(from, to)),
    ];
    final right = <Widget>[
      StatCard(
        title: tr('stats_subjects', 'Subjects'),
        child: StatPair(
          items: [
            (tr('stats_total_time', 'Total time'), formatHms(total)),
            (tr('stats_daily_average', 'Daily average'), formatHms(total ~/ n)),
          ],
        ),
      ),
      StatCard(title: tr('stats_subject_ratio', 'Subject ratio'),
          child: DonutWithLegend(slices: subjectSlices(from, to))),
      StatCard(title: tr('stats_start_end_per_day', 'Start/end per day'),
          child: startEndBars(from, to, labelEvery: every, fmt: dayFmt)),
      StatCard(
        title: tr('stats_avg_focus_per_weekday', 'Avg. focus time per day'),
        child: BarsChart(
          height: 120,
          valueLabel: (v) => v.toStringAsFixed(0),
          groups: [
            for (var i = 0; i < 7; i++)
              BarGroup(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                  [(byWeekday[i], i.isEven ? kStatOrange : const Color(0xFFD9541A))]),
          ],
        ),
      ),
    ];
    return (left, right);
  }

  // ----------------------------------------------------------------- Trend

  (List<Widget>, List<Widget>) _trend(BuildContext context) {
    final filter = state._trendSubject;
    final allSubjects = data
        .subjectTotals(today.subtract(const Duration(days: 240)), today)
        .map((e) => e.key)
        .toList();
    int ms(DateTime a, DateTime b) {
      if (filter == null) return data.totalBetween(a, b);
      var sum = 0;
      for (final d in days(a, b)) {
        sum += data.subjectsOn(d)[filter] ?? 0;
      }
      return sum;
    }

    final daily = [for (var i = 13; i >= 0; i--) today.subtract(Duration(days: i))];
    final weekly = [for (var i = 13; i >= 0; i--) mondayOf(today).subtract(Duration(days: 7 * i))];
    final monthly = [for (var i = 7; i >= 0; i--) DateTime(today.year, today.month - i)];
    DateTime monthEnd(DateTime m) => DateTime(m.year, m.month + 1, 0);
    DateTime weekEnd(DateTime w) => w.add(const Duration(days: 6));

    Widget totals(String title, List<(String, int)> buckets) {
      final maxMs = buckets.fold<int>(0, (m, b) => math.max(m, b.$2));
      return BarsChart(
        height: 110,
        maxLabel: '$title: ${formatHourMin(maxMs)}',
        groups: [for (final (l, v) in buckets) BarGroup(l, [(v / 3600000, kStatOrange)])],
      );
    }

    Widget stacked(List<(String, DateTime, DateTime)> buckets) {
      final top = allSubjects.take(12).toList();
      return BarsChart(
        height: 110,
        groups: [
          for (final (l, a, b) in buckets)
            BarGroup(l, [
              for (final s in top) (data.subjectTotals(a, b).where((e) => e.key == s).fold<int>(0, (x, e) => x + e.value) / 3600000, colors.of(s)),
            ]),
        ],
      );
    }

    final dailyB = [for (final d in daily) ('${d.month}/${d.day}', d, d)];
    final weeklyB = [for (final w in weekly) ('${w.month}/${w.day}~', w, weekEnd(w))];
    final monthlyB = [for (final m in monthly) (DateFormat('MMM').format(m), m, monthEnd(m))];

    final regularityDays = [for (var i = 20; i >= 0; i--) today.subtract(Duration(days: i))];
    final left = <Widget>[
      StatCard(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in [null, ...allSubjects.take(10)])
              ChoiceChip(
                label: Text(s ?? tr('stats_all', 'All')),
                selected: filter == s,
                showCheckmark: false,
                selectedColor: kStatOrange,
                labelStyle: TextStyle(fontSize: 11, color: filter == s ? Colors.white : Colors.white70),
                onSelected: (_) => state.update(() => state._trendSubject = s),
              ),
          ],
        ),
      ),
      StatCard(child: totals(tr('stats_daily_max', 'Daily max'), [for (final (l, a, b) in dailyB) (l, ms(a, b))])),
      StatCard(child: totals(tr('stats_weekly_max', 'Weekly max'), [for (final (l, a, b) in weeklyB) (l, ms(a, b))])),
      StatCard(child: totals(tr('stats_monthly_max', 'Monthly max'), [for (final (l, a, b) in monthlyB) (l, ms(a, b))])),
      StatCard(
        title: tr('stats_regularity', 'Study start/end regularity'),
        child: RangeBarsChart(ranges: [
          for (final d in regularityDays)
            if (data.spanOf(d) case final span?)
              (span.start.difference(d).inMinutes.toDouble(), span.end.difference(d).inMinutes.toDouble())
            else
              null,
        ]),
      ),
    ];
    final right = <Widget>[
      StatCard(child: SubjectLegend(items: [for (final s in allSubjects.take(12)) (s, colors.of(s))])),
      StatCard(child: stacked(dailyB)),
      StatCard(child: stacked(weeklyB)),
      StatCard(child: stacked(monthlyB)),
      StatCard(
        title: tr('stats_recent_days', 'Recent days'),
        child: Column(
          children: [
            for (final d in regularityDays.reversed.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(DateFormat('E, M/d').format(d),
                          style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    ),
                    Expanded(child: _DayStrip(sessions: data.sessionsBetween(d, d), colorOf: colors.of)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
    return (left, right);
  }
}

/// One day as a horizontal 24h strip with session blocks.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.sessions, required this.colorOf});
  final List<StatSession> sessions;
  final Color Function(String) colorOf;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 12,
        child: LayoutBuilder(builder: (context, c) {
          return Stack(children: [
            Container(color: const Color(0xFF2C2C2E)),
            for (final s in sessions)
              Positioned(
                left: c.maxWidth * (s.start.hour * 60 + s.start.minute) / 1440,
                width: math.max(2, c.maxWidth * (s.ms / 60000) / 1440),
                top: 0,
                bottom: 0,
                child: Container(color: colorOf(s.subject)),
              ),
          ]);
        }),
      );
}
