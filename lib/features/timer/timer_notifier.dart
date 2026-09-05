import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/study_date_helper.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../data/repositories/offline_sync_repository.dart';
import '../auth/auth_notifier.dart';
import '../settings/settings_notifier.dart';
import 'offline_sync_notifier.dart';

enum TimerMode {
  stopwatch,
  pomodoro,
}

enum PomodoroPhase {
  focus,
  shortBreak,
  longBreak,
}

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository();
});

final timerRepositoryProvider = Provider<TimerRepository>((ref) {
  return TimerRepository();
});

class TimerState {
  final bool isRunning;
  final bool isPaused;
  final int sessionElapsedMs;
  final int lastSyncedSessionElapsedMs;
  final int todayTotalMs;
  final int sessionRestMs;
  final int todayRestMs;
  final int dailyGoalMinutes;
  final SubjectModel? currentSubject;
  final List<SubjectModel> subjects;
  final DateTime? sessionStartAt;
  final DateTime? restStartAt;
  final String lastStudyDate;
  final int studiconId;

  final TimerMode mode;
  final PomodoroPhase pomodoroPhase;
  final int currentPomodoroCycle;
  final int totalPomodoroCycles;
  final int pomodoroFocusMinutes;
  final int pomodoroShortBreakMinutes;
  final int pomodoroLongBreakMinutes;
  final int pomodoroRemainingMs;
  final bool autoStartBreaks;
  final bool autoStartFocus;

  const TimerState({
    this.isRunning = false,
    this.isPaused = false,
    this.sessionElapsedMs = 0,
    this.lastSyncedSessionElapsedMs = 0,
    this.todayTotalMs = 0,
    this.sessionRestMs = 0,
    this.todayRestMs = 0,
    this.dailyGoalMinutes = 360,
    this.currentSubject,
    this.subjects = const [],
    this.sessionStartAt,
    this.restStartAt,
    this.lastStudyDate = '',
    this.studiconId = -1,
    this.mode = TimerMode.stopwatch,
    this.pomodoroPhase = PomodoroPhase.focus,
    this.currentPomodoroCycle = 1,
    this.totalPomodoroCycles = 4,
    this.pomodoroFocusMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodoroRemainingMs = 25 * 60 * 1000,
    this.autoStartBreaks = false,
    this.autoStartFocus = false,
  });

