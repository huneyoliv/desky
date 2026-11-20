import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import 'timer_notifier.dart';
import 'widgets/timer_display.dart';
import 'widgets/subject_management_dialog.dart';
import 'widgets/pomodoro_config_dialog.dart';
import 'widgets/manual_study_log_dialog.dart';
import 'offline_sync_notifier.dart';
import 'focus_mode_notifier.dart';
import '../settings/widgets/app_settings_dialog.dart';

class TimerScreen extends ConsumerWidget {
  /// Identifies the top bar in tests, which assert it spans the window so the
  /// bar cannot be centred by its own content.
  static const Key headerKey = ValueKey('timer-header');
  static const settingsButtonKey = ValueKey('timer-settings-button');

  const TimerScreen({super.key});

  String _formatTotalTime(int ms) {
    final totalSecs = ms ~/ 1000;
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerNotifierProvider);
    final notifier = ref.read(timerNotifierProvider.notifier);
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;

    final currentSubjectColor =
        timerState.currentSubject?.color ?? palette.primary;

    final isPomodoro = timerState.mode == TimerMode.pomodoro;
    final displayMs = isPomodoro ? timerState.pomodoroRemainingMs : timerState.sessionElapsedMs;

    final phaseLabel = switch (timerState.pomodoroPhase) {
      PomodoroPhase.focus => t.tr('timer_options_pomodoro_study', fallback: 'Foco'),
      PomodoroPhase.shortBreak => t.tr('timer_options_pomodoro_break', fallback: 'Pausa Curta'),
      PomodoroPhase.longBreak => t.tr('study_rest_label', fallback: 'Pausa Longa'),
    };

    final phaseColor = switch (timerState.pomodoroPhase) {
      PomodoroPhase.focus => currentSubjectColor,
      PomodoroPhase.shortBreak => AppColors.success,
      PomodoroPhase.longBreak => AppColors.warning,
    };

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header - Study Time & Rest Time & Mode Switcher
            //
            // The bar is full width on purpose: a Container without a width in a
            // centred Column shrinks to its content and gets centred, so a longer
            // subject name used to shift the whole bar sideways. The subject chip
            // is bounded below for the same reason.
            Container(
              key: TimerScreen.headerKey,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: palette.surface,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Total time: fixed width and tabular figures so 0s -> 1h 23m does not
// push the mode switcher and the icons sideways.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.tr('today_total_study_time', fallback: 'Tempo de Estudo'), style: AppTextStyles.labelSmall.copyWith(color: context.appTextMuted)),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatTotalTime(timerState.todayTotalMs),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fontDisplay,
                                  fontFamilyFallback: AppTextStyles.fontFallbacks,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),

