import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../stats_derivations.dart';

/// Shared shell so every derived card looks the same and always explains an
/// empty result instead of rendering a blank chart.
class StatsCard extends ConsumerWidget {
  const StatsCard({
    super.key,
    required this.title,
    required this.child,
    this.isEmpty = false,
    this.emptyMessage,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool isEmpty;
  final String? emptyMessage;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.insights_outlined, size: 40, color: context.appTextMuted),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage ??
                        t.tr('stats_no_history',
                            fallback: 'Sem histórico para calcular: registre algumas sessões de estudo.'),
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

String formatDurationShort(int ms, AppTranslation t) {
  if (ms <= 0) return '0min';
  final totalMinutes = (ms / 60000).round();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '${minutes}min';
  if (minutes == 0) return '${hours}h';
  return '${hours}h${minutes.toString().padLeft(2, '0')}';
}

String formatDelta(PeriodComparison comparison, AppTranslation t) {
  final growth = comparison.growth;
  if (growth == null) {
    return comparison.currentMs > 0
        ? t.tr('stats_new_period', fallback: 'sem base anterior')
        : '—';
  }
  final percent = (growth * 100).round();
  if (percent == 0) return t.tr('stats_same', fallback: 'igual');
  final sign = percent > 0 ? '+' : '';
  return '$sign$percent%';
}

/// Today/yesterday, this week/last week and this month/last month.
class StatsComparisonCard extends ConsumerWidget {
  const StatsComparisonCard({super.key, required this.comparisons});

  final List<PeriodComparison> comparisons;

  static const Map<String, String> _fallbacks = {
    'today': 'Hoje vs ontem',
    'week': 'Esta semana vs anterior',
    'month': 'Este mês vs anterior',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final hasAny = comparisons.any((c) => c.hasAnyData);

    return StatsCard(
      title: t.tr('stats_comparisons', fallback: 'Comparações'),
      isEmpty: !hasAny,
      emptyMessage: t.tr('stats_no_comparison',
          fallback: 'Sem dados nos períodos comparados.'),
      child: Column(
        children: [
          for (final comparison in comparisons) ...[
            _ComparisonRow(comparison: comparison, t: t),
            if (comparison != comparisons.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.comparison, required this.t});

  final PeriodComparison comparison;
  final AppTranslation t;

  @override
  Widget build(BuildContext context) {
    final growth = comparison.growth;
    final up = (growth ?? 0) > 0;
    final down = (growth ?? 0) < 0;
    final color = up
        ? AppColors.success
        : down
            ? AppColors.error
            : context.appTextMuted;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr(
                  'stats_compare_${comparison.key}',
                  fallback: StatsComparisonCard._fallbacks[comparison.key] ?? comparison.key,
                ),
                style: TextStyle(color: context.appTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatDurationShort(comparison.currentMs, t)} '
                '${t.tr('stats_vs', fallback: 'vs')} '
                '${formatDurationShort(comparison.previousMs, t)}',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (up) const Icon(Icons.arrow_upward, size: 14, color: AppColors.success),
            if (down) const Icon(Icons.arrow_downward, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              formatDelta(comparison, t),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

/// Best day, best week and best month.
class StatsMaximaCard extends ConsumerWidget {
  const StatsMaximaCard({super.key, required this.maxima});

  final StatsMaxima maxima;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);

    return StatsCard(
      title: t.tr('stats_maxima', fallback: 'Recordes'),
      isEmpty: !maxima.hasData,
      emptyMessage: t.tr('stats_no_maxima',
          fallback: 'Ainda não há um dia com estudo para calcular recordes.'),
      child: Column(
        children: [
          _MaximaRow(
            label: t.tr('stats_best_day', fallback: 'Melhor dia'),
            value: formatDurationShort(maxima.bestDayMs, t),
            detail: maxima.bestDayKey,
          ),
          const SizedBox(height: 12),
          _MaximaRow(
            label: t.tr('stats_best_week', fallback: 'Melhor semana'),
            value: formatDurationShort(maxima.bestWeekMs, t),
            detail: maxima.bestWeekKey,
          ),
          const SizedBox(height: 12),
          _MaximaRow(
            label: t.tr('stats_best_month', fallback: 'Melhor mês'),
            value: formatDurationShort(maxima.bestMonthMs, t),
            detail: maxima.bestMonthKey,
          ),
          const SizedBox(height: 16),
          Text(
            '${t.tr('stats_days_with_data', fallback: 'Dias com estudo no período')}'
            ': ${maxima.dayCount}',
            style: TextStyle(color: context.appTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MaximaRow extends StatelessWidget {
  const _MaximaRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: context.appTextSecondary, fontSize: 12)),
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
            if (detail != null)
              Text(detail!, style: TextStyle(color: context.appTextMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}