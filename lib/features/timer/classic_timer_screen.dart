import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/cdn/cdn_resolver.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import '../../data/models/group_member_model.dart';
import '../../data/models/subject_model.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../auth/auth_notifier.dart';
import '../groups/group_detail_screen.dart' show groupRepositoryProvider;
import '../settings/settings_notifier.dart';
import '../statistics/stats_data.dart';
import '../statistics/widgets/stat_charts.dart' show kStatOrange;
import 'focus_mode_notifier.dart';
import 'timer_notifier.dart';
import 'timer_screen.dart';
import 'widgets/pomodoro_config_dialog.dart';
import 'widgets/subject_management_dialog.dart';

const Color _breakBlue = Color(0xFF2F7CF6);

/// `/home`: the Classic YPT timer when that look is on, the regular one
/// otherwise.
class HomeTimerScreen extends ConsumerWidget {
  const HomeTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classic = ref.watch(settingsNotifierProvider.select((s) => s.classicYptLook));
    return classic ? const ClassicTimerScreen() : const TimerScreen();
  }
}

/// Timer home in the YPT desktop layout.
///
/// Idle: date, today's total (or the Pomodoro dial) and the subject list with
/// a play button and today's time per subject. Studying: "Current focus time"
/// with the studicon, and the live member grid of the user's groups.
/// On break: the blue break dial.
class ClassicTimerScreen extends ConsumerWidget {
  const ClassicTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timerNotifierProvider);
    final palette = context.palette;
    if (state.isRunning) {
      return Scaffold(backgroundColor: palette.background, body: const _StudyingView());
    }
    return Scaffold(backgroundColor: palette.background, body: const _IdleView());
  }
}

String _clock(int ms) => formatHms(math.max(0, ms));

