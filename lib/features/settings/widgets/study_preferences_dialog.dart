import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';
import '../settings_notifier.dart';

class StudyPreferencesDialog extends ConsumerWidget {
  const StudyPreferencesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const StudyPreferencesDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('study_preferences', fallback: 'Preferências de Estudo & Rotina'),
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 24),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Day Start Reset Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_filled, color: AppColors.warning, size: 22),
                      title: Text(
                        t.tr('day_start_hour', fallback: 'Início do Dia de Estudo (Reset)'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('day_start_hour_desc', fallback: 'Horário de virada do dia nos gráficos e diário'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      trailing: DropdownButton<int>(
                        value: settings.dayResetHour,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        underline: const SizedBox(),
                        items: List.generate(7, (i) => i).map((h) {
                          final label = '${h.toString().padLeft(2, '0')}:00 AM';
                          return DropdownMenuItem<int>(
                            value: h,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            notifier.setDayResetHour(val);
                          }
                        },
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 16),

                    // Show Rest Time Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: Text(
                        t.tr('drawer_settings_menu_show_rest', fallback: 'Exibir Tempo de Descanso'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('show_rest_desc', fallback: 'Exibir pausas e intervalos no registro diário'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      value: settings.showRestTime,
                      onChanged: (val) => notifier.toggleShowRestTime(val),
                    ),
                    const Divider(color: AppColors.border, height: 16),

                    // Nudge / Wake Notifications Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: Text(
                        t.tr('drawer_settings_menu_wake_notification', fallback: 'Notificações de Cutucada (Nudge)'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('wake_notif_desc', fallback: 'Receber alertas quando membros do grupo te cutucarem'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      value: settings.wakeNotifications,
                      onChanged: (val) => notifier.toggleWakeNotifications(val),
                    ),
                    const Divider(color: AppColors.border, height: 16),

                    // Sound Effects Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: Text(
                        t.tr('sound_effects', fallback: 'Efeitos Sonoros do Cronômetro'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('sound_effects_desc', fallback: 'Sons de início, pausa e conclusão de ciclos Pomodoro'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      value: settings.soundEffects,
                      onChanged: (val) => notifier.toggleSoundEffects(val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(t.tr('close_btn', fallback: 'Concluir'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
