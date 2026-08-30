import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/offline_session_model.dart';
import '../../data/repositories/offline_sync_repository.dart';
import '../../data/repositories/timer_repository.dart';

final offlineSyncRepositoryProvider = Provider<OfflineSyncRepository>((ref) {
  return OfflineSyncRepository(timerRepository: TimerRepository());
});

class OfflineSyncState {
  final List<OfflineSessionModel> pendingSessions;
  final bool isSyncing;
  final String? lastSyncMessage;

  const OfflineSyncState({
    this.pendingSessions = const [],
    this.isSyncing = false,
    this.lastSyncMessage,
  });

  int get pendingCount => pendingSessions.length;
  bool get hasPending => pendingSessions.isNotEmpty;

  OfflineSyncState copyWith({
    List<OfflineSessionModel>? pendingSessions,
    bool? isSyncing,
    String? lastSyncMessage,
  }) {
    return OfflineSyncState(
      pendingSessions: pendingSessions ?? this.pendingSessions,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncMessage: lastSyncMessage,
    );
  }
}

class OfflineSyncNotifier extends StateNotifier<OfflineSyncState> {
  final OfflineSyncRepository _repository;

  OfflineSyncNotifier({required OfflineSyncRepository repository})
      : _repository = repository,
        super(const OfflineSyncState()) {
    loadPending();
  }

  Future<void> loadPending() async {
    final pending = await _repository.getPendingSessions();
    state = state.copyWith(pendingSessions: pending);
  }

  Future<void> enqueueSession({
    required int subjectId,
    required String subjectTitle,
    required DateTime startAt,
    required DateTime stopAt,
    required int studyMs,
  }) async {
    await _repository.enqueueSession(
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      startAt: startAt,
      stopAt: stopAt,
      studyMs: studyMs,
    );
    await loadPending();
  }

  Future<SyncResult> syncNow() async {
    state = state.copyWith(isSyncing: true);
    final result = await _repository.syncAllPending();
    final pending = await _repository.getPendingSessions();

    String msg;
    if (result.totalSynced > 0 && result.totalFailed == 0) {
      msg = '${result.totalSynced} sessões sincronizadas com sucesso!';
    } else if (result.totalFailed > 0) {
      msg = '${result.totalSynced} sincronizadas, ${result.totalFailed} falharam.';
    } else {
      msg = 'Nenhuma sessão pendente.';
    }

    state = state.copyWith(
      pendingSessions: pending,
      isSyncing: false,
      lastSyncMessage: msg,
    );

    return result;
  }
}

final offlineSyncNotifierProvider =
    StateNotifierProvider<OfflineSyncNotifier, OfflineSyncState>((ref) {
  final repo = ref.watch(offlineSyncRepositoryProvider);
  return OfflineSyncNotifier(repository: repo);
});
