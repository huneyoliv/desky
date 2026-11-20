import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/window/overlay_window_channel.dart';
import '../../statistics/stats_data.dart' show formatHourMin;
import '../../timer/timer_notifier.dart';
import '../../timer/widgets/daily_goal_dialog.dart';
import '../../timer/widgets/dial_style_dialog.dart';
import '../settings_notifier.dart';

/// App-level settings, opened from the gear in the timer header:
/// look (Classic YPT), Discord Rich Presence and the OBS overlay mode.
class AppSettingsDialog extends ConsumerWidget {
  const AppSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AppSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    Widget toggle({
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: context.appPrimary,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: context.appTextSecondary, fontSize: 12)),
        value: value,
        onChanged: onChanged,
      );
    }

    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_outlined, color: context.appPrimary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.tr('settings', fallback: 'Settings'),
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
              toggle(
                title: t.tr('classic_ypt_look_title', fallback: 'Classic YPT look'),
                subtitle: t.tr('classic_ypt_look_desc',
                    fallback: 'Tabs along the top and the YPT-style Timer, Calendar and Statistics screens'),
                value: settings.classicYptLook,
                onChanged: notifier.toggleClassicYptLook,
              ),
              Divider(color: context.appBorder, height: 16),
              ListTile(
                key: const ValueKey('settings-daily-goal'),
                contentPadding: EdgeInsets.zero,
                title: Text(t.tr('classic_daily_goal', fallback: 'Daily goal'),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatHourMin(ref.watch(timerNotifierProvider.select((s) => s.dailyGoalMinutes)) * 60000),
                      style: TextStyle(color: context.appTextSecondary, fontSize: 13)),
                  const Icon(Icons.chevron_right_rounded),
                ]),
                onTap: () => DailyGoalDialog.show(context),
              ),
              Divider(color: context.appBorder, height: 16),
              ListTile(
                key: const ValueKey('settings-dial-style'),
                contentPadding: EdgeInsets.zero,
                title: Text(t.tr('classic_dial_title', fallback: 'Timer dial'),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(t.tr('classic_dial_desc', fallback: 'Study and break colours, show or hide the dial'),
                    style: TextStyle(color: context.appTextSecondary, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 8, backgroundColor: Color(settings.dialStudyColor)),
                  const SizedBox(width: 4),
                  CircleAvatar(radius: 8, backgroundColor: Color(settings.dialBreakColor)),
                  const Icon(Icons.chevron_right_rounded),
                ]),
                onTap: () => DialStyleDialog.show(context),
              ),
              Divider(color: context.appBorder, height: 16),
              toggle(
                title: t.tr('classic_offline_mode', fallback: 'Offline mode'),
                subtitle: t.tr('classic_offline_desc',
                    fallback:
                        'Study without internet: sessions are saved on this device and sent when you turn it off'),
                value: settings.offlineMode,
                onChanged: notifier.toggleOfflineMode,
              ),
              Divider(color: context.appBorder, height: 16),
              toggle(
                title: t.tr('discord_rpc_title', fallback: 'Discord Rich Presence'),
                subtitle:
                    t.tr('discord_rpc_desc', fallback: 'Display subject and study time in real-time on Discord status'),
                value: settings.discordRpcEnabled,
                onChanged: notifier.toggleDiscordRpc,
              ),
              if (OverlayWindowChannel.isSupported) ...[
                Divider(color: context.appBorder, height: 16),
                toggle(
                  title: t.tr('obs_overlay_title', fallback: 'OBS overlay mode'),
                  subtitle: t.tr('obs_overlay_desc',
                      fallback:
                          'Minimizing sends the window behind the others instead, so an OBS Window Capture keeps showing it'),
                  value: settings.obsOverlayMode,
                  onChanged: notifier.toggleObsOverlayMode,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
