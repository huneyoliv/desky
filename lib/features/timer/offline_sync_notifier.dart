import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/offline_session_model.dart';
import '../../data/repositories/offline_sync_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../settings/settings_notifier.dart';
import 'timer_notifier.dart';

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
          ? t.tr('no_pending_sessions', fallback: trMsg('sync_no_pending', fallback: 'Nenhuma sessão pendente.'))
          : trMsg('sync_no_pending', fallback: 'Nenhuma sessão pendente.');
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

/// Sends queued sessions without the user having to press "Sync":
/// every 2 minutes while some are waiting, right after Offline mode is turned
/// off, and when the app comes back to the foreground. Also refreshes the
/// waiting count after a session stops or pauses (that is when the timer may
/// have queued one). Does nothing while Offline mode is on.
class OfflineAutoSync {
  OfflineAutoSync(this._ref) {
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => trigger());
    _ref.listen<bool>(settingsNotifierProvider.select((s) => s.offlineMode), (prev, next) {
      if (prev == true && next == false) trigger();
    });
    _ref.listen<bool>(timerNotifierProvider.select((s) => s.isRunning), (prev, next) {
      if (prev == true && next == false) {
        // The stop path queues after its server attempt (up to ~3 s).
        Future.delayed(const Duration(seconds: 4), _reload);
      }
    });
    Future.microtask(trigger);
  }

  final Ref _ref;
  Timer? _timer;
  bool _running = false;

  Future<void> _reload() async {
    try {
      await _ref.read(offlineSyncNotifierProvider.notifier).loadPending();
    } catch (_) {}
  }

  Future<void> trigger() async {
    if (_running) return;
    _running = true;
    try {
      await _reload();
      if (_ref.read(settingsNotifierProvider).offlineMode) return;
      final notifier = _ref.read(offlineSyncNotifierProvider.notifier);
      if (!_ref.read(offlineSyncNotifierProvider).hasPending) return;
      if (_ref.read(offlineSyncNotifierProvider).isSyncing) return;
      await notifier.syncNow();
    } catch (_) {
    } finally {
      _running = false;
    }
  }

  void dispose() => _timer?.cancel();
}

final offlineAutoSyncProvider = Provider<OfflineAutoSync>((ref) {
  final sync = OfflineAutoSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});