  TimerState copyWith({
    bool? isRunning,
    bool? isPaused,
    int? sessionElapsedMs,
    int? lastSyncedSessionElapsedMs,
    int? todayTotalMs,
    int? sessionRestMs,
    int? todayRestMs,
    int? dailyGoalMinutes,
    SubjectModel? currentSubject,
    List<SubjectModel>? subjects,
    DateTime? sessionStartAt,
    DateTime? restStartAt,
    String? lastStudyDate,
    int? studiconId,
    TimerMode? mode,
    PomodoroPhase? pomodoroPhase,
    int? currentPomodoroCycle,
    int? totalPomodoroCycles,
    int? pomodoroFocusMinutes,
    int? pomodoroShortBreakMinutes,
    int? pomodoroLongBreakMinutes,
    int? pomodoroRemainingMs,
    bool? autoStartBreaks,
    bool? autoStartFocus,
  }) {
    return TimerState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      sessionElapsedMs: sessionElapsedMs ?? this.sessionElapsedMs,
      lastSyncedSessionElapsedMs: lastSyncedSessionElapsedMs ?? this.lastSyncedSessionElapsedMs,
      todayTotalMs: todayTotalMs ?? this.todayTotalMs,
      sessionRestMs: sessionRestMs ?? this.sessionRestMs,
      todayRestMs: todayRestMs ?? this.todayRestMs,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      currentSubject: currentSubject ?? this.currentSubject,
      subjects: subjects ?? this.subjects,
      sessionStartAt: sessionStartAt ?? this.sessionStartAt,
      restStartAt: restStartAt ?? this.restStartAt,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      studiconId: studiconId ?? this.studiconId,
      mode: mode ?? this.mode,
      pomodoroPhase: pomodoroPhase ?? this.pomodoroPhase,
      currentPomodoroCycle: currentPomodoroCycle ?? this.currentPomodoroCycle,
      totalPomodoroCycles: totalPomodoroCycles ?? this.totalPomodoroCycles,
      pomodoroFocusMinutes: pomodoroFocusMinutes ?? this.pomodoroFocusMinutes,
      pomodoroShortBreakMinutes: pomodoroShortBreakMinutes ?? this.pomodoroShortBreakMinutes,
      pomodoroLongBreakMinutes: pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
      pomodoroRemainingMs: pomodoroRemainingMs ?? this.pomodoroRemainingMs,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      autoStartFocus: autoStartFocus ?? this.autoStartFocus,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  final TimerRepository _timerRepository;
  final SubjectRepository _subjectRepository;
  final OfflineSyncRepository? _offlineSyncRepository;
  Timer? _ticker;
  Timer? _dayResetTimer;
  int _dayResetHour;

  TimerNotifier({
    required TimerRepository timerRepository,
    required SubjectRepository subjectRepository,
    OfflineSyncRepository? offlineSyncRepository,
    int userStudiconId = -1,
    int dayResetHour = 5,
  })  : _timerRepository = timerRepository,
        _subjectRepository = subjectRepository,
        _offlineSyncRepository = offlineSyncRepository,
        _dayResetHour = dayResetHour,
        super(TimerState(
          studiconId: userStudiconId,
          lastStudyDate: StudyDateHelper.getStudyDateString(null, dayResetHour),
        )) {
    loadSubjects();
    _dayResetTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStudyDateReset();
    });
  }

  void setDayResetHour(int hour) {
    if (_dayResetHour == hour) return;
    _dayResetHour = hour;
    _checkStudyDateReset();
  }

  void _checkStudyDateReset() {
    final currentStudyDate = StudyDateHelper.getStudyDateString(null, _dayResetHour);
    if (state.lastStudyDate.isNotEmpty && state.lastStudyDate != currentStudyDate) {
      final resetSubjects = state.subjects.map((s) => s.copyWith(studyMs: 0)).toList();
      final resetCurrent = state.currentSubject?.copyWith(studyMs: 0);
      state = state.copyWith(
        todayTotalMs: 0,
        todayRestMs: 0,
        subjects: resetSubjects,
        currentSubject: resetCurrent,
        lastStudyDate: currentStudyDate,
      );
      loadSubjects();
    }
  }

  Future<void> loadSubjects() async {
    try {
      final result = await _subjectRepository.fetchSubjectsData();
      if (!mounted) return;
      final subjects = result.subjects;
      final current = subjects.isNotEmpty ? subjects.first : null;

      state = state.copyWith(
        subjects: subjects,
        currentSubject: current,
        todayTotalMs: result.todayTotalMs,
        todayRestMs: result.todayRestMs,
        lastStudyDate: StudyDateHelper.getStudyDateString(null, _dayResetHour),
      );
    } catch (_) {
      if (!mounted) return;
      if (state.subjects.isEmpty) {
        const fallbackSubject = SubjectModel(
          id: 1,
          title: 'Matéria Inicial',
          colorInt: 4292557552,
        );
        state = state.copyWith(
          subjects: [fallbackSubject],
          currentSubject: fallbackSubject,
        );
      }
    }
  }

  void selectSubject(SubjectModel subject) {
    if (state.isRunning) return;
    state = state.copyWith(
      currentSubject: subject,
      sessionElapsedMs: 0,
      lastSyncedSessionElapsedMs: 0,
    );
  }

  void setTimerMode(TimerMode mode) {
    if (state.isRunning) return;
    state = state.copyWith(
      mode: mode,
      isPaused: false,
      sessionElapsedMs: 0,
      lastSyncedSessionElapsedMs: 0,
      pomodoroRemainingMs: state.pomodoroFocusMinutes * 60 * 1000,
      pomodoroPhase: PomodoroPhase.focus,
    );
  }

  void setDailyGoalMinutes(int minutes) {
    state = state.copyWith(dailyGoalMinutes: minutes);
  }

  void configurePomodoro({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? totalCycles,
    bool? autoStartBreaks,
    bool? autoStartFocus,
  }) {
    final newFocus = focusMinutes ?? state.pomodoroFocusMinutes;
    final newShort = shortBreakMinutes ?? state.pomodoroShortBreakMinutes;
    final newLong = longBreakMinutes ?? state.pomodoroLongBreakMinutes;
    final newCycles = totalCycles ?? state.totalPomodoroCycles;
    final newAutoBreaks = autoStartBreaks ?? state.autoStartBreaks;
    final newAutoFocus = autoStartFocus ?? state.autoStartFocus;

    int newRemaining = state.pomodoroRemainingMs;
    if (!state.isRunning) {
      if (state.pomodoroPhase == PomodoroPhase.focus) {
        newRemaining = newFocus * 60 * 1000;
      } else if (state.pomodoroPhase == PomodoroPhase.shortBreak) {
        newRemaining = newShort * 60 * 1000;
      } else {
        newRemaining = newLong * 60 * 1000;
      }
    }

    state = state.copyWith(
      pomodoroFocusMinutes: newFocus,
      pomodoroShortBreakMinutes: newShort,
      pomodoroLongBreakMinutes: newLong,
      totalPomodoroCycles: newCycles,
      autoStartBreaks: newAutoBreaks,
      autoStartFocus: newAutoFocus,
      pomodoroRemainingMs: newRemaining,
    );
  }

  Future<void> startStudy() async {
    _checkStudyDateReset();
    if (state.currentSubject == null && state.pomodoroPhase == PomodoroPhase.focus) return;
    final now = DateTime.now();

    if (state.isPaused && state.restStartAt != null && state.sessionRestMs > 0) {
      final rStart = state.restStartAt!;
      final rElapsed = state.sessionRestMs;
      _timerRepository.recordRest(
        startAt: rStart,
        stopAt: now,
        restMs: rElapsed,
      );
    }

    if (state.pomodoroPhase == PomodoroPhase.focus && state.currentSubject != null) {
      try {
        await _timerRepository.startStudy(
          subjectTitle: state.currentSubject!.title,
          subjectId: state.currentSubject!.id,
          startAt: now,
        );
      } catch (_) {}
    }

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      sessionStartAt: now,
      restStartAt: null,
      sessionRestMs: 0,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _handleTick();
    });
  }

  void _handleTick() {
    _checkStudyDateReset();

    if (state.isPaused) {
      final newRestMs = state.sessionRestMs + 1000;
      final newTodayRestMs = state.todayRestMs + 1000;
      state = state.copyWith(
        sessionRestMs: newRestMs,
        todayRestMs: newTodayRestMs,
      );
      return;
    }

    if (state.mode == TimerMode.stopwatch) {
      final newSessionMs = state.sessionElapsedMs + 1000;
      final newTodayMs = state.todayTotalMs + 1000;
      state = state.copyWith(
        sessionElapsedMs: newSessionMs,
        todayTotalMs: newTodayMs,
      );
    } else {
      if (state.pomodoroPhase == PomodoroPhase.focus) {
        final newSessionMs = state.sessionElapsedMs + 1000;
        final newTodayMs = state.todayTotalMs + 1000;
        final newRemaining = state.pomodoroRemainingMs - 1000;

        if (newRemaining <= 0) {
          _advancePomodoroPhase();
        } else {
          state = state.copyWith(
            sessionElapsedMs: newSessionMs,
            todayTotalMs: newTodayMs,
            pomodoroRemainingMs: newRemaining,
          );
        }
      } else {
        final newRestMs = state.sessionRestMs + 1000;
        final newTodayRestMs = state.todayRestMs + 1000;
        final newRemaining = state.pomodoroRemainingMs - 1000;
        if (newRemaining <= 0) {
          _advancePomodoroPhase();
        } else {
          state = state.copyWith(
            sessionRestMs: newRestMs,
            todayRestMs: newTodayRestMs,
            pomodoroRemainingMs: newRemaining,
          );
        }
      }
    }
  }

  Future<void> _advancePomodoroPhase() async {
    final now = DateTime.now();

    if (state.pomodoroPhase == PomodoroPhase.focus) {
      await _syncCompletedFocusSession();

      if (state.currentPomodoroCycle >= state.totalPomodoroCycles) {
        state = state.copyWith(
          pomodoroPhase: PomodoroPhase.longBreak,
          pomodoroRemainingMs: state.pomodoroLongBreakMinutes * 60 * 1000,
          currentPomodoroCycle: 1,
          isRunning: state.autoStartBreaks,
          isPaused: !state.autoStartBreaks,
          sessionElapsedMs: 0,
          lastSyncedSessionElapsedMs: 0,
          sessionStartAt: null,
          restStartAt: now,
          sessionRestMs: 0,
        );
      } else {
        state = state.copyWith(
          pomodoroPhase: PomodoroPhase.shortBreak,
          pomodoroRemainingMs: state.pomodoroShortBreakMinutes * 60 * 1000,
          currentPomodoroCycle: state.currentPomodoroCycle + 1,
          isRunning: state.autoStartBreaks,
          isPaused: !state.autoStartBreaks,
          sessionElapsedMs: 0,
          lastSyncedSessionElapsedMs: 0,
          sessionStartAt: null,
          restStartAt: now,
          sessionRestMs: 0,
        );
      }

      if (!state.autoStartBreaks) {
        _ticker?.cancel();
      }
    } else {
      if (state.restStartAt != null && state.sessionRestMs > 0) {
        _timerRepository.recordRest(
          startAt: state.restStartAt!,
          stopAt: now,
          restMs: state.sessionRestMs,
        );
      }

      if (state.autoStartFocus && state.currentSubject != null) {
        try {
          await _timerRepository.startStudy(
            subjectTitle: state.currentSubject!.title,
            subjectId: state.currentSubject!.id,
            startAt: now,
          );
        } catch (_) {}
      }

      state = state.copyWith(
        pomodoroPhase: PomodoroPhase.focus,
        pomodoroRemainingMs: state.pomodoroFocusMinutes * 60 * 1000,
        isRunning: state.autoStartFocus,
        isPaused: !state.autoStartFocus,
        sessionElapsedMs: 0,
        lastSyncedSessionElapsedMs: 0,
        sessionStartAt: state.autoStartFocus ? now : null,
        restStartAt: null,
        sessionRestMs: 0,
      );

      if (!state.autoStartFocus) {
        _ticker?.cancel();
      }
    }
  }

  Future<void> _syncCompletedFocusSession() async {
    int elapsed = state.sessionElapsedMs - state.lastSyncedSessionElapsedMs;
    final now = DateTime.now();
    if (elapsed <= 0 && state.sessionStartAt != null) {
      elapsed = now.difference(state.sessionStartAt!).inMilliseconds;
    }
    final currentSub = state.currentSubject;

    if (currentSub != null && (elapsed > 0 || state.isRunning)) {
      final safeElapsed = elapsed > 0 ? elapsed : 0;
      final startAt = state.sessionStartAt ?? now.subtract(Duration(milliseconds: safeElapsed));
      final stopAt = startAt.add(Duration(milliseconds: safeElapsed));
      try {
        final res = await _timerRepository.stopStudy(
          subjectTitle: currentSub.title,
          subjectId: currentSub.id,
          startAt: startAt,
          stopAt: stopAt,
          studyMs: safeElapsed,
        ).timeout(const Duration(seconds: 3), onTimeout: () => null);

        if (res != null) {
          final dl = res['dl'] as Map<String, dynamic>?;
          final serverTotalMs = safeInt(dl?['sm'] ?? dl?['tp']);
          final updatedSubjects = state.subjects.map((s) {
            if (s.id == currentSub.id) {
              return s.copyWith(studyMs: s.studyMs + safeElapsed);
            }
            return s;
          }).toList();

          state = state.copyWith(
            lastSyncedSessionElapsedMs: state.sessionElapsedMs,
            subjects: updatedSubjects,
            todayTotalMs: serverTotalMs > 0 ? serverTotalMs : state.todayTotalMs,
            currentSubject: currentSub.copyWith(studyMs: currentSub.studyMs + safeElapsed),
          );
        } else {
          state = state.copyWith(lastSyncedSessionElapsedMs: state.sessionElapsedMs);
          await _offlineSyncRepository?.enqueueSession(
            subjectId: currentSub.id,
            subjectTitle: currentSub.title,
            startAt: startAt,
            stopAt: stopAt,
            studyMs: safeElapsed,
          );
        }
      } catch (_) {
        state = state.copyWith(lastSyncedSessionElapsedMs: state.sessionElapsedMs);
        await _offlineSyncRepository?.enqueueSession(
          subjectId: currentSub.id,
          subjectTitle: currentSub.title,
          startAt: startAt,
          stopAt: stopAt,
          studyMs: safeElapsed,
        );
      }
    }
  }

  Future<void> skipPomodoroPhase() async {
    await _advancePomodoroPhase();
  }

  Future<void> pauseStudy() async {
    final now = DateTime.now();
    await _syncCompletedFocusSession();

    state = state.copyWith(
      isRunning: false,
      isPaused: true,
      sessionStartAt: null,
      restStartAt: now,
      sessionRestMs: 0,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _handleTick();
    });
  }

  Future<void> stopStudy() async {
    _ticker?.cancel();
    final now = DateTime.now();

    if (state.isPaused && state.restStartAt != null && state.sessionRestMs > 0) {
      try {
        await _timerRepository.recordRest(
          startAt: state.restStartAt!,
          stopAt: now,
          restMs: state.sessionRestMs,
        ).timeout(const Duration(seconds: 2), onTimeout: () => false);
      } catch (_) {}
    }

    if (state.isRunning ||
        state.sessionStartAt != null ||
        (state.sessionElapsedMs - state.lastSyncedSessionElapsedMs) > 0) {
      await _syncCompletedFocusSession();
    }

    int initialRemaining = state.pomodoroFocusMinutes * 60 * 1000;
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      sessionElapsedMs: 0,
      lastSyncedSessionElapsedMs: 0,
      sessionRestMs: 0,
      sessionStartAt: null,
      restStartAt: null,
      pomodoroPhase: PomodoroPhase.focus,
      pomodoroRemainingMs: initialRemaining,
    );
  }

  Future<bool> logManualStudy({
    required int subjectId,
    required String subjectTitle,
    required DateTime startAt,
    required DateTime stopAt,
  }) async {
    try {
      final res = await _timerRepository.logManualStudy(
        subjectId: subjectId,
        subjectTitle: subjectTitle,
        startAt: startAt,
        stopAt: stopAt,
      );

      if (res != null) {
        final elapsed = stopAt.difference(startAt).inMilliseconds;
        final dl = res['dl'] as Map<String, dynamic>?;
        final serverTotalMs = safeInt(dl?['sm'] ?? dl?['tp']);

        final updatedSubjects = state.subjects.map((s) {
          if (s.id == subjectId) {
            return s.copyWith(studyMs: s.studyMs + elapsed);
          }
          return s;
        }).toList();

        state = state.copyWith(
          subjects: updatedSubjects,
          todayTotalMs: serverTotalMs > 0 ? serverTotalMs : state.todayTotalMs + elapsed,
          currentSubject: state.currentSubject?.id == subjectId
              ? state.currentSubject!.copyWith(studyMs: state.currentSubject!.studyMs + elapsed)
              : state.currentSubject,
        );
        return true;
      }
    } catch (_) {
      await _offlineSyncRepository?.enqueueSession(
        subjectId: subjectId,
        subjectTitle: subjectTitle,
        startAt: startAt,
        stopAt: stopAt,
        studyMs: stopAt.difference(startAt).inMilliseconds,
      );
      return true;
    }
    return false;
  }

  Future<void> createSubject(String title, int colorInt) async {
    try {
      final newSubject = await _subjectRepository.createSubject(
        title: title,
        colorInt: colorInt,
      );
      final updatedList = [...state.subjects, newSubject];
      state = state.copyWith(
        subjects: updatedList,
        currentSubject: newSubject,
      );
    } catch (_) {
      final newSubject = SubjectModel(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        colorInt: colorInt,
      );
      final updatedList = [...state.subjects, newSubject];
      state = state.copyWith(
        subjects: updatedList,
        currentSubject: newSubject,
      );
    }
  }

  Future<void> deleteSubject(int subjectId) async {
    final updatedList = state.subjects.where((s) => s.id != subjectId).toList();
    final newCurrent = updatedList.isNotEmpty ? updatedList.first : null;

    state = state.copyWith(
      subjects: updatedList,
      currentSubject: state.currentSubject?.id == subjectId ? newCurrent : state.currentSubject,
    );

    try {
      await _subjectRepository.deleteSubject(subjectId);
    } catch (_) {}
  }

  Future<void> updateSubject(SubjectModel subject) async {
    final updatedList = state.subjects.map((s) => s.id == subject.id ? subject : s).toList();
    final newCurrent = state.currentSubject?.id == subject.id ? subject : state.currentSubject;

    state = state.copyWith(
      subjects: updatedList,
      currentSubject: newCurrent,
    );

    try {
      await _subjectRepository.updateSubject(subject);
    } catch (_) {}
  }

  Future<void> archiveSubject(int subjectId, bool isArchived) async {
    final updatedList = state.subjects.map((s) {
      if (s.id == subjectId) {
        return s.copyWith(isArchived: isArchived);
      }
      return s;
    }).toList();

    final activeList = updatedList.where((s) => !s.isArchived).toList();
    final newCurrent = (state.currentSubject?.id == subjectId && isArchived)
        ? (activeList.isNotEmpty ? activeList.first : null)
        : (state.currentSubject ?? (activeList.isNotEmpty ? activeList.first : null));

    state = state.copyWith(
      subjects: updatedList,
      currentSubject: newCurrent,
    );

    try {
      await _subjectRepository.archiveSubject(subjectId, isArchived);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dayResetTimer?.cancel();
    super.dispose();
  }
}

final timerNotifierProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  final timerRepo = ref.watch(timerRepositoryProvider);
  final subjectRepo = ref.watch(subjectRepositoryProvider);
  final offlineSyncRepo = ref.watch(offlineSyncRepositoryProvider);
  final user = ref.watch(authStateProvider).user;
  final dayResetHour = ref.watch(settingsNotifierProvider.select((s) => s.dayResetHour));

  final notifier = TimerNotifier(
    timerRepository: timerRepo,
    subjectRepository: subjectRepo,
    offlineSyncRepository: offlineSyncRepo,
    userStudiconId: user?.studiconId ?? -1,
    dayResetHour: dayResetHour,
  );

  ref.listen(settingsNotifierProvider.select((s) => s.dayResetHour), (prev, next) {
    if (next != prev) {
      notifier.setDayResetHour(next);
    }
  });

  return notifier;
});
