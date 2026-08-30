import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FlamesBadge extends StatelessWidget {
  final int count;

  const FlamesBadge({super.key, this.count = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.flame.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.flame.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/icon_flame.png',
            width: 16,
            height: 16,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_fire_department,
              color: AppColors.flame,
              size: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.flame,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
