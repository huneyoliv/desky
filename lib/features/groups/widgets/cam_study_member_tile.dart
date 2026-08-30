import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/cdn/cdn_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';
import '../../../data/models/group_member_model.dart';
import '../../../shared/widgets/studicon_avatar.dart';

class CamStudyMemberTile extends ConsumerWidget {
  final GroupMemberModel member;
  final VoidCallback? onShake;

  const CamStudyMemberTile({
    super.key,
    required this.member,
    this.onShake,
  });

  String _formatStudyTime(int ms) {
    final mins = ms ~/ 60000;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final camUrl = CdnResolver.camStudyUrl(dateStr, member.userId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: member.isStudying
              ? AppColors.primary
              : AppColors.border,
          width: member.isStudying ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Camera Image or Fallback Studicon Avatar
          Positioned.fill(
            child: Image.network(
              camUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: Center(
                  child: StudiconAvatar(
                    studiconId: member.studiconId,
                    pose: member.isStudying
                        ? (member.studyMs > 7200000
                            ? StudiconPose.ignite1
                            : StudiconPose.sweat1)
                        : StudiconPose.normal1,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),

          // Top Badge: Cam Live Indicator
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: member.isStudying
                    ? AppColors.primary
                    : Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: member.isStudying
                          ? Colors.white
                          : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    member.isStudying ? t.tr('live_study', fallback: 'LIVE STUDY') : t.tr('paused', fallback: 'PAUSA'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Info Gradient Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _formatStudyTime(member.studyMs),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onShake != null && !member.isStudying)
                    IconButton(
                      icon: const Icon(Icons.notifications_active,
                          color: AppColors.primary, size: 18),
                      onPressed: onShake,
                      tooltip: t.tr('shake', fallback: 'Chacoalhar'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
