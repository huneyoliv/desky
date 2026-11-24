import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/cdn/cdn_resolver.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_palette.dart';
import '../../data/models/group_member_model.dart';
import '../../data/models/subject_model.dart';
import '../../shared/widgets/classic_layout.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../auth/auth_notifier.dart';
import '../groups/group_detail_screen.dart' show groupRepositoryProvider;
import '../groups/group_order.dart';
import '../groups/widgets/member_sheet.dart';
import '../settings/settings_notifier.dart';
import '../statistics/stats_data.dart';
import '../statistics/widgets/stat_charts.dart' show kStatOrange;
import '../todo/todo_notifier.dart';
import 'focus_mode_notifier.dart';
import 'timer_notifier.dart';
import 'timer_screen.dart';
import 'widgets/daily_goal_dialog.dart';
import 'widgets/dial_style_dialog.dart';
import 'widgets/pomodoro_config_dialog.dart';
import 'widgets/subject_management_dialog.dart';


/// Header and timer box have one fixed size in every state (idle, Pomodoro,
/// studying, break), so a single OBS crop fits all of them.
const double kClassicHeaderHeight = 56;
const Size kClassicTimerAreaSize = Size(600, 120);

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

String _clock(int ms) => formatHms(math.max(0, ms));

/// Timer home in the YPT tablet layout.
///
/// Wide windows: the timer pane (timer, then subjects or the live group) and
/// a "Today" pane with the goal and today's to-dos, like YPT's split screen.
/// Narrow or tall 9:16 windows: one centred column.
class ClassicTimerScreen extends ConsumerWidget {
  const ClassicTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusModeProvider);
    final palette = context.palette;
    if (focus.isStrictFocus || focus.isMiniPlayer) {
      return Scaffold(backgroundColor: palette.background, body: const _FocusingView());
    }
    return Scaffold(
      backgroundColor: palette.background,
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= kClassicWideBreakpoint;
        return ClassicPage(
          maxWidth: wide ? 1320 : 680,
          child: wide
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _TimerPane()),
                    SizedBox(width: 20),
                    SizedBox(width: 340, child: _TodayPane()),
                  ],
                )
              : const _TimerPane(),
        );
      }),
    );
  }
}

class _TimerPane extends ConsumerWidget {
  const _TimerPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(timerNotifierProvider.select((s) => s.isRunning));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const _TimerArea(),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            child: running
                ? const _GroupPanel(key: ValueKey('group'))
                : const _SubjectsCard(key: ValueKey('subjects')),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final palette = context.palette;
    final subject = state.currentSubject;
    final isPomodoro = state.mode == TimerMode.pomodoro;

    final Widget title = state.isRunning && subject != null
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: Color(subject.colorInt), shape: BoxShape.circle),
            ),
            Flexible(
              child: Text(subject.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.textPrimary)),
            ),
          ])
        : Text(DateFormat('EEE, MMM d').format(DateTime.now()),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary));

    return SizedBox(
      height: kClassicHeaderHeight,
      child: Row(
        children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: title)),
          Text(t.tr('timer_options_pomodoro', fallback: 'Pomodoro'),
              style: TextStyle(fontSize: 13, color: palette.textSecondary)),
          const SizedBox(width: 4),
          Switch(
            key: const ValueKey('classic-pomodoro-switch'),
            value: isPomodoro,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
            onChanged: state.isRunning || state.isPaused
                ? null
                : (v) => ref
                    .read(timerNotifierProvider.notifier)
                    .setTimerMode(v ? TimerMode.pomodoro : TimerMode.stopwatch),
          ),
          IconButton(
            tooltip: t.tr('focus', fallback: 'Focus mode'),
            icon: Icon(Icons.fullscreen_rounded, color: palette.textSecondary),
            onPressed: () => ref.read(focusModeProvider.notifier).toggleStrictFocus(),
          ),
          IconButton(
            tooltip: t.tr('mini_player', fallback: 'Mini player'),
            icon: Icon(Icons.picture_in_picture_alt_rounded, color: palette.textSecondary),
            onPressed: () => ref.read(focusModeProvider.notifier).toggleMiniPlayer(),
          ),
        ],
      ),
    );
  }
}

