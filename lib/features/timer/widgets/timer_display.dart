import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class TimerDisplay extends StatelessWidget {
  final int elapsedMs;
  final double fontSize;

  const TimerDisplay({
    super.key,
    required this.elapsedMs,
    this.fontSize = 56,
  });

  String _formatDuration(int ms) {
    final secondsTotal = ms ~/ 1000;
    final hours = secondsTotal ~/ 3600;
    final minutes = (secondsTotal % 3600) ~/ 60;
    final seconds = secondsTotal % 60;

    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');

    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatDuration(elapsedMs);

    return Text(
      timeStr,
      style: TextStyle(
        fontFamily: AppTextStyles.fontTimer,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 3.0,
      ),
    );
  }
}
