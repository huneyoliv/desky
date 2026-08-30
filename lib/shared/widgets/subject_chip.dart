import 'package:flutter/material.dart';
import '../../data/models/subject_model.dart';
import '../../core/theme/app_colors.dart';

class SubjectChip extends StatelessWidget {
  final SubjectModel subject;
  final bool isSelected;
  final VoidCallback onTap;

  const SubjectChip({
    super.key,
    required this.subject,
    required this.isSelected,
    required this.onTap,
  });

  String _formatMs(int ms) {
    final totalSecs = ms ~/ 1000;
    final mins = totalSecs ~/ 60;
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    final remainingSecs = totalSecs % 60;
    if (hours > 0) {
      return '${hours}h ${remainingMins}m';
    }
    if (remainingMins > 0) {
      return '${remainingMins}m';
    }
    if (remainingSecs > 0) {
      return '${remainingSecs}s';
    }
    return '0m';
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = subject.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withValues(alpha: 0.25) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: chipColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subject.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatMs(subject.studyMs),
                style: TextStyle(
                  color: isSelected ? AppColors.textSecondary : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
