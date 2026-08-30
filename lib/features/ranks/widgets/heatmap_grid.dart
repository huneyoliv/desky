import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';

class HeatmapGrid extends ConsumerWidget {
  final Map<String, List<int>> hourlyLogs; // Key: 'yyyy-MM-dd', Value: 24 ints (minutes per hour)

  const HeatmapGrid({
    super.key,
    required this.hourlyLogs,
  });

  Color _getColor(int minutes) {
    if (minutes <= 0) return AppColors.surface;
    if (minutes < 15) return AppColors.heatmapL1;
    if (minutes < 30) return AppColors.heatmapL2;
    if (minutes < 45) return AppColors.heatmapL3;
    return AppColors.heatmapL4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = hourlyLogs.keys.toList()..sort();
    final t = ref.watch(appTranslationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Text(
              t.tr('heatmap_title', fallback: 'Mapa de Calor de Estudos (24h x 30d)'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${t.tr("less", fallback: "Menos")} ', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Container(width: 10, height: 10, color: AppColors.surface),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, color: AppColors.heatmapL1),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, color: AppColors.heatmapL2),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, color: AppColors.heatmapL3),
                const SizedBox(width: 4),
                Container(width: 10, height: 10, color: AppColors.heatmapL4),
                const SizedBox(width: 4),
                Text(' ${t.tr("more", fallback: "Mais")}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hours Label Column (00h - 23h)
              Column(
                children: List.generate(24, (h) {
                  return Container(
                    height: 14,
                    width: 32,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${h.toString().padLeft(2, '0')}h',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),

              // Heatmap Days Grid
              Row(
                children: dates.map((dateStr) {
                  final hours = hourlyLogs[dateStr] ?? List.filled(24, 0);

                  return Container(
                    margin: const EdgeInsets.only(right: 3),
                    child: Column(
                      children: List.generate(24, (h) {
                        final mins = hours[h];
                        return Tooltip(
                          message: '$dateStr ${t.tr("at", fallback: "às")} ${h.toString().padLeft(2, '0')}:00 — $mins min ${t.tr("studied", fallback: "estudados")}',
                          child: Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _getColor(mins),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
