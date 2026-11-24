import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/classic_timer_screen.dart' show liveMemberStudyMs;
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_session_store.dart';

const _twoHours = 2 * 3600 * 1000;

class _FakeTimerRepository extends TimerRepository {
  Map<String, dynamic>? dailyLog;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
    int? taskId,
  }) async =>
      true;

  @override
  Future<Map<String, dynamic>?> fetchDailyLog(DateTime date) async => dailyLog;
}

/// The server's day total counts finished sessions only (2 h here).
class _FakeSubjectRepository extends SubjectRepository {
  bool fromServer = true;

  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String language = 'pt',
    String timezone = 'UTC',
    int version = 1,
  }) async {
    return SubjectFetchResult(
      subjects: const [SubjectModel(id: 1, title: 'misc.', colorInt: 4292557552, studyMs: _twoHours)],
      todayTotalMs: fromServer ? _twoHours : 0,
      isFromServer: fromServer,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTimerRepository timerRepository;
  late _FakeSubjectRepository subjectRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    timerRepository = _FakeTimerRepository();
    subjectRepository = _FakeSubjectRepository();
  });

  Future<TimerNotifier> build() async {
    final n = TimerNotifier(
      timerRepository: timerRepository,
      subjectRepository: subjectRepository,
      sessionStore: TimerSessionStore(),
    );
    addTearDown(n.dispose);
    await n.ready;
    await n.loadSubjects();
    return n;
  }

  test('restored running session is added to the finished time, not max()', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      TimerSessionStore.storageKey,
      jsonEncode({
        'subject_id': 1,
        'subject_title': 'misc.',
        'start_at': DateTime.now().toUtc().subtract(const Duration(minutes: 38)).millisecondsSinceEpoch,
      }),
    );
    final n = await build();
    expect(n.state.isRunning, isTrue);
    expect(n.state.todayTotalMs, greaterThanOrEqualTo(_twoHours + 38 * 60000));
    expect(n.state.todayTotalMs, lessThan(_twoHours + 39 * 60000));
  });

  test('session adopted from the server is added to the finished time', () async {
    timerRepository.dailyLog = {
      'dl': {
        'is': true,
        'st': DateTime.now().toUtc().subtract(const Duration(minutes: 38)).toIso8601String(),
        'sb': 'misc.',
      },
    };
    final n = await build();
    expect(n.state.isRunning, isTrue);
    expect(n.state.todayTotalMs, greaterThanOrEqualTo(_twoHours + 38 * 60000));
    expect(n.state.todayTotalMs, lessThan(_twoHours + 39 * 60000));
  });

  test('a failed fetch keeps the local total instead of zeroing it', () async {
    final n = await build();
    expect(n.state.todayTotalMs, _twoHours);
    subjectRepository.fromServer = false;
    await n.loadSubjects();
    expect(n.state.todayTotalMs, _twoHours);
  });

  group('liveMemberStudyMs', () {
    final now = DateTime.utc(2026, 11, 24, 12);
    final fetchedAt = now.subtract(const Duration(seconds: 47));

    GroupMemberModel member({bool studying = true, bool paused = false, DateTime? start}) => GroupMemberModel(
          userId: 1,
          name: 'x',
          studiconId: 0,
          isStudying: studying,
          isPaused: paused,
          studyMs: 3600000,
          sessionStartedAt: start,
          hasCustomAvatar: false,
        );

    test('adds the running session from its start, not from the fetch', () {
      final m = member(start: now.subtract(const Duration(minutes: 38)));
      expect(liveMemberStudyMs(m, now, fetchedAt), 3600000 + 38 * 60000);
    });

    test('idle or paused members keep the server total', () {
      expect(liveMemberStudyMs(member(studying: false), now, fetchedAt), 3600000);
      expect(liveMemberStudyMs(member(paused: true, start: now), now, fetchedAt), 3600000);
    });

    test('without a start time falls back to the time since the fetch', () {
      expect(liveMemberStudyMs(member(), now, fetchedAt), 3600000 + 47000);
    });

    test('a start in the future (clock skew) never subtracts', () {
      final m = member(start: now.add(const Duration(minutes: 1)));
      expect(liveMemberStudyMs(m, now, fetchedAt), 3600000);
    });
  });
}
