import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/study_date_helper.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../data/repositories/offline_sync_repository.dart';
import '../auth/auth_notifier.dart';
import '../settings/settings_notifier.dart';
import '../../core/localization/app_translation.dart';
import 'offline_sync_notifier.dart';
import 'timer_session_store.dart';

enum TimerMode {
  stopwatch,
  pomodoro,
}

enum PomodoroPhase {
  focus,
  shortBreak,
  longBreak,
}


final timerRepositoryProvider = Provider<TimerRepository>((ref) {
  return TimerRepository();
});

final timerSessionStoreProvider = Provider<TimerSessionStore>((ref) {
  return TimerSessionStore();
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
  final TimerSessionStore _sessionStore;
  final String? _initialSubjectTitle;
  Timer? _ticker;
  Timer? _dayResetTimer;
  Timer? _reconcileTimer;
  int _dayResetHour;
  int _accumulatedSessionMs = 0;
  int _accumulatedRestMs = 0;
  int _segmentStartRemainingMs = 0;
  bool _reconciling = false;
  String _language;
  String _timezone;

  /// Completes once the persisted session (if any) has been restored and the
  /// first server reconciliation finished.
  late final Future<void> ready;

  TimerNotifier({
    required TimerRepository timerRepository,
    required SubjectRepository subjectRepository,
    OfflineSyncRepository? offlineSyncRepository,
    TimerSessionStore? sessionStore,
    int userStudiconId = -1,
    int dayResetHour = 5,
    String? initialSubjectTitle,
    String language = 'pt',
    String timezone = 'America/Sao_Paulo',
  })  : _timerRepository = timerRepository,
        _subjectRepository = subjectRepository,
        _offlineSyncRepository = offlineSyncRepository,
        _sessionStore = sessionStore ?? TimerSessionStore(),
        _dayResetHour = dayResetHour,
        _initialSubjectTitle = initialSubjectTitle,
        _language = language,
        _timezone = timezone,
        super(TimerState(
          studiconId: userStudiconId,
          lastStudyDate: StudyDateHelper.getStudyDateString(null, dayResetHour),
        )) {
    loadSubjects();
    _dayResetTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStudyDateReset();
    });
    ready = _bootstrap();
  }

  Future<void> _bootstrap() async {
    final snapshot = await _sessionStore.load();
    if (!mounted) return;
    if (snapshot != null) {
      _restoreFromSnapshot(snapshot);
    }
    await reconcileWithServer();
    if (!mounted) return;
    if (state.isRunning) _ensureReconcileTimer();
  }

  void _ensureReconcileTimer() {
    _reconcileTimer ??= Timer.periodic(const Duration(seconds: 60), (_) {
      reconcileWithServer();
    });
  }

  void _cancelReconcileTimer() {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
  }

  void _restoreFromSnapshot(TimerSessionSnapshot snapshot) {
    final startAt = snapshot.startAt.toLocal();
    final elapsed = DateTime.now().difference(startAt).inMilliseconds;
    final subject = _findSubject(snapshot.subjectId, snapshot.subjectTitle);

    _accumulatedSessionMs = 0;
    _accumulatedRestMs = 0;
    _segmentStartRemainingMs = state.pomodoroRemainingMs;

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      mode: TimerMode.stopwatch,
      sessionStartAt: startAt,
      sessionElapsedMs: elapsed > 0 ? elapsed : 0,
      todayTotalMs: state.todayTotalMs > elapsed ? state.todayTotalMs : elapsed,
      currentSubject: subject ?? state.currentSubject,
    );
    _startTicker();
    debugPrint('[timer] restored local session started at ${snapshot.startAt.toIso8601String()}');
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _handleTick();
    });
    _ensureReconcileTimer();
  }

  SubjectModel? _findSubject(int id, String title) {
    for (final subject in state.subjects) {
      if (subject.id == id) return subject;
    }
    for (final subject in state.subjects) {
      if (subject.title == title) return subject;
    }
    return null;
  }

  /// Reconciles the local timer with the session YPT has open on the server.
  ///
  /// The daily log exposes `dl.is`; when the payload does not carry that flag
  /// the local state is left untouched instead of guessing.
  Future<void> reconcileWithServer() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      final log = await _timerRepository.fetchDailyLog(DateTime.now());
      if (!mounted) return;
      final dl = log?['dl'];
      if (dl is! Map) return;

      final isStudying = dl['is'];
      if (isStudying is! bool) return;

      if (isStudying && !state.isRunning) {
        await _adoptServerSession(Map<String, dynamic>.from(dl));
      } else if (!isStudying && state.isRunning) {
        await _stopFromServer();
      }
    } catch (_) {
    } finally {
      _reconciling = false;
    }
  }

  Future<void> _adoptServerSession(Map<String, dynamic> dl) async {
    final startAt = _parseServerInstant(dl['st']) ?? DateTime.now();
    final subject = _findSubject(-1, _lastSessionSubject(dl)) ?? state.currentSubject;
    final elapsed = DateTime.now().difference(startAt).inMilliseconds;

    _accumulatedSessionMs = 0;
    _accumulatedRestMs = 0;
    _segmentStartRemainingMs = state.pomodoroRemainingMs;

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      mode: TimerMode.stopwatch,
      sessionStartAt: startAt,
      sessionElapsedMs: elapsed > 0 ? elapsed : 0,
      todayTotalMs: elapsed > state.todayTotalMs ? elapsed : state.todayTotalMs,
      currentSubject: subject ?? state.currentSubject,
    );
    _startTicker();
    await _saveSnapshot();
    debugPrint('[timer] adopted active ypt session started at ${startAt.toIso8601String()}');
  }

  Future<void> _stopFromServer() async {
    _ticker?.cancel();
    _cancelReconcileTimer();
    _accumulatedSessionMs = 0;
    _accumulatedRestMs = 0;
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      sessionStartAt: null,
      restStartAt: null,
      sessionElapsedMs: 0,
      lastSyncedSessionElapsedMs: 0,
      sessionRestMs: 0,
    );
    await _sessionStore.clear();
    debugPrint('[timer] ypt reports no active session; local timer cleared');
  }

  DateTime? _parseServerInstant(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim())?.toLocal();
  }

  String _lastSessionSubject(Map<String, dynamic> dl) {
    final sessions = dl['ls'];
    if (sessions is List && sessions.isNotEmpty) {
      final last = sessions.last;
      if (last is Map && last['sb'] is String) return last['sb'] as String;
    }
    final single = dl['sb'];
    return single is String ? single : '';
  }

  Future<void> _saveSnapshot() async {
    if (!mounted) return;
    final subject = state.currentSubject;
    final startAt = state.sessionStartAt;
    if (subject == null || startAt == null || !state.isRunning) return;
    await _sessionStore.save(TimerSessionSnapshot(
      subjectId: subject.id,
      subjectTitle: subject.title,
      startAt: startAt.toUtc(),
    ));
  }

  void setLocale({String? language, String? timezone}) {
    final nextLanguage = language ?? _language;
    final nextTimezone = timezone ?? _timezone;
    if (nextLanguage == _language && nextTimezone == _timezone) return;
    _language = nextLanguage;
    _timezone = nextTimezone;
    loadSubjects();
  }

  void updateStudiconId(int newStudiconId) {
    if (state.studiconId != newStudiconId) {
      state = state.copyWith(studiconId: newStudiconId);
    }
  }

  void handleLogout() {
    _ticker?.cancel();
    _cancelReconcileTimer();
    _accumulatedSessionMs = 0;
    _accumulatedRestMs = 0;
    _segmentStartRemainingMs = 0;
    _sessionStore.clear();
    state = TimerState(
      studiconId: -1,
      lastStudyDate: StudyDateHelper.getStudyDateString(null, _dayResetHour),
    );
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
      final result = await _subjectRepository.fetchSubjectsData(
        language: _language,
        timezone: _timezone,
      );
      if (!mounted) return;
      final subjects = result.subjects.isNotEmpty ? result.subjects : state.subjects;
      final current = subjects.isNotEmpty
          ? (state.currentSubject != null && subjects.any((s) => s.id == state.currentSubject!.id)
              ? subjects.firstWhere((s) => s.id == state.currentSubject!.id)
              : subjects.first)
          : null;

      final effectiveTodayTotal = state.isRunning
          ? (state.todayTotalMs > result.todayTotalMs ? state.todayTotalMs : result.todayTotalMs)
          : result.todayTotalMs;

      state = state.copyWith(
        subjects: subjects,
        currentSubject: (state.isRunning && state.currentSubject != null) ? state.currentSubject : current,
        todayTotalMs: effectiveTodayTotal,
        todayRestMs: (state.isRunning && state.isPaused) ? state.todayRestMs : result.todayRestMs,
        lastStudyDate: StudyDateHelper.getStudyDateString(null, _dayResetHour),
      );
    } catch (_) {
      if (!mounted) return;
      if (state.subjects.isEmpty) {
        final fallbackSubject = SubjectModel(
          id: 1,
          title: _initialSubjectTitle ?? 'Matéria Inicial',
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

    _accumulatedSessionMs = state.sessionElapsedMs;
    _accumulatedRestMs = 0;
    _segmentStartRemainingMs = state.pomodoroRemainingMs;

    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      sessionStartAt: now,
      restStartAt: null,
      sessionRestMs: 0,
    );

    _ticker?.cancel();
    _startTicker();
    await _saveSnapshot();
  }

  void _handleTick() {
    _checkStudyDateReset();
    final now = DateTime.now();

    if (state.isPaused) {
      if (state.restStartAt != null) {
        final elapsedRest = now.difference(state.restStartAt!).inMilliseconds;
        final newRestMs = _accumulatedRestMs + elapsedRest;
        final delta = newRestMs - state.sessionRestMs;
        state = state.copyWith(
          sessionRestMs: newRestMs,
          todayRestMs: state.todayRestMs + (delta > 0 ? delta : 0),
        );
      } else {
        final newRestMs = state.sessionRestMs + 1000;
        final newTodayRestMs = state.todayRestMs + 1000;
        state = state.copyWith(
          sessionRestMs: newRestMs,
          todayRestMs: newTodayRestMs,
        );
      }
      return;
    }

    if (state.mode == TimerMode.stopwatch) {
      if (state.sessionStartAt != null) {
        final elapsedInSegment = now.difference(state.sessionStartAt!).inMilliseconds;
        final newSessionMs = _accumulatedSessionMs + elapsedInSegment;
        final delta = newSessionMs - state.sessionElapsedMs;
        state = state.copyWith(
          sessionElapsedMs: newSessionMs,
          todayTotalMs: state.todayTotalMs + (delta > 0 ? delta : 0),
        );
      } else {
        final newSessionMs = state.sessionElapsedMs + 1000;
        final newTodayMs = state.todayTotalMs + 1000;
        state = state.copyWith(
          sessionElapsedMs: newSessionMs,
          todayTotalMs: newTodayMs,
        );
      }
    } else {
      if (state.pomodoroPhase == PomodoroPhase.focus) {
        int delta = 1000;
        int newSessionMs = state.sessionElapsedMs + 1000;
        int newRemaining = state.pomodoroRemainingMs - 1000;

        if (state.sessionStartAt != null) {
          final elapsedInSegment = now.difference(state.sessionStartAt!).inMilliseconds;
          newSessionMs = _accumulatedSessionMs + elapsedInSegment;
          delta = newSessionMs - state.sessionElapsedMs;
          newRemaining = _segmentStartRemainingMs - elapsedInSegment;
        }

        if (newRemaining <= 0) {
          _advancePomodoroPhase();
        } else {
          state = state.copyWith(
            sessionElapsedMs: newSessionMs,
            todayTotalMs: state.todayTotalMs + (delta > 0 ? delta : 0),
            pomodoroRemainingMs: newRemaining,
          );
        }
      } else {
        int delta = 1000;
        int newRestMs = state.sessionRestMs + 1000;
        int newRemaining = state.pomodoroRemainingMs - 1000;

        if (state.restStartAt != null) {
          final elapsedRest = now.difference(state.restStartAt!).inMilliseconds;
          newRestMs = _accumulatedRestMs + elapsedRest;
          delta = newRestMs - state.sessionRestMs;
          newRemaining = _segmentStartRemainingMs - elapsedRest;
        }

        if (newRemaining <= 0) {
          _advancePomodoroPhase();
        } else {
          state = state.copyWith(
            sessionRestMs: newRestMs,
            todayRestMs: state.todayRestMs + (delta > 0 ? delta : 0),
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

      final isLongBreak = state.currentPomodoroCycle >= state.totalPomodoroCycles;
      final breakMinutes = isLongBreak
          ? state.pomodoroLongBreakMinutes
          : state.pomodoroShortBreakMinutes;
      final targetBreakRemaining = breakMinutes * 60 * 1000;

      _accumulatedSessionMs = 0;
      _accumulatedRestMs = 0;
      _segmentStartRemainingMs = targetBreakRemaining;

      if (isLongBreak) {
        state = state.copyWith(
          pomodoroPhase: PomodoroPhase.longBreak,
          pomodoroRemainingMs: targetBreakRemaining,
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
          pomodoroRemainingMs: targetBreakRemaining,
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

      final focusTargetRemaining = state.pomodoroFocusMinutes * 60 * 1000;
      _accumulatedSessionMs = 0;
      _accumulatedRestMs = 0;
      _segmentStartRemainingMs = focusTargetRemaining;

      state = state.copyWith(
        pomodoroPhase: PomodoroPhase.focus,
        pomodoroRemainingMs: focusTargetRemaining,
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

    if (state.isRunning) {
      await _saveSnapshot();
    } else {
      await _sessionStore.clear();
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

    _accumulatedRestMs = 0;
    _accumulatedSessionMs = state.sessionElapsedMs;

    state = state.copyWith(
      isRunning: false,
      isPaused: true,
      sessionStartAt: null,
      restStartAt: now,
      sessionRestMs: 0,
    );

    _ticker?.cancel();
    _cancelReconcileTimer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _handleTick();
    });
    await _sessionStore.clear();
  }

  Future<void> stopStudy() async {
    _ticker?.cancel();
    _cancelReconcileTimer();
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
        (state.sessionStartAt != null && !state.isPaused) ||
        (state.sessionElapsedMs - state.lastSyncedSessionElapsedMs) > 0) {
      await _syncCompletedFocusSession();
    }

    _accumulatedSessionMs = 0;
    _accumulatedRestMs = 0;
    _segmentStartRemainingMs = 0;

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
    await _sessionStore.clear();
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
    _reconcileTimer?.cancel();
    super.dispose();
  }
}

final timerNotifierProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  final timerRepo = ref.watch(timerRepositoryProvider);
  final subjectRepo = ref.watch(subjectRepositoryProvider);
  final offlineSyncRepo = ref.watch(offlineSyncRepositoryProvider);
  final sessionStore = ref.watch(timerSessionStoreProvider);
  final initialUser = ref.read(authStateProvider).user;
  final settings = ref.read(settingsNotifierProvider);
  final dayResetHour = settings.dayResetHour;
  final initialTranslation = ref.read(appTranslationProvider);

  final notifier = TimerNotifier(
    timerRepository: timerRepo,
    subjectRepository: subjectRepo,
    offlineSyncRepository: offlineSyncRepo,
    sessionStore: sessionStore,
    userStudiconId: initialUser?.studiconId ?? -1,
    dayResetHour: dayResetHour,
    initialSubjectTitle: initialTranslation.tr('initial_subject', fallback: 'Matéria Inicial'),
    language: settings.selectedLanguage,
    timezone: settings.selectedCountry.timezone,
  );

  // Daily logs are resolved with the country timezone, so keep it in sync when
  // the user changes region without recreating the running timer.
  ref.listen(settingsNotifierProvider, (prev, next) {
    if (prev?.selectedLanguage != next.selectedLanguage ||
        prev?.selectedCountry != next.selectedCountry) {
      notifier.setLocale(
        language: next.selectedLanguage,
        timezone: next.selectedCountry.timezone,
      );
    }
  });

  // Dynamically update day reset hour without disposing TimerNotifier
  ref.listen<int>(settingsNotifierProvider.select((s) => s.dayResetHour), (prev, next) {
    if (next != prev) {
      notifier.setDayResetHour(next);
    }
  });

  // Dynamically update studicon when user equips/changes avatar without resetting running timer
  ref.listen<int?>(authStateProvider.select((s) => s.user?.studiconId), (prev, next) {
    if (next != null && next != prev) {
      notifier.updateStudiconId(next);
    }
  });

  // Cleanly handle user logout
  ref.listen<bool>(authStateProvider.select((s) => s.isAuthenticated), (prev, next) {
    if (prev == true && next == false) {
      notifier.handleLogout();
    }
  });

  return notifier;
});
