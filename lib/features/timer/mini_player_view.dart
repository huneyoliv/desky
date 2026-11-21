import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:window_manager/window_manager.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import '../auth/auth_notifier.dart';
import '../ranks/ranks_screen.dart' show rankRepositoryProvider;
import '../settings/settings_notifier.dart';
import '../statistics/stats_data.dart';
import 'focus_mode_notifier.dart';
import 'timer_notifier.dart';

const Color _orange = Color(0xFFFF6B1A);

/// This week's study time for the mini player: one small request, made when
/// the stats row is shown and dropped when it is hidden.
final miniWeekFocusProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
  if (userId == null) return 0;
  final today = dateOnly(DateTime.now());
  final fmt = DateFormat('yyyy-MM-dd');
  final byDay = await ref.read(rankRepositoryProvider).fetchDailyStudyMs(
        userId: userId,
        startDate: fmt.format(mondayOf(today)),
        endDate: fmt.format(today),
      );
  return byDay.values.fold<int>(0, (a, b) => a + b);
});

/// Whether the mini player shows its opacity slider instead of the stats.
final miniOpacityOpenProvider = StateProvider.autoDispose<bool>((ref) => false);

String _clock(int ms) {
  final s = math.max(0, ms) ~/ 1000;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// TickTick-style floating timer: always on top, adjustable opacity, drag it
/// anywhere, and drop it on a screen edge to tuck it away behind a thin
/// handle that slides it back out on hover.
class MiniPlayerView extends ConsumerStatefulWidget {
  const MiniPlayerView({super.key});

  @override
  ConsumerState<MiniPlayerView> createState() => _MiniPlayerViewState();
}

class _MiniPlayerViewState extends ConsumerState<MiniPlayerView> with WindowListener {
  MiniDockSide _dock = MiniDockSide.none;
  bool _hidden = false;
  bool _hovering = false;
  Timer? _hideTimer;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyOpacity(ref.read(settingsNotifierProvider).miniOpacity);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _applyOpacity(double v) async {
    try {
      await windowManager.setOpacity(v);
    } catch (_) {}
  }

  @override
  void onWindowMoved() => _checkDock();

  Future<void> _checkDock() async {
    if (_moving) return;
    try {
      final bounds = await windowManager.getBounds();
      final displays = await FocusModeNotifier.displayAreas();
      final display = MiniDock.displayAreaFor(bounds, displays);
      if (display == null) return;
      final side = MiniDock.sideFor(bounds, display, displays);
      if (!mounted) return;
      setState(() {
        _dock = side;
        _hidden = false;
      });
      if (side != MiniDockSide.none) {
        await _moveTo(MiniDock.positionFor(side, bounds, display, hidden: false));
        if (!_hovering) _scheduleHide();
      }
    } catch (_) {}
  }

  Future<void> _moveTo(Offset p) async {
    _moving = true;
    try {
      await windowManager.setPosition(p);
    } catch (_) {
    } finally {
      // Ignore the "moved" event our own move causes.
      Future.delayed(const Duration(milliseconds: 150), () => _moving = false);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_dock == MiniDockSide.none) return;
    _hideTimer = Timer(const Duration(milliseconds: 700), () => _setHidden(true));
  }

  Future<void> _setHidden(bool hidden) async {
    if (_dock == MiniDockSide.none || hidden == _hidden) return;
    try {
      final bounds = await windowManager.getBounds();
      final displays = await FocusModeNotifier.displayAreas();
      final display = MiniDock.displayAreaFor(bounds, displays);
      if (display == null) return;
      await _moveTo(MiniDock.positionFor(_dock, bounds, display, hidden: hidden));
      if (mounted) setState(() => _hidden = hidden);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<double>(settingsNotifierProvider.select((s) => s.miniOpacity), (_, v) => _applyOpacity(v));
    final palette = context.palette;

    return MouseRegion(
      onEnter: (_) {
        _hovering = true;
        _hideTimer?.cancel();
        if (_hidden) _setHidden(false);
      },
      onExit: (_) {
        _hovering = false;
        _scheduleHide();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _hidden
            ? _Handle(key: const ValueKey('mini-handle'), side: _dock)
            : Container(
                key: const ValueKey('mini-card'),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border.withValues(alpha: 0.7)),
                ),
                clipBehavior: Clip.antiAlias,
                child: const DragToMoveArea(child: _MiniContent()),
              ),
      ),
    );
  }
}

/// What stays on screen while tucked away: a slim rounded grip.
class _Handle extends StatelessWidget {
  const _Handle({super.key, required this.side});
  final MiniDockSide side;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: side == MiniDockSide.left ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MiniDock.handleWidth,
        height: 96,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.horizontal(
            left: side == MiniDockSide.right ? const Radius.circular(8) : Radius.zero,
            right: side == MiniDockSide.left ? const Radius.circular(8) : Radius.zero,
          ),
          border: Border.all(color: palette.border),
        ),
        alignment: Alignment.center,
        child: Container(width: 3, height: 28, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2))),
      ),
    );
  }
}

class _MiniContent extends ConsumerWidget {
  const _MiniContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final focus = ref.watch(focusModeProvider);
    final focusNotifier = ref.read(focusModeProvider.notifier);
    final palette = context.palette;
    final isPomodoro = state.mode == TimerMode.pomodoro;
    final subject = state.currentSubject;