/// The timer, built for a stream crop: [dial] [label + time] … [buttons]
/// [studicon + today]. One fixed box in every state; buttons sit at the right
/// end so the time never shifts, and nothing else (no captions) changes.
class _TimerArea extends ConsumerWidget {
  const _TimerArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final user = ref.watch(authStateProvider.select((s) => s.user));
    final settings = ref.watch(settingsNotifierProvider);
    final palette = context.palette;
    final isPomodoro = state.mode == TimerMode.pomodoro;
    final focusTotal = math.max(1, state.pomodoroFocusMinutes * 60000);
    final goal = math.max(1, state.dailyGoalMinutes * 60000);
    final studyColor = Color(settings.dialStudyColor);
    final breakColor = Color(settings.dialBreakColor);
    final showDial = isPomodoro || state.isPaused || settings.showStopwatchDial;

    Future<void> start() async {
      final subjects = state.subjects.where((s) => !s.isArchived && !s.isDeleted);
      final subject = state.currentSubject ?? (subjects.isEmpty ? null : subjects.first);
      if (subject == null) return;
      notifier.selectSubject(subject);
      await notifier.startStudy();
    }

    final double fraction;
    final Color color;
    final String label;
    final String value;
    final List<Widget> actions;
    VoidCallback? onDialTap;

