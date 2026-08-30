import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offline_session_model.dart';
import 'timer_repository.dart';

class SyncResult {
  final int totalSynced;
  final int totalFailed;
  final int remaining;

  const SyncResult({
    required this.totalSynced,
    required this.totalFailed,
    required this.remaining,
  });
}

class OfflineSyncRepository {
  static const String _storageKey = 'desky_offline_study_sessions';
  final TimerRepository _timerRepository;
  final SharedPreferences? _prefs;

  OfflineSyncRepository({
    required TimerRepository timerRepository,
    SharedPreferences? prefs,
  })  : _timerRepository = timerRepository,
        _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<List<OfflineSessionModel>> getPendingSessions() async {
    try {
      final prefs = await _getPrefs();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      return rawList
          .map((item) => OfflineSessionModel.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueueSession({
    required int subjectId,
    required String subjectTitle,
    required DateTime startAt,
    required DateTime stopAt,
    required int studyMs,
  }) async {
    final prefs = await _getPrefs();
    final currentList = await getPendingSessions();

    final newSession = OfflineSessionModel(
      id: '${DateTime.now().millisecondsSinceEpoch}_$subjectId',
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      startAt: startAt,
      stopAt: stopAt,
      studyMs: studyMs,
      createdAt: DateTime.now(),
    );

    final updated = [...currentList, newSession];
    final stringList = updated.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_storageKey, stringList);
  }

  Future<void> removeSession(String id) async {
    final prefs = await _getPrefs();
    final currentList = await getPendingSessions();
    final updated = currentList.where((s) => s.id != id).toList();
    final stringList = updated.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_storageKey, stringList);
  }

  Future<SyncResult> syncAllPending() async {
    final pending = await getPendingSessions();
    if (pending.isEmpty) {
      return const SyncResult(totalSynced: 0, totalFailed: 0, remaining: 0);
    }

    int synced = 0;
    int failed = 0;
    final List<OfflineSessionModel> remainingList = [];

    for (final session in pending) {
      try {
        final res = await _timerRepository.stopStudy(
          subjectTitle: session.subjectTitle,
          subjectId: session.subjectId,
          startAt: session.startAt,
          stopAt: session.stopAt,
          studyMs: session.studyMs,
        );

        if (res != null) {
          synced++;
        } else {
          failed++;
          remainingList.add(session.copyWith(
            retryCount: session.retryCount + 1,
            lastError: 'Servidor rejeitou sessão',
          ));
        }
      } catch (e) {
        failed++;
        remainingList.add(session.copyWith(
          retryCount: session.retryCount + 1,
          lastError: e.toString(),
        ));
      }
    }

    final prefs = await _getPrefs();
    final stringList = remainingList.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_storageKey, stringList);

    return SyncResult(
      totalSynced: synced,
      totalFailed: failed,
      remaining: remainingList.length,
    );
  }

  Future<void> clearQueue() async {
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }
}
