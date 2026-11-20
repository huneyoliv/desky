import 'dart:async';

import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/offline_sync_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Timer extends TimerRepository {
  int starts = 0, stops = 0, logs = 0;
  Completer<bool>? hangStart;

  @override
  Future<bool> startStudy({required String subjectTitle, required int subjectId, required DateTime startAt}) {
    starts++;
    return hangStart?.future ?? Future.value(true);
  }

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async {
    stops++;
    return {'s': true};
  }

  @override
  Future<Map<String, dynamic>?> fetchDailyLog(DateTime date) async {
    logs++;
    return null;
  }
}

class _Subjects extends SubjectRepository {
  int fetches = 0;
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async {
    fetches++;
    return const SubjectFetchResult(subjects: [SubjectModel(id: 1, title: 'GS1', colorInt: 1)], todayTotalMs: 0);
  }

  @override
  Future<List<SubjectModel>> getCachedSubjects() async =>
      const [SubjectModel(id: 9, title: 'Cached', colorInt: 1)];
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('offline: subjects come from the cache and nothing reaches the server', () async {
    final timer = _Timer();
    final subjects = _Subjects();
    final queue = OfflineSyncRepository(timerRepository: timer, prefs: prefs);
    final n = TimerNotifier(
      timerRepository: timer,
      subjectRepository: subjects,
      offlineSyncRepository: queue,
      sessionStore: TimerSessionStore(prefs: prefs),
      isOffline: () => true,
    );
    await n.ready;
    expect(subjects.fetches, 0);
    expect(n.state.subjects.single.title, 'Cached');

    n.selectSubject(n.state.subjects.single);
    await n.startStudy();
    expect(n.state.isRunning, isTrue);
    expect(timer.starts, 0);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await n.reconcileWithServer();
    expect(timer.logs, 0);

    await n.stopStudy();
    expect(timer.stops, 0);
    expect((await queue.getPendingSessions()).length, 1, reason: 'the session is queued locally');
    n.dispose();
  });

  test('online: a hanging server never delays the start', () async {
    final timer = _Timer()..hangStart = Completer<bool>();
    final n = TimerNotifier(
      timerRepository: timer,
      subjectRepository: _Subjects(),
      sessionStore: TimerSessionStore(prefs: prefs),
    );
    await n.ready;
    n.selectSubject(n.state.subjects.first);
    await n.startStudy().timeout(const Duration(milliseconds: 500));
    expect(n.state.isRunning, isTrue);
    expect(timer.starts, 1);
    n.dispose();
  });
}
