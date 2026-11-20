import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/window/overlay_window_channel.dart';
import '../settings_notifier.dart';

/// App-level settings, opened from the gear in the timer header:
/// Discord Rich Presence and the OBS overlay mode.
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
              title: t.tr('discord_rpc_title', fallback: 'Discord Rich Presence'),
              subtitle: t.tr('discord_rpc_desc',
                  fallback: 'Display subject and study time in real-time on Discord status'),
              value: settings.discordRpcEnabled,
              onChanged: notifier.toggleDiscordRpc,
            ),
            if (OverlayWindowChannel.isSupported) ...[
              Divider(color: context.appBorder, height: 16),
              toggle(
                title: t.tr('obs_overlay_title', fallback: 'OBS overlay mode'),
                subtitle: t.tr('obs_overlay_desc',
                    fallback: 'Minimizing sends the window behind the others instead, so an OBS Window Capture keeps showing it'),
                value: settings.obsOverlayMode,
                onChanged: notifier.toggleObsOverlayMode,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