String _mmss(int ms) {
  final s = math.max(0, ms) ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final palette = context.palette;
    final isPomodoro = state.mode == TimerMode.pomodoro;
    final onBreak = state.isPaused;
    final subjects = state.subjects.where((s) => !s.isArchived && !s.isDeleted).toList();

    Widget hero;
    if (onBreak) {
      hero = _Dial(
        color: _breakBlue,
        progress: null,
        label: t.tr('classic_break', fallback: 'Break'),
        value: _mmss(state.sessionRestMs),
        action: TextButton(
          onPressed: notifier.stopStudy,
          child: Text(t.tr('classic_finish', fallback: 'Finish'),
              style: TextStyle(fontSize: 11, color: palette.textSecondary)),
        ),
        onTap: notifier.startStudy,
      );
    } else if (isPomodoro) {
      hero = _Dial(
        color: kStatOrange,
        progress: null,
        label: t.tr('classic_focus_time', fallback: 'Focus time'),
        value: _mmss(state.pomodoroRemainingMs),
        caption: '${t.tr('classic_now', fallback: 'Now')} ${DateFormat('h:mm a').format(DateTime.now())}',
        onTap: () => PomodoroConfigDialog.show(context, state: state, onSave: notifier.configurePomodoro),
      );
    } else {
      hero = Column(
        children: [
          Text(
            _clock(state.todayTotalMs),
            key: const ValueKey('classic-today-total'),
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(t.tr('classic_total_today', fallback: 'Total time today'),
              style: TextStyle(fontSize: 11, color: palette.textMuted)),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
          child: Row(
            children: [
              _ModeSwitch(isPomodoro: isPomodoro, enabled: !onBreak),
              Expanded(
                child: Center(
                  child: Text(DateFormat('EEE, M/d').format(DateTime.now()),
                      style: TextStyle(fontSize: 13, color: palette.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                tooltip: t.tr('focus', fallback: 'Focus mode'),
                icon: Icon(Icons.fullscreen_rounded, size: 18, color: palette.textSecondary),
                onPressed: () => ref.read(focusModeProvider.notifier).toggleStrictFocus(),
              ),
              IconButton(
                tooltip: t.tr('mini_player', fallback: 'Mini player'),
                icon: Icon(Icons.picture_in_picture_alt_rounded, size: 18, color: palette.textSecondary),
                onPressed: () => ref.read(focusModeProvider.notifier).toggleMiniPlayer(),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: hero),
        if (isPomodoro || onBreak)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(t.tr('classic_total_today', fallback: 'Total time today'),
                    style: TextStyle(fontSize: 11, color: palette.textMuted)),
                const Spacer(),
                Text(_clock(state.todayTotalMs), style: TextStyle(fontSize: 11, color: palette.textMuted)),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            children: [
              for (final s in subjects)
                _SubjectRow(
                  subject: s,
                  selected: s.id == state.currentSubject?.id,
                  onPlay: () async {
                    notifier.selectSubject(s);
                    await notifier.startStudy();
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('classic-edit-subject'),
                  icon: Icon(Icons.edit_outlined, size: 14, color: palette.textSecondary),
                  label: Text(t.tr('classic_edit_subject', fallback: 'Edit subject'),
                      style: TextStyle(fontSize: 12, color: palette.textSecondary)),
                  onPressed: () => SubjectManagementDialog.show(
                    context,
                    subjects: state.subjects,
                    selectedSubject: state.currentSubject,
                    onSelectSubject: notifier.selectSubject,
                    onCreateSubject: notifier.createSubject,
                    onUpdateSubject: notifier.updateSubject,
                    onArchiveSubject: notifier.archiveSubject,
                    onDeleteSubject: notifier.deleteSubject,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends ConsumerWidget {
  const _ModeSwitch({required this.isPomodoro, required this.enabled});
  final bool isPomodoro;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.tr('timer_options_pomodoro', fallback: 'Pomodoro'),
            style: TextStyle(fontSize: 11, color: context.palette.textSecondary)),
        Transform.scale(
          scale: 0.7,
          child: Switch(
            key: const ValueKey('classic-pomodoro-switch'),
            value: isPomodoro,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
            onChanged: enabled
                ? (v) => ref
                    .read(timerNotifierProvider.notifier)
                    .setTimerMode(v ? TimerMode.pomodoro : TimerMode.stopwatch)
                : null,
          ),
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject, required this.selected, required this.onPlay});
  final SubjectModel subject;
  final bool selected;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = Color(subject.colorInt);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subject.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              _clock(subject.studyMs),
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big round dial: a filled circle, or a pie of the remaining Pomodoro time.
class _Dial extends StatelessWidget {
  const _Dial({
    required this.color,
    required this.progress,
    required this.label,
    required this.value,
    this.caption,
    this.action,
    this.onTap,
  });

  final Color color;

  /// Remaining fraction (1 → full); null draws a plain filled circle.
  final double? progress;
  final String label;
  final String value;
  final String? caption;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _DialPainter(color, progress),
              child: Center(
                child: progress == null
                    ? const Icon(Icons.water_drop_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
        Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: palette.textSecondary)),
            Text(value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            if (caption != null)
              Text(caption!, style: TextStyle(fontSize: 9, color: palette.textMuted)),
            if (action != null) action!,
          ],
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.color, this.progress);
  final Color color;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (progress == null) {
      canvas.drawCircle(c, r, Paint()..color = color);
      return;
    }
    canvas.drawCircle(c, r, Paint()..color = Colors.black);
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white24);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 3), -math.pi / 2, 2 * math.pi * progress!,
        true, Paint()..color = color);
    canvas.drawCircle(c, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.progress != progress || old.color != color;
}

class _StudyingView extends ConsumerWidget {
  const _StudyingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final user = ref.watch(authStateProvider.select((s) => s.user));
    final palette = context.palette;
    final isPomodoro = state.mode == TimerMode.pomodoro;
    final subject = state.currentSubject;
    final focusTotal = state.pomodoroFocusMinutes * 60000;

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Icons.pause_rounded, tooltip: t.tr('pause', fallback: 'Pause'), onTap: notifier.pauseStudy),
        const SizedBox(width: 6),
        _RoundButton(icon: Icons.stop_rounded, tooltip: t.tr('stop', fallback: 'Stop'), onTap: notifier.stopStudy),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
          child: Row(
            children: [
              if (subject != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: Color(subject.colorInt), shape: BoxShape.circle),
                ),
              Text(
                '${subject?.title ?? ''}  ${_clock(subject?.studyMs ?? 0)}',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
              const Spacer(),
              IconButton(
                tooltip: t.tr('focus', fallback: 'Focus mode'),
                icon: Icon(Icons.fullscreen_rounded, size: 18, color: palette.textSecondary),
                onPressed: () => ref.read(focusModeProvider.notifier).toggleStrictFocus(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              if (isPomodoro) ...[
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _DialPainter(
                      kStatOrange,
                      focusTotal <= 0 ? 0 : (state.pomodoroRemainingMs / focusTotal).clamp(0.0, 1.0),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: isPomodoro ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPomodoro
                          ? t.tr('classic_remaining_time', fallback: 'Remaining time')
                          : t.tr('classic_current_focus_time', fallback: 'Current focus time'),
                      style: TextStyle(fontSize: 11, color: palette.textSecondary),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPomodoro ? _mmss(state.pomodoroRemainingMs) : _clock(state.sessionElapsedMs),
                          key: const ValueKey('classic-focus-time'),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 8),
                        controls,
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  StudiconAvatar(
                    studiconId: user?.studiconId ?? state.studiconId,
                    pose: CdnResolver.resolvePose(isStudying: true, studyMs: state.todayTotalMs),
                    size: 44,
                  ),
                  Text(_clock(state.todayTotalMs),
                      style: const TextStyle(fontSize: 10, color: kStatOrange)),
                ],
              ),
            ],
          ),
        ),
        const Expanded(child: _GroupPanel()),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: context.palette.textPrimary, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: context.palette.background),
          ),
        ),
      );
}

/// Members of one of the user's groups, refreshed every minute. Arrows (or
/// the group name) switch between groups.
class _GroupPanel extends ConsumerStatefulWidget {
  const _GroupPanel();

  @override
  ConsumerState<_GroupPanel> createState() => _GroupPanelState();
}

class _GroupPanelState extends ConsumerState<_GroupPanel> {
  int _index = 0;
  List<GroupMemberModel>? _members;
  int? _loadedGroup;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _load(force: true));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final groups = ref.read(authStateProvider).user?.userGroups ?? const [];
    if (groups.isEmpty) return;
    final group = groups[_index % groups.length];
    if (!force && _loadedGroup == group.id) return;
    _loadedGroup = group.id;
    try {
      final members = await ref.read(groupRepositoryProvider).fetchMembers(group.id);
      if (!mounted || _loadedGroup != group.id) return;
      members.sort((a, b) {
        if (a.isStudying != b.isStudying) return a.isStudying ? -1 : 1;
        return b.studyMs.compareTo(a.studyMs);
      });
      setState(() => _members = members);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final groups = ref.watch(authStateProvider.select((s) => s.user?.userGroups)) ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();
    final group = groups[_index % groups.length];
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    final members = _loadedGroup == group.id ? _members : null;
    final studying = members?.where((m) => m.isStudying).length ?? 0;

    void move(int delta) => setState(() {
          _index = (_index + delta) % groups.length;
          if (_index < 0) _index += groups.length;
          _members = null;
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              if (groups.length > 1)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.chevron_left, size: 18, color: palette.textMuted),
                  onPressed: () => move(-1),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    Text(
                      '$studying ${t.tr('classic_members_studying', fallback: 'members studying')}',
                      style: const TextStyle(fontSize: 10, color: kStatOrange),
                    ),
                  ],
                ),
              ),
              if (groups.length > 1)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.chevron_right, size: 18, color: palette.textMuted),
                  onPressed: () => move(1),
                ),
            ],
          ),
        ),
        Expanded(
          child: members == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kStatOrange))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisExtent: 96,
                  ),
                  itemCount: members.length,
                  itemBuilder: (context, i) => _MemberTile(member: members[i]),
                ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final GroupMemberModel member;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = member.isStudying && !member.isPaused;
    return Column(
      children: [
        Opacity(
          opacity: active ? 1 : 0.45,
          child: active
              ? StudiconAvatar(
                  studiconId: member.studiconId,
                  pose: CdnResolver.resolvePose(isStudying: true, studyMs: member.studyMs),
                  size: 48,
                )
              : Icon(Icons.chair_alt_outlined, size: 40, color: palette.textMuted),
        ),
        const SizedBox(height: 2),
        Text(member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: active ? kStatOrange : palette.textMuted)),
        Text(_clock(member.studyMs),
            style: TextStyle(fontSize: 9, color: active ? kStatOrange : palette.textMuted)),
      ],
    );
  }
}
