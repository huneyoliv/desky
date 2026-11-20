import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/classic_layout.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import 'stats_data.dart';
import 'stats_provider.dart';
import 'widgets/stat_charts.dart';

/// The Classic look's Calendar tab: a full-width month with each day's study
/// time as an orange chip, the way the YPT desktop app shows it.
class StudyCalendarScreen extends ConsumerStatefulWidget {
  const StudyCalendarScreen({super.key});

  @override
  ConsumerState<StudyCalendarScreen> createState() => _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends ConsumerState<StudyCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final data = ref.watch(statisticsDataProvider).valueOrNull ?? StatsData.empty;
    final today = dateOnly(DateTime.now());
    final first = DateTime(_month.year, _month.month);
    final last = DateTime(_month.year, _month.month + 1, 0);
    final start = mondayOf(first);
    final weeks = ((last.difference(start).inDays + 1) / 7).ceil();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      backgroundColor: palette.background,
      body: ClassicPage(
        maxWidth: 1400,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(DateFormat('MMM y').format(_month),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: palette.textSecondary),
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: palette.textSecondary),
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _month = DateTime(today.year, today.month)),
                    child: Text(t.tr('stats_today', fallback: 'Today'),
                        style: const TextStyle(fontSize: 14, color: kStatOrange)),
                  ),
                  const Spacer(),
                  Text(
                    '${t.tr('stats_total_time', fallback: 'Total time')}: '
                    '${formatHms(data.totalBetween(first, last))}',
                    style: TextStyle(fontSize: 14, color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                for (final w in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(w, style: TextStyle(fontSize: 13, color: palette.textMuted)),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  children: [
                    for (var w = 0; w < weeks; w++)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var d = 0; d < 7; d++)
                              Expanded(
                                child: _DayCell(
                                  day: start.add(Duration(days: w * 7 + d)),
                                  inMonth: start.add(Duration(days: w * 7 + d)).month == _month.month,
                                  isToday: start.add(Duration(days: w * 7 + d)) == today,
                                  ms: data.msOn(start.add(Duration(days: w * 7 + d))),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.inMonth, required this.isToday, required this.ms});
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final int ms;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: isToday ? const BoxDecoration(color: Colors.white, shape: BoxShape.circle) : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.black : (inMonth ? palette.textPrimary : palette.textMuted),
                ),
              ),
            ),
          ),
          if (ms > 0 && inMonth)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: kStatOrange.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '⏱ ${formatHm(ms)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kStatOrange),
              ),
            ),
        ],
      ),
    );
  }
}
