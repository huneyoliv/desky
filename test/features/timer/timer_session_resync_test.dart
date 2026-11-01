import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_session_store.dart';

class _FakeTimerRepository extends TimerRepository {
  Map<String, dynamic>? dailyLog;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
  }) async {
    startCalls++;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async {
    stopCalls++;
    return {'s': true, 'dl': {'sm': studyMs}};
  }

  @override
  Future<Map<String, dynamic>?> fetchDailyLog(DateTime date) async => dailyLog;
}

class _FakeSubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String language = 'pt',
    String timezone = 'UTC',
    int version = 1,
  }) async {
    return const SubjectFetchResult(
      subjects: [SubjectModel(id: 1, title: 'Matemática', colorInt: 4292557552)],
      todayTotalMs: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTimerRepository timerRepository;
  late _FakeSubjectRepository subjectRepository;
  late TimerSessionStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    timerRepository = _FakeTimerRepository();
    subjectRepository = _FakeSubjectRepository();
    store = TimerSessionStore();
  });

  Future<TimerNotifier> buildNotifier() async {
    final notifier = TimerNotifier(
      timerRepository: timerRepository,
      subjectRepository: subjectRepository,
      sessionStore: store,
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    return notifier;
  }

  Future<void> seedSession({required Duration ago, int subjectId = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      TimerSessionStore.storageKey,
      jsonEncode({
        'subject_id': subjectId,
        'subject_title': 'Matemática',
        'start_at': DateTime.now().toUtc().subtract(ago).millisecondsSinceEpoch,
      }),
    );
  }

  group('Timer session resync', () {
    test('restores a persisted session and keeps counting', () async {
      await seedSession(ago: const Duration(minutes: 10));

      final notifier = await buildNotifier();

      expect(notifier.state.isRunning, isTrue);
      expect(notifier.state.mode, TimerMode.stopwatch);
      expect(notifier.state.sessionElapsedMs, greaterThan(9 * 60 * 1000));
      expect(notifier.state.currentSubject?.title, 'Matemática');
    });

    test('persists a snapshot when a study starts', () async {
      final notifier = await buildNotifier();
      await notifier.loadSubjects();

      await notifier.startStudy();

      final snapshot = await store.load();
      expect(snapshot, isNotNull);
      expect(snapshot!.subjectTitle, 'Matemática');
    });

    test('clears the snapshot when the user stops studying', () async {
      await seedSession(ago: const Duration(minutes: 5));
      final notifier = await buildNotifier();

      await notifier.stopStudy();

      expect(await store.load(), isNull);
      expect(notifier.state.isRunning, isFalse);
    });

    test('discards a snapshot older than a study day', () async {
      await seedSession(ago: const Duration(hours: 48));

      final notifier = await buildNotifier();

      expect(notifier.state.isRunning, isFalse);
      expect(await store.load(), isNull);
    });

    test('adopts a session that is still open on YPT without starting a new one', () async {
      timerRepository.dailyLog = {
        's': true,
        'dl': {
          'is': true,
          'st': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          'ls': [
            {'sb': 'Matemática', 'sm': 120000},
          ],
        },
      };

      final notifier = await buildNotifier();

      expect(notifier.state.isRunning, isTrue);
      expect(notifier.state.sessionElapsedMs, greaterThan(4 * 60 * 1000));
      expect(timerRepository.startCalls, 0);
      expect(await store.load(), isNotNull);
    });

    test('stops the local timer when YPT reports no active session', () async {
      await seedSession(ago: const Duration(minutes: 5));
      timerRepository.dailyLog = {'s': true, 'dl': {'is': false}};

      final notifier = await buildNotifier();

      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.sessionElapsedMs, 0);
      expect(await store.load(), isNull);
    });

    test('leaves the local timer untouched when the payload has no is flag', () async {
      await seedSession(ago: const Duration(minutes: 5));
      timerRepository.dailyLog = {'s': true, 'dl': <String, dynamic>{}};

      final notifier = await buildNotifier();

      expect(notifier.state.isRunning, isTrue);
      expect(await store.load(), isNotNull);
    });
  });
}
