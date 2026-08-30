import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = handler(options);
    final status = res['status'] as int? ?? 200;
    final data = res['data'] as String;
    return ResponseBody.fromString(
      data,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Pomodoro Timer Mode Tests', () {
    late TimerRepository timerRepo;
    late SubjectRepository subjectRepo;

    setUp(() {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path.contains('/logs/v2/study/save')) {
          return {
            'status': 200,
            'data': '{"s":true,"dl":{"sm":1500000}}',
          };
        }
        if (options.path.contains('/logs/v2/study/start')) {
          return {'status': 200, 'data': '{"s":true}'};
        }
        if (options.path.contains('/category/subjects')) {
          return {
            'status': 200,
            'data': '{"s":true,"sub":[{"id":1,"t":"Física","c":4292557552,"sm":0,"td":0,"o":100}]}',
          };
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      timerRepo = TimerRepository(apiClient: ApiClient(customDio: dio));
      subjectRepo = SubjectRepository(apiClient: ApiClient(customDio: dio));
    });

    test('setTimerMode switches to Pomodoro and sets initial remaining time', () {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      notifier.setTimerMode(TimerMode.pomodoro);

      expect(notifier.state.mode, TimerMode.pomodoro);
      expect(notifier.state.pomodoroPhase, PomodoroPhase.focus);
      expect(notifier.state.pomodoroRemainingMs, 25 * 60 * 1000);
      expect(notifier.state.currentPomodoroCycle, 1);
    });

    test('configurePomodoro updates parameters and initial remaining time', () {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      notifier.setTimerMode(TimerMode.pomodoro);
      notifier.configurePomodoro(
        focusMinutes: 50,
        shortBreakMinutes: 10,
        longBreakMinutes: 30,
        totalCycles: 3,
        autoStartBreaks: true,
      );

      expect(notifier.state.pomodoroFocusMinutes, 50);
      expect(notifier.state.pomodoroShortBreakMinutes, 10);
      expect(notifier.state.pomodoroLongBreakMinutes, 30);
      expect(notifier.state.totalPomodoroCycles, 3);
      expect(notifier.state.autoStartBreaks, true);
      expect(notifier.state.pomodoroRemainingMs, 50 * 60 * 1000);
    });

    test('skipPomodoroPhase advances from Focus to Short Break and increments cycle', () async {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      notifier.setTimerMode(TimerMode.pomodoro);
      expect(notifier.state.pomodoroPhase, PomodoroPhase.focus);
      expect(notifier.state.currentPomodoroCycle, 1);

      await notifier.skipPomodoroPhase();

      expect(notifier.state.pomodoroPhase, PomodoroPhase.shortBreak);
      expect(notifier.state.currentPomodoroCycle, 2);
      expect(notifier.state.pomodoroRemainingMs, 5 * 60 * 1000);
    });

    test('Advancing at totalCycles transitions to Long Break and resets cycle', () async {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      notifier.setTimerMode(TimerMode.pomodoro);
      notifier.configurePomodoro(totalCycles: 2);

      // Cycle 1: Focus -> Short Break (cycle becomes 2)
      await notifier.skipPomodoroPhase();
      expect(notifier.state.pomodoroPhase, PomodoroPhase.shortBreak);
      expect(notifier.state.currentPomodoroCycle, 2);

      // Break -> Cycle 2 Focus
      await notifier.skipPomodoroPhase();
      expect(notifier.state.pomodoroPhase, PomodoroPhase.focus);
      expect(notifier.state.currentPomodoroCycle, 2);

      // Cycle 2 Focus completed (reaches totalCycles: 2) -> Long Break
      await notifier.skipPomodoroPhase();
      expect(notifier.state.pomodoroPhase, PomodoroPhase.longBreak);
      expect(notifier.state.currentPomodoroCycle, 1);
      expect(notifier.state.pomodoroRemainingMs, 15 * 60 * 1000);
    });

    test('stopStudy resets Pomodoro timer to initial focus state', () async {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );

      notifier.setTimerMode(TimerMode.pomodoro);
      notifier.selectSubject(
        const SubjectModel(id: 1, title: 'Física', colorInt: 4292557552),
      );

      await notifier.startStudy();
      expect(notifier.state.isRunning, true);

      await notifier.stopStudy();
      expect(notifier.state.isRunning, false);
      expect(notifier.state.pomodoroPhase, PomodoroPhase.focus);
      expect(notifier.state.pomodoroRemainingMs, 25 * 60 * 1000);
    });
  });
}
