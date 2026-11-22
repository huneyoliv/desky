import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/cdn/cdn_resolver.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/group_member_model.dart';
import '../../../shared/widgets/studicon_avatar.dart';
import '../../auth/auth_notifier.dart';
import '../group_detail_screen.dart' show groupRepositoryProvider;
import 'member_live_timer.dart';

/// What a click on a group member opens: who they are, what they are doing,
/// today's and this week's time with their weekly rank, and a Nudge button.
class MemberSheet extends ConsumerStatefulWidget {
  const MemberSheet({super.key, required this.groupId, required this.member});

  final int groupId;
  final GroupMemberModel member;

  static Future<void> show(BuildContext context, {required int groupId, required GroupMemberModel member}) {
    return showDialog(
      context: context,
      builder: (_) => MemberSheet(groupId: groupId, member: member),
    );
  }

  @override
  ConsumerState<MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<MemberSheet> {
  late final Future<(int, int)?> _weekly = _loadWeekly();
  bool _sending = false;
  bool? _sent;

  /// (rank, weekly ms) of this member, or null when the ranking has no row.
  Future<(int, int)?> _loadWeekly() async {
    try {
      final ranks = await ref.read(groupRepositoryProvider).fetchWeeklyRanks(widget.groupId);
      final i = ranks.indexWhere((m) => m.userId == widget.member.userId);
      return i < 0 ? null : (i + 1, ranks[i].studyMs);
    } catch (_) {
      return null;
    }
  }

  Future<void> _nudge() async {
    setState(() => _sending = true);
    final ok = await ref
        .read(groupRepositoryProvider)
        .shakeMember(
          groupId: widget.groupId,
          targetUserId: widget.member.userId,
        );
    if (mounted) {
      setState(() {
        _sending = false;
        _sent = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final m = widget.member;
    final me = ref.watch(authStateProvider.select((s) => s.user?.id)) == m.userId;
    final active = m.isStudying && !m.isPaused;
    final status = active
        ? t.tr('studying', fallback: 'Studying')
        : m.isPaused
            ? t.tr('paused', fallback: 'Paused')
            : t.tr('resting', fallback: 'Resting');
    final statusColor = active ? const Color(0xFFFF6B1A) : (m.isPaused ? AppColors.warning : palette.textMuted);

    Widget stat(String label, Widget value) => Expanded(
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: palette.textMuted)),
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: value,
              ),
            ],
          ),
        );

    return Dialog(
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              m.hasCustomAvatar
                  ? CircleAvatar(radius: 48, backgroundImage: ResizeImage(NetworkImage(m.avatarUrl), width: 192, height: 192))
                  : StudiconAvatar(
                      studiconId: m.studiconId,
                      pose: CdnResolver.resolvePose(isStudying: m.isStudying, isPaused: m.isPaused, studyMs: m.studyMs),
                      size: 96,
                      isStudying: m.isStudying,
                    ),
              const SizedBox(height: 10),
              Text(m.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(status, style: TextStyle(fontSize: 13, color: statusColor)),
                  if (active && (m.currentSubject ?? '').isNotEmpty) ...[
                    Text('  ·  ', style: TextStyle(color: palette.textMuted)),
                    if (m.subjectColor != null)
                      Container(width: 3, height: 12, color: Color(m.subjectColor!)),
                    const SizedBox(width: 4),
                    Text(m.currentSubject!, style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  stat(t.tr('classic_today', fallback: 'Today'), Text(formatElapsed(Duration(milliseconds: m.studyMs)))),
                  stat(
                    t.tr('classic_current_session', fallback: 'Current session'),
                    active
                        ? MemberLiveTimer(
                            isStudying: m.isStudying,
                            isPaused: m.isPaused,
                            sessionStartedAt: m.sessionStartedAt,
                            activePrefix: '',
                            staticLabel: '—',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          )
                        : const Text('—'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FutureBuilder<(int, int)?>(
                future: _weekly,
                builder: (context, snap) {
                  final v = snap.data;
                  final loading = snap.connectionState != ConnectionState.done;
                  return Row(
                    children: [
                      stat(t.tr('classic_this_week', fallback: 'This week'),
                          Text(loading ? '…' : (v == null ? '—' : formatElapsed(Duration(milliseconds: v.$2))))),
                      stat(t.tr('classic_weekly_rank', fallback: 'Weekly rank'),
                          Text(loading ? '…' : (v == null ? '—' : '#${v.$1}'))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (!me)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('member-nudge'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B1A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _sending || _sent == true ? null : _nudge,
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: Text(
                      _sent == true
                          ? t.tr('classic_nudge_sent', fallback: 'Nudge sent')
                          : t.tr('shake', fallback: 'Nudge'),
                    ),
                  ),
                ),
              if (_sent == false)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      t.tr('shake_failed', fallback: 'Could not send the nudge.'),
                      style: const TextStyle(fontSize: 12, color: AppColors.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
