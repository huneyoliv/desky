import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/timer_appearance.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/utils/package_helper.dart';
import '../settings_notifier.dart';

Future<void> _pickTimerBackgroundImage(
  BuildContext context,
  WidgetRef ref,
) async {
  final t = ref.read(appTranslationProvider);
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    final valid = await isValidTimerBackgroundImageFile(path);
    if (!valid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.tr('timer_background_file_error',
                fallback: 'Não foi possível usar essa imagem.')),
          ),
        );
      }
      return;
    }
    await ref
        .read(settingsNotifierProvider.notifier)
        .setTimerBackgroundImage(path);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('timer_background_file_error',
              fallback: 'Não foi possível usar essa imagem.')),
        ),
      );
    }
  }
}

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
                    style: AppTextStyles.titleMedium.copyWith(color: context.appTextPrimary, fontWeight: FontWeight.bold),
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
                    // Day Start Reset Time
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_filled, color: AppColors.warning, size: 22),
                      title: Text(
                        t.tr('day_start_hour', fallback: 'Início do Dia de Estudo (Reset)'),
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('day_start_hour_desc', fallback: 'Horário de virada do dia nos gráficos e diário'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      trailing: DropdownButton<int>(
                        value: settings.dayResetHour,
                        dropdownColor: context.appSurface,
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14),
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
                        t.tr('drawer_settings_menu_show_rest', fallback: 'Show break time'),
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('show_rest_desc', fallback: 'Exibir pausas e intervalos no registro diário'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.showRestTime,
                      onChanged: (val) => notifier.toggleShowRestTime(val),
                    ),
                    Divider(color: context.appBorder, height: 16),

                    // Optional Classic zoom (no alternate navigation or offline mode).
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: context.appPrimary,
                      title: Text(
                        t.tr('classic_zoom', fallback: 'Zoom clássico'),
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('classic_zoom_desc', fallback: 'Atalhos Ctrl +/-/0 e Ctrl + roda do mouse'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.classicYptLook,
                      onChanged: (val) => notifier.toggleClassicYptLook(val),
                    ),
                    Divider(color: context.appBorder, height: 16),

                    // Nudge / Wake Notifications Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: context.appPrimary,
                      title: Text(
                        t.tr('drawer_settings_menu_wake_notification', fallback: 'Nudge notifications'),
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
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
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
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
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('discord_rpc_desc', fallback: 'Exibir matéria e tempo de estudo em tempo real no status do Discord'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      value: settings.discordRpcEnabled,
                      onChanged: (val) => notifier.toggleDiscordRpc(val),
                    ),

                    Divider(color: context.appBorder, height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.wallpaper_rounded, color: context.appPrimary),
                      title: Text(
                        t.tr('timer_background', fallback: 'Fundo do Timer'),
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.tr('timer_background_image_desc',
                            fallback: 'PNG/JPEG/WebP até 20 MB; vídeo não incluído'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                      ),
                      trailing: DropdownButton<String>(
                        value: settings.timerBackground,
                        dropdownColor: context.appSurface,
                        style: TextStyle(color: context.appTextPrimary, fontSize: 13),
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: timerBackgroundTheme,
                            child: Text(t.tr('timer_background_theme', fallback: 'Tema padrão')),
                          ),
                          const DropdownMenuItem(
                            value: timerBackgroundAurora,
                            child: Text('Aurora'),
                          ),
                          const DropdownMenuItem(
                            value: timerBackgroundSunset,
                            child: Text('Sunset'),
                          ),
                          DropdownMenuItem(
                            value: timerBackgroundCustomImage,
                            child: Text(t.tr('timer_background_image', fallback: 'Imagem local')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          if (value == timerBackgroundCustomImage) {
                            _pickTimerBackgroundImage(context, ref);
                          } else {
                            notifier.setTimerBackground(value);
                          }
                        },
                      ),
                    ),
                    if (settings.timerBackground == timerBackgroundCustomImage)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _pickTimerBackgroundImage(context, ref),
                          icon: Icon(Icons.folder_open_rounded, size: 18),
                          label: Text(t.tr('timer_choose_image', fallback: 'Escolher imagem')),
                        ),
                      ),
                    Divider(color: context.appBorder, height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.font_download_rounded, color: context.appPrimary),
                      title: Text(
                        t.tr('timer_font', fallback: 'Fonte do Timer'),
                        style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: DropdownButton<String>(
                        value: settings.timerFont,
                        dropdownColor: context.appSurface,
                        style: TextStyle(color: context.appTextPrimary, fontSize: 13),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: timerFontDigital, child: Text('Digital')),
                          DropdownMenuItem(value: timerFontSfPro, child: Text('SF Pro')),
                          DropdownMenuItem(value: timerFontPretendard, child: Text('Pretendard')),
                        ],
                        onChanged: (value) {
                          if (value != null) notifier.setTimerFont(value);
                        },
                      ),
                    ),

                    // Beta updates. Hidden in the Store/MSIX build: the packaged
                    // app is updated by the Store, and offering a downloaded
                    // installer there would bypass managed updates.
                    if (!PackageHelper.isStoreOrMsix) ...[
                      Divider(color: context.appBorder, height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: context.appPrimary,
                        title: Text(
                          t.tr('beta_updates_title', fallback: 'Participar do beta'),
                          style: TextStyle(color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          t.tr('beta_updates_desc',
                              fallback: 'Receber também versões de teste (pré-lançamento) antes do lançamento estável'),
                          style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                        ),
                        value: settings.betaChannel,
                        onChanged: (val) => notifier.toggleBetaChannel(val),
                      ),
                    ],
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
                child: Text(t.tr('close_btn', fallback: 'Done'), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
