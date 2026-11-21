import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/theme_palette.dart';
import '../../settings/settings_notifier.dart';

/// Colours offered for the timer dial.
const List<int> kDialColors = [
  0xFFFF6B1A, 0xFFFF3B30, 0xFFFF2D78, 0xFFAF52DE, 0xFF5E5CE6, 0xFF2F7CF6,
  0xFF32ADE6, 0xFF30D158, 0xFF34C759, 0xFFFFD60A, 0xFFFF9F0A, 0xFFE5E5EA,
];

/// Study colour, break colour and whether the dial shows outside Pomodoro.
/// Opened from Settings and by right-clicking (or long-pressing) the dial.
class DialStyleDialog extends ConsumerWidget {
  const DialStyleDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog(context: context, builder: (_) => const DialStyleDialog());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);

    Widget swatches(String label, int selected, ValueChanged<int> onPick, String keyPrefix) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kDialColors)
                  InkResponse(
                    key: ValueKey('$keyPrefix-$c'),
                    radius: 18,
                    onTap: () => onPick(c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == selected ? palette.textPrimary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: c == selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
          ],
        );

    return Dialog(
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.tr('classic_dial_title', fallback: 'Timer dial'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              const SizedBox(height: 18),
              swatches(t.tr('classic_dial_study', fallback: 'Study colour'), s.dialStudyColor,
                  (c) => n.setDialStyle(study: c), 'dial-study'),
              const SizedBox(height: 18),
              swatches(t.tr('classic_dial_break', fallback: 'Break colour'), s.dialBreakColor,
                  (c) => n.setDialStyle(rest: c), 'dial-break'),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('dial-show'),
                contentPadding: EdgeInsets.zero,
                title: Text(t.tr('classic_dial_show', fallback: 'Show the dial outside Pomodoro'),
                    style: TextStyle(fontSize: 14, color: palette.textPrimary)),
                value: s.showStopwatchDial,
                onChanged: (v) => n.setDialStyle(show: v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.tr('ok', fallback: 'OK')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
