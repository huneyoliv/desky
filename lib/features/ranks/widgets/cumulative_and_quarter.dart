import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../stats_derivations.dart';
import 'stats_summary_cards.dart';

/// Cumulative study time per subject across the visible range.
class CumulativeSubjectCard extends ConsumerWidget {
  const CumulativeSubjectCard({super.key, required this.series});

  final CumulativeSeries series;

  static const List<Color> _palette = [
    Color(0xFF6C8AE4),
    Color(0xFF4CB782),
    Color(0xFFE4A06C),
    Color(0xFFC46CE4),
    Color(0xFF8A9BAE),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final subjects = series.subjects;

    return StatsCard(
      title: t.tr('stats_cumulative_subject', fallback: 'Tempo acumulado por matéria'),
      isEmpty: !series.hasData,
      emptyMessage: t.tr('stats_no_cumulative',
          fallback: 'Sem sessões no período para acumular por matéria.'),
      trailing: Wrap(
        spacing: 10,
        children: [
          for (var i = 0; i < subjects.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _palette[i % _palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  subjects[i] == StatsDerivations.otherSubjectsKey
                      ? t.tr('others', fallback: 'Outros')
                      : subjects[i],
                  style: TextStyle(color: context.appTextSecondary, fontSize: 10),
                ),
              ],
            ),
        ],
      ),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (series.days.length - 1).toDouble().clamp(0, double.infinity),
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: context.appBorder,
                strokeWidth: 0.6,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) => Text(
                    '${(value / 3600000).toStringAsFixed(0)}h',
                    style: TextStyle(color: context.appTextMuted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: series.days.length <= 1
                      ? 1
                      : (series.days.length / 4).ceilToDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= series.days.length) {
                      return const SizedBox.shrink();
                    }
                    final day = series.days[index];
                    return Text(
                      day.substring(5),
                      style: TextStyle(color: context.appTextMuted, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              for (var i = 0; i < subjects.length; i++)
                LineChartBarData(
                  spots: [
                    for (var d = 0; d < series.days.length; d++)
                      FlSpot(d.toDouble(), (series.totals[subjects[i]]![d]).toDouble()),
                  ],
                  isCurved: false,
                  barWidth: 2.4,
                  color: _palette[i % _palette.length],
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: _palette[i % _palette.length].withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three month grid showing the whole quarter, with a clear empty state when
/// the account has no history in it.
class QuarterlyCalendar extends ConsumerWidget {
  const QuarterlyCalendar({
    super.key,
    required this.quarterDays,
    required this.month,
    required this.onMonthChanged,
  });

  final Map<String, int> quarterDays;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  static const List<String> _monthNames = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final peak = StatsDerivations.quarterPeak(quarterDays);
    final hasData = peak > 0;
    final quarterStart = ((month.month - 1) ~/ 3) * 3 + 1;

    return StatsCard(
      title: t.tr('stats_quarter', fallback: 'Calendário trimestral'),
      isEmpty: !hasData,
      emptyMessage: t.tr('stats_no_quarter',
          fallback: 'Nenhum dia com estudo neste trimestre.'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 18,
            onPressed: () => onMonthChanged(DateTime(month.year, month.month - 3)),
            icon: const Icon(Icons.chevron_left),
            tooltip: t.tr('previous_quarter', fallback: 'Trimestre anterior'),
          ),
          Text(
            'T${((month.month - 1) ~/ 3) + 1} ${month.year}',
            style: TextStyle(color: context.appTextSecondary, fontSize: 12),
          ),
          IconButton(
            iconSize: 18,
            onPressed: () => onMonthChanged(DateTime(month.year, month.month + 3)),
            icon: const Icon(Icons.chevron_right),
            tooltip: t.tr('next_quarter', fallback: 'Próximo trimestre'),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var offset = 0; offset < 3; offset++)
            _MonthRow(
              year: month.year,
              month: quarterStart + offset,
              quarterDays: quarterDays,
              peak: peak,
              label: _monthNames[(quarterStart + offset - 1) % 12],
            ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.year,
    required this.month,
    required this.quarterDays,
    required this.peak,
    required this.label,
  });

  final int year;
  final int month;
  final Map<String, int> quarterDays;
  final int peak;
  final String label;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              label,
              style: TextStyle(color: context.appTextSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                // Alinha o primeiro dia no dia da semana correto.
                for (var pad = 1; pad < firstWeekday; pad++)
                  const SizedBox(width: 12, height: 12),
                for (var day = 1; day <= daysInMonth; day++)
                  _DayCell(
                    ms: quarterDays[
                            '$year-${month.toString().padLeft(2, '0')}'
                            '-${day.toString().padLeft(2, '0')}'] ??
                        0,
                    peak: peak,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.ms, required this.peak});

  final int ms;
  final int peak;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color color;
    if (ms <= 0 || peak <= 0) {
      color = palette.surface;
    } else {
      final ratio = ms / peak;
      if (ratio < 0.25) {
        color = palette.heatmapL1;
      } else if (ratio < 0.5) {
        color = palette.heatmapL2;
      } else if (ratio < 0.75) {
        color = palette.heatmapL3;
      } else {
        color = palette.heatmapL4;
      }
    }

    return Tooltip(
      message: ms > 0 ? '${(ms / 3600000).toStringAsFixed(1)}h' : '',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}