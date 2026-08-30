import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/timelapse_session_model.dart';
import '../../core/services/timelapse_service.dart';

final timelapseServiceProvider = Provider<TimelapseService>((ref) {
  return TimelapseService();
});

class TimelapseState {
  final List<TimelapseSession> sessions;
  final bool isRecording;
  final String? activeSessionId;
  final String? activeSubjectName;
  final int activeSubjectColor;
  final DateTime? sessionStartTime;
  final List<String> currentFrames;
  final bool isLoading;

  const TimelapseState({
    this.sessions = const [],
    this.isRecording = false,
    this.activeSessionId,
    this.activeSubjectName,
    this.activeSubjectColor = 4292557552,
    this.sessionStartTime,
    this.currentFrames = const [],
    this.isLoading = false,
  });

  TimelapseState copyWith({
    List<TimelapseSession>? sessions,
    bool? isRecording,
    String? activeSessionId,
    String? activeSubjectName,
    int? activeSubjectColor,
    DateTime? sessionStartTime,
    List<String>? currentFrames,
    bool? isLoading,
  }) {
    return TimelapseState(
      sessions: sessions ?? this.sessions,
      isRecording: isRecording ?? this.isRecording,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      activeSubjectName: activeSubjectName ?? this.activeSubjectName,
      activeSubjectColor: activeSubjectColor ?? this.activeSubjectColor,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      currentFrames: currentFrames ?? this.currentFrames,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TimelapseNotifier extends StateNotifier<TimelapseState> {
  final TimelapseService _service;

  TimelapseNotifier(this._service) : super(const TimelapseState()) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final list = await _service.getSessions();
      if (!mounted) return;
      state = state.copyWith(sessions: list, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  void startRecording({
    required String subjectName,
    required int subjectColorInt,
  }) {
    final sessionId = 'tl_${DateTime.now().millisecondsSinceEpoch}';
    state = state.copyWith(
      isRecording: true,
      activeSessionId: sessionId,
      activeSubjectName: subjectName,
      activeSubjectColor: subjectColorInt,
      sessionStartTime: DateTime.now(),
      currentFrames: [],
    );
  }

  Future<void> addFrame(Uint8List frameBytes) async {
    if (!state.isRecording || state.activeSessionId == null) return;
    final sessionId = state.activeSessionId!;
    final frameIndex = state.currentFrames.length;

    try {
      final savedPath = await _service.saveFrame(
        sessionId: sessionId,
        frameIndex: frameIndex,
        bytes: frameBytes,
      );
      state = state.copyWith(
        currentFrames: [...state.currentFrames, savedPath],
      );
    } catch (_) {}
  }

  Future<TimelapseSession?> stopRecording() async {
    if (!state.isRecording || state.activeSessionId == null) return null;

    final startTime = state.sessionStartTime ?? DateTime.now();
    final durationSeconds = DateTime.now().difference(startTime).inSeconds;

    final newSession = TimelapseSession(
      id: state.activeSessionId!,
      subjectName: state.activeSubjectName ?? 'Estudo',
      subjectColorInt: state.activeSubjectColor,
      startTime: startTime,
      durationSeconds: durationSeconds > 0 ? durationSeconds : 1,
      framePaths: state.currentFrames,
      thumbnailPath: state.currentFrames.isNotEmpty ? state.currentFrames.first : null,
    );

    if (state.currentFrames.isNotEmpty) {
      await _service.saveSession(newSession);
    }

    state = state.copyWith(
      isRecording: false,
      activeSessionId: null,
      activeSubjectName: null,
      sessionStartTime: null,
      currentFrames: [],
    );

    await loadSessions();
    return newSession;
  }

  Future<void> deleteSession(String sessionId) async {
    await _service.deleteSession(sessionId);
    await loadSessions();
  }
}

final timelapseNotifierProvider =
    StateNotifierProvider<TimelapseNotifier, TimelapseState>((ref) {
  final service = ref.watch(timelapseServiceProvider);
  return TimelapseNotifier(service);
});
