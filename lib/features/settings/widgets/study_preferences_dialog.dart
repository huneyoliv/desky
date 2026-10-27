import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';
import '../settings_notifier.dart';
import 'theme_selection_dialog.dart';

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
      backgroundColor: context.appCard,
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
                Icon(Icons.tune_rounded, color: context.appPrimary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('study_preferences', fallback: 'Preferências de Estudo & Rotina'),
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.appTextMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(color: context.appBorder, height: 24),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Theme & Appearance
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.palette_outlined, color: context.appPrimary, size: 22),
                      title: Text(
                        t.tr('theme_appearance', fallback: 'Aparência & Tema'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('theme_appearance_desc', fallback: 'Personalize a paleta visual e cores do aplicativo'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: context.appTextMuted),
                      onTap: () => ThemeSelectionDialog.show(context),
                    ),
                    Divider(color: context.appBorder, height: 16),

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
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      trailing: DropdownButton<int>(
                        value: settings.dayResetHour,
                        dropdownColor: context.appSurface,
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
                    Divider(color: context.appBorder, height: 16),

                    // Show Rest Time Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: context.appPrimary,
                      title: Text(
                        t.tr('drawer_settings_menu_show_rest', fallback: 'Exibir Tempo de Descanso'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('show_rest_desc', fallback: 'Exibir pausas e intervalos no registro diário'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.showRestTime,
                      onChanged: (val) => notifier.toggleShowRestTime(val),
                    ),
                    Divider(color: context.appBorder, height: 16),

                    // Nudge / Wake Notifications Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: context.appPrimary,
                      title: Text(
                        t.tr('drawer_settings_menu_wake_notification', fallback: 'Notificações de Cutucada (Nudge)'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('wake_notif_desc', fallback: 'Receber alertas quando membros do grupo te cutucarem'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.wakeNotifications,
                      onChanged: (val) => notifier.toggleWakeNotifications(val),
                    ),
                    Divider(color: context.appBorder, height: 16),

                    // Sound Effects Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: context.appPrimary,
                      title: Text(
                        t.tr('sound_effects', fallback: 'Efeitos Sonoros do Cronômetro'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('sound_effects_desc', fallback: 'Sons de início, pausa e conclusão de ciclos Pomodoro'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.soundEffects,
                      onChanged: (val) => notifier.toggleSoundEffects(val),
                    ),
                    Divider(color: context.appBorder, height: 16),

                    // Discord Rich Presence Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: context.appPrimary,
                      title: Text(
                        t.tr('discord_rpc_title', fallback: 'Discord Rich Presence'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('discord_rpc_desc', fallback: 'Exibir matéria e tempo de estudo em tempo real no status do Discord'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.discordRpcEnabled,
                      onChanged: (val) => notifier.toggleDiscordRpc(val),
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
                  backgroundColor: context.appPrimary,
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