    if (state.isPaused) {
      color = breakColor;
      fraction = (state.sessionRestMs / math.max(1, state.pomodoroShortBreakMinutes * 60000)).clamp(0.0, 1.0);
      label = t.tr('classic_break', fallback: 'Break');
      value = _clock(state.sessionRestMs);
      actions = [
        _RoundButton(icon: Icons.play_arrow_rounded, tooltip: t.tr('restart', fallback: 'Resume'), onTap: notifier.startStudy),
        _RoundButton(icon: Icons.stop_rounded, tooltip: t.tr('classic_finish', fallback: 'Finish'), onTap: notifier.stopStudy, filled: false),
      ];
    } else if (state.isRunning) {
      color = studyColor;
      fraction = isPomodoro
          ? (state.pomodoroRemainingMs / focusTotal).clamp(0.0, 1.0)
          : (state.sessionElapsedMs % 3600000) / 3600000;
      label = isPomodoro
          ? t.tr('classic_remaining_time', fallback: 'Remaining time')
          : t.tr('classic_current_focus_time', fallback: 'Current focus time');
      value = isPomodoro ? _clock(state.pomodoroRemainingMs) : _clock(state.sessionElapsedMs);
      actions = [
        _RoundButton(icon: Icons.pause_rounded, tooltip: t.tr('pause', fallback: 'Pause'), onTap: notifier.pauseStudy),
        _RoundButton(icon: Icons.stop_rounded, tooltip: t.tr('stop', fallback: 'Stop'), onTap: notifier.stopStudy, filled: false),
      ];
    } else if (isPomodoro) {
      color = studyColor;
      fraction = 1;
      label = t.tr('classic_focus_time', fallback: 'Focus time');
      value = _clock(state.pomodoroRemainingMs);
      onDialTap = () => PomodoroConfigDialog.show(context, state: state, onSave: notifier.configurePomodoro);
      actions = [_RoundButton(icon: Icons.play_arrow_rounded, tooltip: t.tr('start', fallback: 'Start'), onTap: start)];
    } else {
      color = studyColor;
      fraction = (state.todayTotalMs / goal).clamp(0.0, 1.0);
      label = t.tr('classic_total_today', fallback: 'Total time today');
      value = _clock(state.todayTotalMs);
      actions = [_RoundButton(icon: Icons.play_arrow_rounded, tooltip: t.tr('start', fallback: 'Start'), onTap: start)];
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox.fromSize(
        key: const ValueKey('classic-timer-area'),
        size: kClassicTimerAreaSize,
        child: Row(
          children: [
            if (showDial) ...[
              Tooltip(
                message: t.tr('classic_dial_hint', fallback: 'Right-click to change colours'),
                waitDuration: const Duration(seconds: 1),
                child: GestureDetector(
                  key: const ValueKey('classic-dial'),
                  onTap: onDialTap,
                  onSecondaryTap: () => DialStyleDialog.show(context),
                  onLongPress: () => DialStyleDialog.show(context),
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: fraction),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => CustomPaint(painter: _TickDialPainter(f, color, palette.textMuted)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, height: 1.3, color: palette.textSecondary)),
                  ),
                  SizedBox(
                    height: 68,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        key: const ValueKey('classic-focus-time'),
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Fixed slot for up to two buttons, right-aligned: Pause/Stop and
            // Play take the same space, so nothing moves between states.
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    actions[i],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 96,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StudiconAvatar(
                    studiconId: user?.studiconId ?? state.studiconId,
                    pose: CdnResolver.resolvePose(
                      isStudying: state.isRunning,
                      isPaused: state.isPaused,
                      studyMs: state.todayTotalMs,
                    ),
                    size: 68,
                    isStudying: state.isRunning,
                  ),
                  const SizedBox(height: 4),
                  Text(_clock(state.todayTotalMs),
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// YPT's clock-face dial: minute ticks, 0–55 labels, and a wedge from the top.
class _TickDialPainter extends CustomPainter {
  _TickDialPainter(this.fraction, this.color, this.muted);
  final double fraction;
  final Color color;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    for (var i = 0; i < 60; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / 60;
      final dir = Offset(math.cos(a), math.sin(a));
      final long = i % 5 == 0;
      canvas.drawLine(c + dir * (r - (long ? 9 : 5)), c + dir * r,
          Paint()
            ..color = muted.withValues(alpha: long ? 0.9 : 0.5)
            ..strokeWidth = long ? 1.6 : 1);
      if (long) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$i',
              style: TextStyle(
                  fontFamily: AppTextStyles.fontText,
                  fontFamilyFallback: AppTextStyles.fontFallbacks,
                  fontSize: 8,
                  color: muted)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c + dir * (r - 18) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    final wedge = r - 24;
    if (fraction > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: wedge), -math.pi / 2, 2 * math.pi * fraction, true,
          Paint()..color = color);
    }
    canvas.drawCircle(c, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TickDialPainter old) =>
      old.fraction != fraction || old.color != color || old.muted != muted;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.filled = true});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? palette.textPrimary : palette.card,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 22, color: filled ? palette.background : palette.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _SubjectsCard extends ConsumerWidget {
  const _SubjectsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final palette = context.palette;
    final subjects = state.subjects.where((s) => !s.isArchived && !s.isDeleted).toList();

    return ClassicCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text(t.tr('stats_subjects', fallback: 'Subjects'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              const Spacer(),
              TextButton.icon(
                key: const ValueKey('classic-edit-subject'),
                icon: Icon(Icons.edit_outlined, size: 16, color: palette.textSecondary),
                label: Text(t.tr('classic_edit_subject', fallback: 'Edit subject'),
                    style: TextStyle(fontSize: 13, color: palette.textSecondary)),
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
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, i) => _SubjectRow(
                subject: subjects[i],
                selected: subjects[i].id == state.currentSubject?.id,
                onPlay: () async {
                  notifier.selectSubject(subjects[i]);
                  await notifier.startStudy();
                },
              ),
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(12),
      onTap: onPlay,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? palette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                subject.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              _clock(subject.studyMs),
              style: TextStyle(
                fontSize: 15,
                color: subject.studyMs > 0 ? palette.textPrimary : palette.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Right pane on wide windows: today's goal progress and today's to-dos.
class _TodayPane extends ConsumerWidget {
  const _TodayPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final timer = ref.watch(timerNotifierProvider);
    final goal = math.max(1, timer.dailyGoalMinutes * 60000);
    final progress = (timer.todayTotalMs / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kClassicHeaderHeight),
        ClassicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.tr('classic_today', fallback: 'Today'),
                  style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              const SizedBox(height: 4),
              Text(_clock(timer.todayTotalMs),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: kStatOrange,
                    backgroundColor: palette.card,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                key: const ValueKey('classic-edit-goal'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => DailyGoalDialog.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          '${t.tr('classic_daily_goal', fallback: 'Daily goal')} ${formatHourMin(goal)} · ${(progress * 100).round()}%',
                          style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                    ),
                    Icon(Icons.edit_outlined, size: 15, color: palette.textMuted),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Expanded(child: _HomeTodoCard()),
      ],
    );
  }
}

/// Home To-Do: every unticked task from today and the last
/// [TodoNotifier.carryOverDays] days. A task stays until it is ticked; ticked
/// tasks leave this list but stay on their day in the To-Do tab.
class _HomeTodoCard extends ConsumerStatefulWidget {
  const _HomeTodoCard();

  @override
  ConsumerState<_HomeTodoCard> createState() => _HomeTodoCardState();
}

class _HomeTodoCardState extends ConsumerState<_HomeTodoCard> {
  bool _adding = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    setState(() => _adding = false);
    _controller.clear();
    if (title.isEmpty) return;
    final notifier = ref.read(todoNotifierProvider.notifier);
    await notifier.add(title, dateYmd: notifier.todayKey);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final open = ref.watch(todoNotifierProvider.select((s) => s.openTodos));
    final notifier = ref.read(todoNotifierProvider.notifier);
    final today = notifier.todayKey;

    final children = <Widget>[
      if (_adding)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextField(
            key: const ValueKey('classic-home-todo-field'),
            controller: _controller,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.radio_button_unchecked_rounded, size: 18, color: palette.textMuted),
              hintText: t.tr('classic_enter_todo', fallback: 'Enter to-do'),
              hintStyle: TextStyle(fontSize: 14, color: palette.textMuted),
            ),
            onSubmitted: (_) => _submit(),
            onTapOutside: (_) => _submit(),
          ),
        ),
    ];
    String? lastDay;
    for (final todo in open) {
      if (todo.dateYmd != lastDay) {
        lastDay = todo.dateYmd;
        if (todo.dateYmd != today) {
          final d = DateTime.tryParse(todo.dateYmd);
          children.add(Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2, left: 4),
            child: Text(d == null ? todo.dateYmd : DateFormat('EEE, MMM d').format(d),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textMuted)),
          ));
        }
      }
      children.add(InkWell(
        key: ValueKey('classic-home-todo-${todo.id}-${todo.dateYmd}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => notifier.toggle(todo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Icon(Icons.circle_outlined, size: 20, color: palette.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(todo.title, style: TextStyle(fontSize: 14, color: palette.textPrimary)),
            ),
          ]),
        ),
      ));
    }

    return ClassicCard(
      title: t.tr('classic_tab_todo', fallback: 'To-Do'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${open.length}', style: TextStyle(fontSize: 13, color: palette.textMuted)),
        IconButton(
          key: const ValueKey('classic-home-todo-add'),
          tooltip: t.tr('classic_add', fallback: 'Add'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_rounded, size: 20, color: kStatOrange),
          onPressed: () => setState(() {
            _adding = true;
            _controller.clear();
          }),
        ),
      ]),
      child: children.isEmpty
          ? Center(
              child: TextButton(
                onPressed: () => setState(() => _adding = true),
                child: Text(t.tr('classic_add_todo', fallback: 'Plan today in To-Do'),
                    style: const TextStyle(color: kStatOrange)),
              ),
            )
          : ListView(children: children),
    );
  }
}