    final settings = ref.watch(settingsNotifierProvider);
    final double fraction;
    final String time;
    final Color ring;
    if (state.isPaused) {
      ring = Color(settings.dialBreakColor);
      time = _clock(state.sessionRestMs);
      fraction = (state.sessionRestMs / math.max(1, state.pomodoroShortBreakMinutes * 60000)).clamp(0.0, 1.0);
    } else if (state.isRunning) {
      ring = Color(settings.dialStudyColor);
      time = _clock(isPomodoro ? state.pomodoroRemainingMs : state.sessionElapsedMs);
      fraction = isPomodoro
          ? (state.pomodoroRemainingMs / math.max(1, state.pomodoroFocusMinutes * 60000)).clamp(0.0, 1.0)
          : (state.sessionElapsedMs % 3600000) / 3600000;
    } else {
      ring = Color(settings.dialStudyColor);
      time = isPomodoro ? _clock(state.pomodoroRemainingMs) : _clock(state.todayTotalMs);
      fraction = isPomodoro ? 1 : 0;
    }

    Future<void> primary() async {
      if (state.isRunning) {
        await notifier.pauseStudy();
      } else if (state.isPaused) {
        await notifier.startStudy();
      } else {
        final subjects = state.subjects.where((s) => !s.isArchived && !s.isDeleted);
        final s = subject ?? (subjects.isEmpty ? null : subjects.first);
        if (s == null) return;
        notifier.selectSubject(s);
        await notifier.startStudy();
      }
    }

    Widget icon(IconData i, String tip, VoidCallback onTap, {Key? key}) => Tooltip(
          message: tip,
          child: InkResponse(
            key: key,
            radius: 14,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(i, size: 15, color: palette.textMuted),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        children: [
          SizedBox(
            height: 94,
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: fraction),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, f, _) =>
                            CustomPaint(size: const Size(76, 76), painter: _RingPainter(f, ring, palette.border)),
                      ),
                      Material(
                        color: palette.card,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const ValueKey('mini-primary'),
                          customBorder: const CircleBorder(),
                          onTap: primary,
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: Icon(
                              state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: palette.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            state.isPaused
                                ? t.tr('classic_break', fallback: 'Break')
                                : (subject?.title ?? t.tr('classic_total_today', fallback: 'Total time today')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          time,
                          key: const ValueKey('mini-time'),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      icon(
                        focus.miniExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                        t.tr('classic_mini_stats', fallback: 'Today and week'),
                        focusNotifier.toggleMiniExpanded,
                        key: const ValueKey('mini-expand'),
                      ),
                      const _OpacityMenu(),
                      icon(Icons.close_rounded, t.tr('classic_mini_exit', fallback: 'Back to the full window'),
                          focusNotifier.toggleMiniPlayer,
                          key: const ValueKey('mini-close')),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          if (focus.miniExpanded) ...[
            Divider(color: palette.border, height: 14),
            Expanded(
              child: ref.watch(miniOpacityOpenProvider)
                  ? const _OpacityRow()
                  : _MiniStats(todayMs: state.todayTotalMs),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStats extends ConsumerWidget {
  const _MiniStats({required this.todayMs});
  final int todayMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final week = ref.watch(miniWeekFocusProvider).valueOrNull;
    Widget cell(String label, String value) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: palette.textMuted)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        );
    return Row(children: [
      cell(t.tr('classic_today_focus', fallback: 'Today focus'), formatHourMin(todayMs)),
      // The week figure comes from the last fetch; never show it below
      // today's live total.
      cell(t.tr('classic_week_focus', fallback: 'Week focus'), week == null ? '…' : formatHourMin(math.max(week, todayMs))),
    ]);
  }
}

/// "…" button: opens the opacity slider inside the card.
class _OpacityMenu extends ConsumerWidget {
  const _OpacityMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    return Tooltip(
      message: t.tr('classic_mini_opacity', fallback: 'Opacity'),
      child: InkResponse(
        key: const ValueKey('mini-more'),
        radius: 14,
        onTap: () {
          final open = !ref.read(miniOpacityOpenProvider);
          ref.read(miniOpacityOpenProvider.notifier).state = open;
          final focus = ref.read(focusModeProvider);
          if (open && !focus.miniExpanded) ref.read(focusModeProvider.notifier).toggleMiniExpanded();
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.more_horiz_rounded, size: 15, color: palette.textMuted),
        ),
      ),
    );
  }
}

class _OpacityRow extends ConsumerWidget {
  const _OpacityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final v = ref.watch(settingsNotifierProvider.select((s) => s.miniOpacity));
    return Row(children: [
      Icon(Icons.opacity_rounded, size: 16, color: palette.textMuted),
      Expanded(
        child: Slider(
          key: const ValueKey('mini-opacity'),
          value: v,
          min: 0.3,
          max: 1.0,
          activeColor: _orange,
          label: t.tr('classic_mini_opacity', fallback: 'Opacity'),
          onChanged: (x) => ref.read(settingsNotifierProvider.notifier).setMiniOpacity(x),
        ),
      ),
      SizedBox(
        width: 40,
        child: Text('${(v * 100).round()}%', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track);
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = track);
    if (fraction > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * fraction, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction || old.color != color;
}
