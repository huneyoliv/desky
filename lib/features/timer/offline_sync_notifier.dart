import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_translation.dart';
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
  final Ref? _ref;

  OfflineSyncNotifier({
    required OfflineSyncRepository repository,
    Ref? ref,
  })  : _repository = repository,
        _ref = ref,
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

    final t = _ref?.read(appTranslationProvider);
    String msg;
    if (result.totalSynced > 0 && result.totalFailed == 0) {
      msg = t != null
          ? t.tr('sessions_synced_success', args: [result.totalSynced.toString()], fallback: '${result.totalSynced} sessões sincronizadas com sucesso!')
          : '${result.totalSynced} sessões sincronizadas com sucesso!';
    } else if (result.totalFailed > 0) {
      msg = t != null
          ? t.tr('sessions_sync_failed', args: [result.totalSynced.toString(), result.totalFailed.toString()], fallback: '${result.totalSynced} sincronizadas, ${result.totalFailed} falharam.')
          : '${result.totalSynced} sincronizadas, ${result.totalFailed} falharam.';
    } else {
      msg = t != null
          ? t.tr('no_pending_sessions', fallback: 'Nenhuma sessão pendente.')
          : 'Nenhuma sessão pendente.';
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
  return OfflineSyncNotifier(repository: repo, ref: ref);
});
