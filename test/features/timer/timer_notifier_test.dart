import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';

void main() {
  group('TimerNotifier Tests', () {
    late TimerNotifier notifier;
    late Dio mockDio;

    setUp(() {
      mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/user/v2/reload/info')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'ss': [
                      {
                        'id': 100,
                        'tt': 'Português',
                        'sm': 1800000,
                        'or': 100,
                        'co': 4292557552,
                        'dl': false,
                      },
                      {
                        'id': 101,
                        'tt': 'Matemática',
                        'sm': 3600000,
                        'or': 200,
                        'co': 4294948685,
                        'dl': false,
                      },
                    ],
                    'dl': {
                      'sm': 5400000,
                      'ls': [
                        {'id': 100, 'sb': 'Português', 'sm': 1800000},
                        {'id': 101, 'sb': 'Matemática', 'sm': 3600000},
                      ],
                    },
                  },
                ),
              );
            }
            if (options.path.contains('/study/start') ||
                options.path.contains('/study/stop')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'s': true},
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final apiClient = ApiClient(customDio: mockDio);
      final timerRepo = TimerRepository(apiClient: apiClient);
      final subjectRepo = SubjectRepository(apiClient: apiClient);

      notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
        userStudiconId: 377,
      );
    });

    test('loadSubjects populates subjects list and sets first subject', () async {
      await notifier.loadSubjects();

      expect(notifier.state.subjects.length, equals(2));
      expect(notifier.state.currentSubject?.title, equals('Português'));
      expect(notifier.state.todayTotalMs, equals(5400000));
    });

    test('selectSubject updates currentSubject when not running', () async {
      await notifier.loadSubjects();
      final mathSubject = notifier.state.subjects[1];

      notifier.selectSubject(mathSubject);
      expect(notifier.state.currentSubject?.id, equals(101));
    });

    test('startStudy sets isRunning true and ticks timer', () async {
      await notifier.loadSubjects();
      await notifier.startStudy();

      expect(notifier.state.isRunning, isTrue);

      // Wait 2.2 seconds for ticker
      await Future.delayed(const Duration(milliseconds: 2200));

      expect(notifier.state.sessionElapsedMs, greaterThanOrEqualTo(2000));

      await notifier.pauseStudy();
      expect(notifier.state.isRunning, isFalse);
      expect(notifier.state.isPaused, isTrue);

      await notifier.stopStudy();
      expect(notifier.state.sessionElapsedMs, equals(0));
      expect(notifier.state.isPaused, isFalse);
    });
  });
}
