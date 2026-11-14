import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../session_derivations.dart';

/// Average start and end, plus how regular the routine is.
class AvgTimesCard extends ConsumerWidget {
  const AvgTimesCard({super.key, required this.stats});

  final TimeOfDayStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);

    return _TimeCard(
      title: t.tr('stats_avg_times', fallback: 'Horários médios'),
      isEmpty: !stats.hasData,
      emptyMessage: t.tr('stats_no_time_of_day',
          fallback: 'Sem sessões no período para calcular horários.'),
      child: Column(
        children: [
          _TimeRow(
            label: t.tr('stats_avg_start', fallback: 'Início médio'),
            value: stats.avgStartMinute == null
                ? '—'
                : formatMinuteOfDay(stats.avgStartMinute!),
          ),
          const SizedBox(height: 12),
          _TimeRow(
            label: t.tr('stats_avg_end', fallback: 'Término médio'),
            value: stats.avgEndMinute == null
                ? '—'
                : formatMinuteOfDay(stats.avgEndMinute!),
          ),
          const SizedBox(height: 12),
          _TimeRow(
            label: t.tr('stats_regularity', fallback: 'Regularidade'),
            value: stats.startStdDevMinutes == null
                ? '—'
                : '±${stats.startStdDevMinutes}min',
            hint: regularityLabel(stats.startStdDevMinutes),
          ),
          const SizedBox(height: 16),
          Text(
            '${t.tr('stats_sessions_counted', fallback: 'Sessões consideradas')}'
            ': ${stats.sessionCount}',
            style: TextStyle(color: context.appTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Start time against end time, one dot per session.
class SessionScatterCard extends ConsumerWidget {
  const SessionScatterCard({super.key, required this.points});

  final List<SessionScatterPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);

    // Eixo em horas, com uma hora de respiro apos o maior término.
    final maxMinute = points.isEmpty
        ? 24 * 60
        : points.map((p) => p.endMinute).reduce((a, b) => a > b ? a : b);
    final axisMaxHours = ((maxMinute / 60).ceil() + 1).clamp(2, 30).toDouble();

    return _TimeCard(
      title: t.tr('stats_start_end', fallback: 'Início × término das sessões'),
      isEmpty: points.isEmpty,
      emptyMessage: t.tr('stats_no_scatter',
          fallback: 'Sem sessões no período para cruzar início e término.'),
      child: SizedBox(
        height: 220,
        child: ScatterChart(
          ScatterChartData(
            minX: 0,
            maxX: axisMaxHours,
            minY: 0,
            maxY: axisMaxHours,
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: context.appBorder, strokeWidth: 0.6),
              getDrawingVerticalLine: (_) =>
                  FlLine(color: context.appBorder, strokeWidth: 0.6),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 6,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}h',
                    style: TextStyle(color: context.appTextMuted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 6,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}h',
                    style: TextStyle(color: context.appTextMuted, fontSize: 10),
                  ),
                ),
              ),
            ),
            scatterSpots: [
              for (final point in points)
                ScatterSpot(
                  point.startMinute / 60,
                  point.endMinute / 60,
                  dotPainter: FlDotCirclePainter(
                    radius: 4,
                    color: context.appPrimary.withValues(alpha: 0.85),
                    strokeWidth: 0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.appPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (hint != null)
              Text(hint!,
                  style: TextStyle(color: context.appTextMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

/// Card shell with the same empty state look used by the other statistics
/// cards, kept local so this file does not depend on the derived-charts PR.
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.title,
    required this.child,
    required this.isEmpty,
    required this.emptyMessage,
  });

  final String title;
  final Widget child;
  final bool isEmpty;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.appTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.schedule_outlined, size: 40, color: context.appTextMuted),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.appTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            child,
        ],
      ),
    );
  }
}