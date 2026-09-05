import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';

class FakeTimerRepository extends TimerRepository {
  bool recordRestCalled = false;
  int? lastRestMs;
  DateTime? lastRestStart;
  DateTime? lastRestStop;

  bool startStudyCalled = false;
  bool stopStudyCalled = false;
  int? lastStudyMs;
  DateTime? lastStudyStart;
  DateTime? lastStudyStop;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
  }) async {
    startStudyCalled = true;
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
    stopStudyCalled = true;
    lastStudyMs = studyMs;
    lastStudyStart = startAt;
    lastStudyStop = stopAt;
    return {
      's': true,
      'dl': {'sm': studyMs, 'tp': studyMs}
    };
  }

  @override
  Future<bool> recordRest({
    required DateTime startAt,
    required DateTime stopAt,
    required int restMs,
    String deviceModel = 'Desktop',
  }) async {
    recordRestCalled = true;
    lastRestStart = startAt;
    lastRestStop = stopAt;
    lastRestMs = restMs;
    return true;
  }
}

class FakeSubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String? language,
    String? timezone,
    int? version,
  }) async {
    return const SubjectFetchResult(
      subjects: [
        SubjectModel(id: 1, title: 'Matemática', colorInt: 4292557552, studyMs: 5000),
      ],
      todayTotalMs: 5000,
    );
  }
}

void main() {
  group('Timer Break Tracking & Rest Isolation Tests', () {
    test('pauseStudy syncs active focus session immediately and transitions to isPaused', () async {
      final timerRepo = FakeTimerRepository();
      final subjectRepo = FakeSubjectRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.startStudy();
      expect(notifier.state.isRunning, isTrue);
      expect(notifier.state.isPaused, isFalse);

      notifier.state = notifier.state.copyWith(sessionElapsedMs: 12000);

      await notifier.pauseStudy();
      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.isPaused, isTrue);
      expect(notifier.state.restStartAt, isNotNull);
      expect(notifier.state.sessionElapsedMs, equals(12000));
      expect(timerRepo.stopStudyCalled, isTrue);
      expect(timerRepo.lastStudyMs, equals(12000));
    });

    test('resuming after pause records accumulated rest time via recordRest', () async {
      final timerRepo = FakeTimerRepository();
      final subjectRepo = FakeSubjectRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.startStudy();
      await notifier.pauseStudy();

      notifier.state = notifier.state.copyWith(sessionRestMs: 15000);

      await notifier.startStudy();

      expect(notifier.state.isRunning, isTrue);
      expect(notifier.state.isPaused, isFalse);
      expect(notifier.state.sessionRestMs, equals(0));
      expect(timerRepo.recordRestCalled, isTrue);
      expect(timerRepo.lastRestMs, equals(15000));
    });

    test('stopStudy while paused records rest and does not inflate subject hours with rest time', () async {
      final timerRepo = FakeTimerRepository();
      final subjectRepo = FakeSubjectRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.startStudy();
      notifier.state = notifier.state.copyWith(sessionElapsedMs: 20000);
      await notifier.pauseStudy();

      expect(timerRepo.stopStudyCalled, isTrue);
      expect(timerRepo.lastStudyMs, equals(20000));

      // User rests for 50 minutes (3,000,000 ms)
      notifier.state = notifier.state.copyWith(
        sessionRestMs: 3000000,
      );

      await notifier.stopStudy();

      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.isPaused, isFalse);
      expect(timerRepo.recordRestCalled, isTrue);
      expect(timerRepo.lastRestMs, equals(3000000));
      // Subject received strictly the 20000 ms, rest of 3000000 ms went to recordRest
      expect(timerRepo.lastStudyMs, equals(20000));
    });

    test('stopAt strictly matches startAt + studyMs to eliminate server interval inflation', () async {
      final timerRepo = FakeTimerRepository();
      final subjectRepo = FakeSubjectRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final customStart = DateTime.now().subtract(const Duration(minutes: 30));
      notifier.state = notifier.state.copyWith(
        sessionStartAt: customStart,
        sessionElapsedMs: 600000, // 10 minutes
        isRunning: true,
      );

      await notifier.pauseStudy();

      expect(timerRepo.stopStudyCalled, isTrue);
      expect(timerRepo.lastStudyStart, equals(customStart));
      expect(timerRepo.lastStudyStop, equals(customStart.add(const Duration(milliseconds: 600000))));
      expect(timerRepo.lastStudyStop!.difference(timerRepo.lastStudyStart!).inMilliseconds, equals(600000));
    });
  });
}
