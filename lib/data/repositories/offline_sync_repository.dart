import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offline_session_model.dart';
import 'timer_repository.dart';
import '../../core/localization/app_translation.dart';

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

/// Returns the id of the signed-in account, or null when nobody is signed in.
typedef OfflineOwnerResolver = int? Function();

/// Study sessions the server did not accept yet, kept on this device until
/// they can be submitted.
///
/// Two rules keep the queue safe:
///
/// * **Account-owned.** When an [OfflineOwnerResolver] is given, every entry
///   records the account that created it. Reads, submissions and changes only
///   touch entries of the account signed in at that moment, and the owner is
///   checked again right before each request, so signing out of A and into B
///   mid-sync never sends A's sessions with B's token.
/// * **Serialized.** Every write to storage is a read-modify-write done under
///   one lock, and a sync never rewrites the whole list from a snapshot: it
///   removes or updates only the entry it just submitted. A session queued
///   while a sync is running stays pending. Concurrent [syncAllPending] calls
///   share the sync already running, so an entry is never in flight twice.
class OfflineSyncRepository {
  static const String _storageKey = 'desky_offline_study_sessions';
  final TimerRepository _timerRepository;
  final SharedPreferences? _prefs;
  final OfflineOwnerResolver? _currentOwner;

  Future<void> _lock = Future.value();
  Future<SyncResult>? _syncInFlight;
  int _idCounter = 0;

  OfflineSyncRepository({
    required TimerRepository timerRepository,
    SharedPreferences? prefs,
    OfflineOwnerResolver? currentOwner,
  })  : _timerRepository = timerRepository,
        _prefs = prefs,
        _currentOwner = currentOwner;

  /// True while a sync is running.
  bool get isSyncing => _syncInFlight != null;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Without a resolver (tests, single-account use) every entry is visible,
  /// as before entries had an owner.
  bool get _ownerScoped => _currentOwner != null;

  int? _owner() => _currentOwner?.call();

  bool _belongsTo(OfflineSessionModel s, int? owner) {
    if (!_ownerScoped) return true;
    return owner != null && s.ownerId == owner;
  }

  /// Runs [op] alone: no other queue write can interleave with it.
  Future<T> _locked<T>(Future<T> Function() op) {
    final result = _lock.then((_) => op());
    _lock = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<List<OfflineSessionModel>> _readAll() async {
    try {
      final prefs = await _getPrefs();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final out = <OfflineSessionModel>[];
      for (final item in rawList) {
        try {
          out.add(OfflineSessionModel.fromJson(jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {
          // One corrupt entry must not hide the others.
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<OfflineSessionModel> sessions) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(
      _storageKey,
      sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  /// Pending sessions of the signed-in account.
  Future<List<OfflineSessionModel>> getPendingSessions() async {
    final owner = _owner();
    final all = await _readAll();
    return all.where((s) => _belongsTo(s, owner)).toList();
  }

  Future<void> enqueueSession({
    required int subjectId,
    required String subjectTitle,
    required DateTime startAt,
    required DateTime stopAt,
    required int studyMs,
  }) {
    // The owner is captured now, not when the lock frees up: the session
    // belongs to whoever was signed in when it was recorded.
    final owner = _owner();
    final now = DateTime.now();
    final newSession = OfflineSessionModel(
      id: '${now.microsecondsSinceEpoch}_${_idCounter++}_$subjectId',
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      startAt: startAt,
      stopAt: stopAt,
      studyMs: studyMs,
      createdAt: now,
      ownerId: owner,
    );
    return _locked(() async {
      final current = await _readAll();
      await _writeAll([...current, newSession]);
    });
  }

  Future<void> removeSession(String id) {
    final owner = _owner();
    return _locked(() async {
      final current = await _readAll();
      await _writeAll(
        current.where((s) => !(s.id == id && _belongsTo(s, owner))).toList(),
      );
    });
  }

  /// Submits the signed-in account's pending sessions, one at a time.
  ///
  /// A call made while a sync is running returns that sync's result instead
  /// of starting a second one.
  Future<SyncResult> syncAllPending() {
    final running = _syncInFlight;
    if (running != null) return running;
    final sync = _runSync().whenComplete(() => _syncInFlight = null);
    _syncInFlight = sync;
    return sync;
  }

  Future<SyncResult> _runSync() async {
    final owner = _owner();
    if (_ownerScoped && owner == null) {
      return const SyncResult(totalSynced: 0, totalFailed: 0, remaining: 0);
    }

    // Snapshot under the lock so a half-written enqueue is never read.
    final snapshot = await _locked(() async {
      final all = await _readAll();
      return all.where((s) => _belongsTo(s, owner)).toList();
    });

    int synced = 0;
    int failed = 0;

    for (final session in snapshot) {
      // Signed out, or another account signed in, since the sync began:
      // stop here and leave the rest untouched for their owner.
      if (_ownerScoped && _owner() != owner) break;

      bool accepted;
      String? error;
      try {
        final res = await _timerRepository.stopStudy(
          subjectTitle: session.subjectTitle,
          subjectId: session.subjectId,
          startAt: session.startAt,
          stopAt: session.stopAt,
          studyMs: session.studyMs,
        );
        accepted = res != null;
        if (!accepted) {
          error = trMsg('sync_server_rejected', fallback: 'Servidor rejeitou sessão');
        }
      } catch (e) {
        accepted = false;
        error = e.toString();
      }

      final ownerStillCurrent = !_ownerScoped || _owner() == owner;
      await _locked(() async {
        final current = await _readAll();
        if (accepted) {
          // The server has it: drop it even if the account changed meanwhile,
          // or its owner would submit it a second time later.
          await _writeAll(current.where((s) => s.id != session.id).toList());
        } else if (ownerStillCurrent) {
          await _writeAll(current
              .map((s) => s.id == session.id
                  ? s.copyWith(retryCount: s.retryCount + 1, lastError: error)
                  : s)
              .toList());
        }
        // Rejected after the account changed: leave the entry as it was.
      });
      if (accepted) {
        synced++;
      } else {
        failed++;
      }
    }

    final remaining = (await getPendingSessions()).length;
    return SyncResult(
      totalSynced: synced,
      totalFailed: failed,
      remaining: remaining,
    );
  }

  /// Removes the signed-in account's pending sessions (every session when the
  /// queue is not owner-scoped). Other accounts' sessions are kept.
  Future<void> clearQueue() {
    final owner = _owner();
    return _locked(() async {
      if (!_ownerScoped) {
        final prefs = await _getPrefs();
        await prefs.remove(_storageKey);
        return;
      }
      final current = await _readAll();
      await _writeAll(current.where((s) => !_belongsTo(s, owner)).toList());
    });
  }
}