class _FocusingView extends ConsumerWidget {
  const _FocusingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final palette = context.palette;
    final isPomodoro = state.mode == TimerMode.pomodoro;
    final String label;
    final String value;
    if (state.isPaused) {
      label = t.tr('classic_break', fallback: 'Break');
      value = _clock(state.sessionRestMs);
    } else if (state.isRunning) {
      label = isPomodoro
          ? t.tr('classic_remaining_time', fallback: 'Remaining time')
          : t.tr('classic_focusing', fallback: 'Focusing');
      value = isPomodoro ? _clock(state.pomodoroRemainingMs) : _clock(state.sessionElapsedMs);
    } else {
      label = t.tr('classic_total_today', fallback: 'Total time today');
      value = _clock(state.todayTotalMs);
    }

    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              Text(
                value,
                key: const ValueKey('classic-focusing-time'),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('${state.currentSubject?.title ?? ''}  ${_clock(state.todayTotalMs)}',
                  style: TextStyle(fontSize: 13, color: palette.textMuted)),
              const SizedBox(height: 12),
              if (state.isRunning)
                _RoundButton(icon: Icons.pause_rounded, tooltip: t.tr('pause', fallback: 'Pause'), onTap: notifier.pauseStudy)
              else if (state.isPaused)
                _RoundButton(
                    icon: Icons.play_arrow_rounded, tooltip: t.tr('restart', fallback: 'Resume'), onTap: notifier.startStudy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live members of one of the user's groups. Refreshed every minute; the
/// times of studying members tick every second between refreshes. A click on
/// a member opens their card (stats and Nudge).
class _GroupPanel extends ConsumerStatefulWidget {
  const _GroupPanel({super.key});

  @override
  ConsumerState<_GroupPanel> createState() => _GroupPanelState();
}

class _GroupPanelState extends ConsumerState<_GroupPanel> {
  int _index = 0;
  List<GroupMemberModel>? _members;
  int? _loadedGroup;
  DateTime _fetchedAt = DateTime.now();
  Timer? _refresh;
  Timer? _tick;
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _load(force: true));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _now.value = DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    _now.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final groups = ref.read(orderedMyGroupsProvider);
    if (groups.isEmpty || ref.read(settingsNotifierProvider).offlineMode) return;
    final group = groups[_index % groups.length];
    if (!force && _loadedGroup == group.id) return;
    _loadedGroup = group.id;
    try {
      final members = await ref.read(groupRepositoryProvider).fetchMembers(group.id);
      if (!mounted || _loadedGroup != group.id) return;
      setState(() {
        _members = members;
        _fetchedAt = DateTime.now();
      });
    } catch (_) {}
  }

  void _move(int delta, int count) {
    setState(() {
      _index = ((_index + delta) % count + count) % count;
      _members = null;
      _loadedGroup = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final groups = ref.watch(orderedMyGroupsProvider);
    final myId = ref.watch(authStateProvider.select((s) => s.user?.id));
    if (ref.watch(settingsNotifierProvider.select((s) => s.offlineMode))) {
      return ClassicCard(
        child: Center(
          child: Text(t.tr('classic_group_offline', fallback: 'Offline mode: your group shows up when you go online.'),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: palette.textMuted)),
        ),
      );
    }
    if (groups.isEmpty) {
      return ClassicCard(
        child: Center(
          child: TextButton(
            onPressed: () => context.go('/groups'),
            child: Text(t.tr('classic_join_group', fallback: 'Join a group to study together'),
                style: const TextStyle(color: kStatOrange)),
          ),
        ),
      );
    }
    final group = groups[_index % groups.length];
    final members = _loadedGroup == group.id ? _members : null;
    final studying = members?.where((m) => m.isStudying && !m.isPaused).length ?? 0;
    // My own tile follows the local timer, so it always equals "Today".
    final myToday = ref.watch(timerNotifierProvider.select((s) => s.todayTotalMs));
    final meActive = ref.watch(timerNotifierProvider.select((s) => s.isRunning && !s.isPaused));

    return ClassicCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '$studying ${t.tr('classic_people', fallback: 'people')}',
                          style: const TextStyle(color: kStatOrange)),
                      TextSpan(
                          text: ' ${t.tr('studying', fallback: 'Studying')}',
                          style: TextStyle(color: palette.textSecondary)),
                    ]), style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (groups.length > 1) ...[
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: palette.textSecondary),
                  onPressed: () => _move(-1, groups.length),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
                  onPressed: () => _move(1, groups.length),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: members == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kStatOrange))
                : ValueListenableBuilder<DateTime>(
                    valueListenable: _now,
                    builder: (context, now, _) {
                      // One ranking by today's total, studying or not.
                      final ranked = [
                        for (final m in members)
                          (
                            member: m,
                            isMe: m.userId == myId,
                            active: m.userId == myId ? meActive : m.isStudying && !m.isPaused,
                            ms: m.userId == myId ? myToday : liveMemberStudyMs(m, now, _fetchedAt),
                          ),
                      ]..sort((a, b) {
                          final c = b.ms.compareTo(a.ms);
                          return c != 0 ? c : a.member.userId.compareTo(b.member.userId);
                        });
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisExtent: 138,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: ranked.length,
                        itemBuilder: (context, i) => _MemberTile(
                          key: ValueKey('classic-member-tile-${ranked[i].member.userId}'),
                          member: ranked[i].member,
                          isMe: ranked[i].isMe,
                          active: ranked[i].active,
                          studyMs: ranked[i].ms,
                          onTap: () => MemberSheet.show(context, groupId: group.id, member: ranked[i].member),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Today's study time of a group member at [now].
///
/// The API's `sm` counts finished sessions only; a running session is added
/// from its start `dl.st`. Without a usable start the time since the fetch is
/// the best available estimate.
int liveMemberStudyMs(GroupMemberModel m, DateTime now, DateTime fetchedAt) {
  if (!m.isStudying || m.isPaused) return m.studyMs;
  final start = m.sessionStartedAt;
  final running = now.difference(start ?? fetchedAt).inMilliseconds;
  return m.studyMs + math.max(0, running);
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    super.key,
    required this.member,
    required this.isMe,
    required this.active,
    required this.studyMs,
    required this.onTap,
  });
  final GroupMemberModel member;
  final bool isMe;
  final bool active;
  final int studyMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? kStatOrange : palette.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('classic-member-${member.userId}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isMe ? Border.all(color: kStatOrange, width: 1.5) : null,
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 66,
                // Same avatar either way; not studying is just greyed out.
                child: Greyed(
                  enabled: !active,
                  child: StudiconAvatar(
                    studiconId: member.studiconId,
                    pose: CdnResolver.resolvePose(isStudying: true, studyMs: studyMs),
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: color)),
              Text(_clock(studyMs),
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