                    // Mode Switcher Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeTab(
                            context: context,
                            label: t.tr('bottom_home', fallback: 'Cronômetro'),
                            isSelected: !isPomodoro,
                            onTap: timerState.isRunning
                                ? null
                                : () => notifier.setTimerMode(TimerMode.stopwatch),
                          ),
                          _buildModeTab(
                            context: context,
                            label: t.tr('timer_options_pomodoro', fallback: 'Pomodoro'),
                            isSelected: isPomodoro,
                            onTap: timerState.isRunning
                                ? null
                                : () => notifier.setTimerMode(TimerMode.pomodoro),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Focus Mode Distraction-Free Toggle
                        IconButton(
                          tooltip: t.tr('focus', fallback: 'Modo Foco Sem Distrações'),
                          icon: Icon(Icons.fullscreen_rounded, color: palette.textSecondary),
                          onPressed: () => ref.read(focusModeProvider.notifier).toggleStrictFocus(),
                        ),

                        // Mini-Player Floating Window Toggle
                        IconButton(
                          tooltip: t.tr('mini_player', fallback: 'Mini-Player Flutuante'),
                          icon: Icon(Icons.picture_in_picture_alt_rounded, color: palette.textSecondary),
                          onPressed: () => ref.read(focusModeProvider.notifier).toggleMiniPlayer(),
                        ),

                        // Manual Study Log Button
                        IconButton(
                          tooltip: t.tr('alert_planner_add_study_log', fallback: 'Registro Manual de Estudo'),
                          icon: Icon(Icons.edit_calendar_rounded, color: palette.primaryLight),
                          onPressed: () => ManualStudyLogDialog.show(context),
                        ),
                        const SizedBox(width: 8),

                        // Subject Selector Badge
                        InkWell(
                          onTap: () {
                            SubjectManagementDialog.show(
                              context,
                              subjects: timerState.subjects,
                              selectedSubject: timerState.currentSubject,
                              onSelectSubject: (subject) => notifier.selectSubject(subject),
                              onCreateSubject: (title, colorInt) => notifier.createSubject(title, colorInt),
                              onUpdateSubject: (subject) => notifier.updateSubject(subject),
                              onArchiveSubject: (id, archive) => notifier.archiveSubject(id, archive),
                              onDeleteSubject: (id) => notifier.deleteSubject(id),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: currentSubjectColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: currentSubjectColor, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: currentSubjectColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Bounded so a long subject name cannot widen
                                // the bar; the chip truncates instead.
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    timerState.currentSubject?.title ?? t.tr('timer_study_subject', fallback: 'Selecionar Matéria'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      // Subject names read like every other label;
                                      // the dot and border keep the subject colour.
                                      color: context.appTextPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, color: currentSubjectColor, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                  ),
                  // App settings: Discord, OBS overlay, look.
                  IconButton(
                    key: TimerScreen.settingsButtonKey,
                    tooltip: t.tr('settings', fallback: 'Settings'),
                    icon: Icon(Icons.settings_outlined, color: palette.textSecondary),
                    onPressed: () => AppSettingsDialog.show(context),
                  ),
                ],
              ),
            ),

            // Pomodoro Info Banner & Config Button
            //
            // The slot keeps the same height in both modes, so switching to
            // Pomodoro does not push the timer block down. Only the content
            // toggles; the reserved space stays.
            // Pomodoro Info Banner & Config Button
            //
            // The slot keeps the same height in both modes, so switching to
            // Pomodoro does not push the timer block down. Only the content
            // toggles; the reserved space stays.
            SizedBox(
              height: 84,
              child: Align(
                alignment: Alignment.topCenter,
                child: isPomodoro
                    ? Container(
                        margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: phaseColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: phaseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${timerState.currentPomodoroCycle}/${timerState.totalPomodoroCycles} • $phaseLabel',
                                  style: TextStyle(
                                    color: phaseColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (timerState.isRunning || timerState.isPaused)
                                  TextButton.icon(
                                    onPressed: () => notifier.skipPomodoroPhase(),
                                    icon: const Icon(Icons.skip_next,
                                        size: 18, color: AppColors.textSecondary),
                                    label: Text(
                                      t.tr('skip', fallback: 'Pular'),
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined,
                                      size: 20, color: AppColors.textSecondary),
                                  onPressed: () => PomodoroConfigDialog.show(
                                    context,
                                    state: timerState,
                                    onSave: notifier.configurePomodoro,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Offline Sync Pending Banner
            if (ref.watch(offlineSyncNotifierProvider).hasPending) ...[
              Builder(
                builder: (context) {
                  final syncState = ref.watch(offlineSyncNotifierProvider);
                  return Container(
                    margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_off, color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${syncState.pendingCount} ${t.tr("pending", fallback: "pendente(s)")}',
                              style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: syncState.isSyncing
                              ? null
                              : () async {
                                  final res = await ref.read(offlineSyncNotifierProvider.notifier).syncNow();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res.remaining == 0
                                              ? t.tr('synchronized', fallback: 'Sincronizado!')
                                              : '${res.totalSynced} ${t.tr("sent", fallback: "enviadas")}, ${res.remaining} ${t.tr("pending", fallback: "pendentes.")}',
                                        ),
                                        backgroundColor: res.remaining == 0 ? AppColors.success : AppColors.warning,
                                      ),
                                    );
                                  }
                                },
                          child: syncState.isSyncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                                )
                              : Text(
                                  t.tr('refresh', fallback: 'Sincronizar'),
                                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Center Timer Area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TimerDisplay(
                          elapsedMs: timerState.isPaused ? timerState.sessionRestMs : displayMs,
                          fontSize: 64,
                        ),
                        // Fixed-height slot: the paused chip and the subject
                        // name have different heights, and without a reserved
                        // box the digits moved up or down when pausing.
                        SizedBox(
                          height: 44,
                          child: Center(
                            child: timerState.isPaused
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.resting.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.resting.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.coffee_rounded, color: AppColors.resting, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          t.tr("study_rest_label", fallback: "Em Descanso"),
                                          style: const TextStyle(
                                            color: AppColors.resting,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : timerState.currentSubject != null
                                    // Bounded so a long name cannot push the
                                    // timer block wider than the window.
                                    ? ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 320),
                                        child: Text(
                                          timerState.currentSubject!.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: currentSubjectColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Timer Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!timerState.isRunning && !timerState.isPaused) ...[
                          ElevatedButton.icon(
                            onPressed: timerState.currentSubject == null
                                ? null
                                : () => notifier.startStudy(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: phaseColor,
                              disabledBackgroundColor: AppColors.surfaceLight.withValues(alpha: 0.4),
                              disabledForegroundColor: AppColors.stopped,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              // Width does not depend on the label, so
                              // "INICIAR" and "INICIAR FOCO" occupy the same box
                              // and the button does not move between modes.
                              minimumSize: const Size(240, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: Icon(
                              Icons.play_arrow_rounded,
                              color: timerState.currentSubject == null ? AppColors.stopped : Colors.white,
                              size: 28,
                            ),
                            label: Text(
                              isPomodoro
                                  ? '${t.tr("start", fallback: "INICIAR")} $phaseLabel'.toUpperCase()
                                  : t.tr("start", fallback: "INICIAR").toUpperCase(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: timerState.currentSubject == null ? AppColors.stopped : Colors.white,
                              ),
                            ),
                          ),
                        ],

                        if (timerState.isRunning) ...[
                          ElevatedButton.icon(
                            onPressed: () => notifier.pauseStudy(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.resting,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: const Icon(Icons.pause_rounded, color: Colors.white, size: 24),
                            label: Text(t.tr('pause', fallback: 'PAUSAR').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () => notifier.stopStudy(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                            label: Text(t.tr('stop', fallback: 'PARAR').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ],

                        if (timerState.isPaused) ...[
                          ElevatedButton.icon(
                            onPressed: () => notifier.startStudy(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: phaseColor,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            label: Text(t.tr('restart', fallback: 'RETOMAR').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () => notifier.stopStudy(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                            label: Text(t.tr('stop', fallback: 'PARAR').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : palette.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
