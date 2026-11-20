import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/theme_palette.dart';
import '../timer_notifier.dart';

/// Sets the daily study goal: a slider in 15-minute steps plus quick presets.
class DailyGoalDialog extends ConsumerStatefulWidget {
  const DailyGoalDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog(context: context, builder: (_) => const DailyGoalDialog());

  @override
  ConsumerState<DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends ConsumerState<DailyGoalDialog> {
  late int _minutes = ref.read(timerNotifierProvider).dailyGoalMinutes.clamp(15, 16 * 60);

  String _fmt(int m) => m % 60 == 0 ? '${m ~/ 60}h' : '${m ~/ 60}h ${m % 60}m';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.tr('classic_daily_goal', fallback: 'Daily goal'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              const SizedBox(height: 14),
              Center(
                child: Text(_fmt(_minutes),
                    key: const ValueKey('goal-value'),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              ),
              Slider(
                key: const ValueKey('goal-slider'),
                value: _minutes.toDouble(),
                min: 15,
                max: 16 * 60,
                divisions: (16 * 60 - 15) ~/ 15,
                activeColor: const Color(0xFFFF6B1A),
                onChanged: (v) => setState(() => _minutes = (v / 15).round() * 15),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in const [2, 4, 6, 8, 10, 12])
                    ChoiceChip(
                      label: Text('${h}h'),
                      selected: _minutes == h * 60,
                      onSelected: (_) => setState(() => _minutes = h * 60),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.tr('cancel', fallback: 'Cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey('goal-save'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B1A)),
                    onPressed: () {
                      ref.read(timerNotifierProvider.notifier).setDailyGoalMinutes(_minutes);
                      Navigator.of(context).pop();
                    },
                    child: Text(t.tr('save', fallback: 'Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
