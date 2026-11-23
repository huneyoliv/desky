import 'dart:async';
import 'dart:convert';

import 'package:desky/data/repositories/offline_sync_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every submission and lets the test decide when (and how) each one
/// resolves. Each call also records the account signed in at send time.
class _ControlledTimerRepository extends Fake implements TimerRepository {
  _ControlledTimerRepository(this.signedIn);

  final int? Function() signedIn;
  final List<({int subjectId, int studyMs, int? sentAs})> sent = [];
  final List<Completer<Map<String, dynamic>?>> pending = [];

  /// When false, submissions resolve immediately with [autoResult].
  bool hold = false;
  Map<String, dynamic>? autoResult = const {'s': true};

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) {
    sent.add((subjectId: subjectId, studyMs: studyMs, sentAs: signedIn()));
    if (!hold) return Future.value(autoResult);
    final c = Completer<Map<String, dynamic>?>();
    pending.add(c);
    return c.future;
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  const accountA = 101;
  const accountB = 202;

  late SharedPreferences prefs;
  late _ControlledTimerRepository server;
  late OfflineSyncRepository queue;
  int? signedIn;

  Future<void> enqueue(int subjectId, {int studyMs = 60000}) {
    return queue.enqueueSession(
      subjectId: subjectId,
      subjectTitle: 'S$subjectId',
      startAt: DateTime(2026, 11, 1, 10),
      stopAt: DateTime(2026, 11, 1, 11),
      studyMs: studyMs,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    signedIn = accountA;
    server = _ControlledTimerRepository(() => signedIn);
    queue = OfflineSyncRepository(
      timerRepository: server,
      prefs: prefs,
      currentOwner: () => signedIn,
    );
  });

  group('account ownership (F01)', () {
    test('A queues, sync is held, A logs out, B signs in: nothing of A is sent or changed under B',
        () async {
      await enqueue(1);
      await enqueue(2);

      server.hold = true;
      final sync = queue.syncAllPending();
      await _settle();
      expect(server.sent, hasLength(1), reason: 'first A entry is in flight');

      // A logs out, B signs in while the first request is outstanding.
      signedIn = null;
      signedIn = accountB;

      // A's in-flight request fails: A's entry must not be touched under B.
      server.pending.single.complete(null);
      final result = await sync;

      expect(server.sent, hasLength(1), reason: 'the second A entry is never sent');
      expect(server.sent.single.sentAs, accountA);
      expect(result.totalSynced, 0);

      // B sees none of A's entries and a B sync sends nothing.
      expect(await queue.getPendingSessions(), isEmpty);
      server.hold = false;
      final bSync = await queue.syncAllPending();
      expect(bSync.totalSynced + bSync.totalFailed, 0);
      expect(server.sent, hasLength(1));

      // Back as A: both entries are still there, unmodified.
      signedIn = accountA;
      final aPending = await queue.getPendingSessions();
      expect(aPending.map((s) => s.subjectId), [1, 2]);
      expect(aPending.every((s) => s.retryCount == 0 && s.lastError == null), isTrue);
    });

    test('switching account before the first request means zero requests', () async {
      await enqueue(1);
      final sync = queue.syncAllPending();
      signedIn = accountB; // synchronously, before the sync reaches the network
      await sync;
      expect(server.sent, isEmpty);
      signedIn = accountA;
      expect(await queue.getPendingSessions(), hasLength(1));
    });

    test('an entry accepted by the server after the switch is removed, not resent later', () async {
      await enqueue(1);
      server.hold = true;
      final sync = queue.syncAllPending();
      await _settle();
      signedIn = accountB;
      server.pending.single.complete(const {'s': true});
      await sync;

      signedIn = accountA;
      expect(await queue.getPendingSessions(), isEmpty);
    });

    test('each account only syncs its own entries', () async {
      await enqueue(1); // A
      signedIn = accountB;
      await enqueue(2); // B

      final result = await queue.syncAllPending();
      expect(result.totalSynced, 1);
      expect(server.sent.single.subjectId, 2);
      expect(server.sent.single.sentAs, accountB);

      signedIn = accountA;
      final aPending = await queue.getPendingSessions();
      expect(aPending.single.subjectId, 1);
    });

    test('nobody signed in: nothing is sent', () async {
      await enqueue(1);
      signedIn = null;
      final result = await queue.syncAllPending();
      expect(result.totalSynced + result.totalFailed, 0);
      expect(server.sent, isEmpty);
    });

    test('entries without an owner (written before this change) are never sent', () async {
      final legacy = {
        'id': 'legacy_1',
        'subjectId': 9,
        'subjectTitle': 'Old',
        'startAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'stopAt': DateTime(2026, 1, 1, 1).millisecondsSinceEpoch,
        'studyMs': 3600000,
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      };
      await prefs.setStringList('desky_offline_study_sessions', [jsonEncode(legacy)]);

      expect(await queue.getPendingSessions(), isEmpty);
      await queue.syncAllPending();
      expect(server.sent, isEmpty);
      // Kept on disk, not deleted.
      expect(prefs.getStringList('desky_offline_study_sessions'), hasLength(1));
    });

    test('clearQueue only clears the signed-in account', () async {
      await enqueue(1);
      signedIn = accountB;
      await enqueue(2);
      await queue.clearQueue();
      expect(await queue.getPendingSessions(), isEmpty);
      signedIn = accountA;
      expect((await queue.getPendingSessions()).single.subjectId, 1);
    });
  });

  group('serialization (F02)', () {
    test('enqueue while a sync is in flight: the new entry stays pending', () async {
      await enqueue(1);
      server.hold = true;
      final sync = queue.syncAllPending();
      await _settle();
      expect(server.sent, hasLength(1));

      await enqueue(2); // queued while entry 1 is in flight
      server.pending.single.complete(const {'s': true});
      final result = await sync;

      expect(result.totalSynced, 1);
      final left = await queue.getPendingSessions();
      expect(left.map((s) => s.subjectId), [2], reason: 'B was neither dropped nor duplicated');
      expect(left.single.retryCount, 0);
    });

    test('enqueue while a failing sync is in flight keeps both, retry only on the sent one', () async {
      await enqueue(1);
      server.hold = true;
      final sync = queue.syncAllPending();
      await _settle();
      await enqueue(2);
      server.pending.single.complete(null);
      await sync;

      final left = await queue.getPendingSessions();
      expect(left.map((s) => s.subjectId), [1, 2]);
      expect(left[0].retryCount, 1);
      expect(left[1].retryCount, 0);
    });

    test('concurrent syncs share one run: one submission per entry', () async {
      await enqueue(1);
      await enqueue(2);
      server.hold = true;

      final first = queue.syncAllPending();
      final second = queue.syncAllPending();
      expect(identical(first, second), isTrue);
      expect(queue.isSyncing, isTrue);

      for (var i = 0; i < 2; i++) {
        await _settle();
        server.pending[i].complete(const {'s': true});
      }
      await Future.wait([first, second]);

      expect(server.sent.map((s) => s.subjectId), [1, 2]);
      expect(queue.isSyncing, isFalse);
      expect(await queue.getPendingSessions(), isEmpty);
    });

    test('parallel enqueues are all kept with distinct ids', () async {
      await Future.wait([for (var i = 0; i < 20; i++) enqueue(7, studyMs: i)]);
      final all = await queue.getPendingSessions();
      expect(all, hasLength(20));
      expect(all.map((s) => s.id).toSet(), hasLength(20));
      expect(all.map((s) => s.studyMs).toSet(), hasLength(20));

      await queue.removeSession(all.first.id);
      expect(await queue.getPendingSessions(), hasLength(19));
    });
  });
}
