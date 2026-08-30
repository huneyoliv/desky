import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/utils/study_date_helper.dart';
import '../../settings/settings_notifier.dart';

class StudyCalendar extends ConsumerWidget {
  final Map<String, int> dailyStudyTimeMs; // Key: 'yyyy-MM-dd', Value: ms

  const StudyCalendar({
    super.key,
    required this.dailyStudyTimeMs,
  });

  Color _getDayColor(int ms) {
    if (ms <= 0) return AppColors.card;
    final hours = ms / 3600000;
    if (hours < 2) return const Color(0xFF0E4429);
    if (hours < 4) return const Color(0xFF006D32);
    if (hours < 7) return const Color(0xFF26A641);
    return const Color(0xFF39D353);
  }

  String _formatMs(int ms) {
    final mins = ms ~/ 60000;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayResetHour = ref.watch(settingsNotifierProvider.select((s) => s.dayResetHour));
    final now = StudyDateHelper.getStudyDate(null, dayResetHour);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDayWeekday = DateTime(now.year, now.month, 1).weekday; // 1=Mon...7=Sun
    final t = ref.watch(appTranslationProvider);

    final dayLabels = [
      t.tr('mon', fallback: 'Seg'),
      t.tr('tue', fallback: 'Ter'),
      t.tr('wed', fallback: 'Qua'),
      t.tr('thu', fallback: 'Qui'),
      t.tr('fri', fallback: 'Sex'),
      t.tr('sat', fallback: 'Sáb'),
      t.tr('sun', fallback: 'Dom'),
    ];

    final monthHeader = () {
      try {
        final locale = t.languageCode == 'zh-cn'
            ? 'zh_CN'
            : (t.languageCode == 'zh-tw' ? 'zh_TW' : t.languageCode);
        return DateFormat('MMMM yyyy', locale).format(now);
      } catch (_) {
        return '${now.month}/${now.year}';
      }
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${t.tr("presence_calendar", fallback: "Calendário de Presença")} — $monthHeader',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Weekday Header
        Row(
          children: dayLabels.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: (firstDayWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstDayWeekday - 1) {
              return const SizedBox.shrink();
            }

            final dayNum = index - (firstDayWeekday - 1) + 1;
            final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
            final studyMs = dailyStudyTimeMs[dateStr] ?? 0;
            final color = _getDayColor(studyMs);

            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: Text('${t.tr("studies_on", fallback: "Estudos em")} $dateStr', style: const TextStyle(color: Colors.white)),
                    content: Text(
                      studyMs > 0
                          ? '${t.tr("total_time_studied", fallback: "Tempo total estudado")}: ${_formatMs(studyMs)}'
                          : t.tr('no_study_on_day', fallback: 'Nenhum estudo registrado neste dia.'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t.tr('ok', fallback: 'OK'), style: const TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dayNum == now.day ? AppColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: dayNum == now.day ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    if (studyMs > 0)
                      Text(
                        _formatMs(studyMs),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
