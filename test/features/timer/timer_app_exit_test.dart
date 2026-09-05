import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/offline_sync_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';

class MockTimerRepository extends TimerRepository {
  bool stopStudyCalled = false;
  bool recordRestCalled = false;
  int? lastStudyMs;
  int? lastRestMs;
  bool shouldHangs = false;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
  }) async {
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
    if (shouldHangs) {
      await Completer<void>().future;
      return null;
    }
    stopStudyCalled = true;
    lastStudyMs = studyMs;
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
    if (shouldHangs) {
      await Completer<void>().future;
      return false;
    }
    recordRestCalled = true;
    lastRestMs = restMs;
    return true;
  }
}

class MockSubjectRepository extends SubjectRepository {
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

class MockOfflineSyncRepository extends Fake implements OfflineSyncRepository {
  bool enqueued = false;
  int? enqueuedStudyMs;

  @override
  Future<void> enqueueSession({
    required int subjectId,
    required String subjectTitle,
    required DateTime startAt,
    required DateTime stopAt,
    required int studyMs,
  }) async {
    enqueued = true;
    enqueuedStudyMs = studyMs;
  }
}

void main() {
  group('TimerNotifier - App Exit Scenarios', () {
    test('stopStudy cleanly syncs running focus session and resets state', () async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.startStudy();
      expect(notifier.state.isRunning, isTrue);

      notifier.state = notifier.state.copyWith(sessionElapsedMs: 15000);

      await notifier.stopStudy();

      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.isPaused, isFalse);
      expect(notifier.state.sessionElapsedMs, equals(0));
      expect(timerRepo.stopStudyCalled, isTrue);
      expect(timerRepo.lastStudyMs, equals(15000));
    });

    test('stopStudy while paused records rest time and resets state', () async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.startStudy();
      notifier.state = notifier.state.copyWith(sessionElapsedMs: 8000);

      await notifier.pauseStudy();
      expect(notifier.state.isPaused, isTrue);
      expect(timerRepo.stopStudyCalled, isTrue);

      notifier.state = notifier.state.copyWith(sessionRestMs: 4000);

      await notifier.stopStudy();

      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.isPaused, isFalse);
      expect(timerRepo.recordRestCalled, isTrue);
      expect(timerRepo.lastRestMs, equals(4000));
    });

    test('stopStudy does not block indefinitely if network hangs and falls back to offline queue', () async {
      final timerRepo = MockTimerRepository()..shouldHangs = true;
      final subjectRepo = MockSubjectRepository();
      final offlineRepo = MockOfflineSyncRepository();

      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
        offlineSyncRepository: offlineRepo,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.startStudy();
      notifier.state = notifier.state.copyWith(sessionElapsedMs: 10000);

      final stopwatch = Stopwatch()..start();
      await notifier.stopStudy();
      stopwatch.stop();

      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(5));
      expect(notifier.state.isRunning, isFalse);
      expect(offlineRepo.enqueued, isTrue);
      expect(offlineRepo.enqueuedStudyMs, equals(10000));
    });
  });
}
