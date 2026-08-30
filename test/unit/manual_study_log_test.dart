import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/api/api_exception.dart';
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
  group('Manual Study Log Tests', () {
    late TimerRepository timerRepo;
    late SubjectRepository subjectRepo;
    late Map<String, dynamic> lastManualPayload;

    setUp(() {
      lastManualPayload = {};
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path.contains('/logs/v2/study/manual')) {
          lastManualPayload = options.data as Map<String, dynamic>;
          return {
            'status': 200,
            'data': '{"s":true,"dl":{"sm":3600000,"tp":3600000}}',
          };
        }
        if (options.path.contains('/user/v2/splash-login') ||
            options.path.contains('/user/v2/reload/info')) {
          return {
            'status': 200,
            'data': '{"s":true,"ss":[{"id":10,"tt":"História","co":4292557552,"sm":1800000,"or":100,"dl":false,"ia":false}]}',
          };
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      timerRepo = TimerRepository(apiClient: ApiClient(customDio: dio));
      subjectRepo = SubjectRepository(apiClient: ApiClient(customDio: dio));
    });

    test('logManualStudy sends correct JSON payload to /logs/v2/study/manual', () async {
      final startAt = DateTime(2026, 8, 14, 10, 0, 0);
      final stopAt = DateTime(2026, 8, 14, 11, 0, 0);

      final res = await timerRepo.logManualStudy(
        subjectId: 10,
        subjectTitle: 'História',
        startAt: startAt,
        stopAt: stopAt,
      );

      expect(res, isNotNull);
      expect(res!['s'], true);
      expect(lastManualPayload['subject_id'], 10);
      expect(lastManualPayload['subject'], 'História');
      expect(lastManualPayload['study_ms'], 3600000);
      expect(lastManualPayload['deviceModel'], 'Desktop');
      expect(lastManualPayload['language'], 'pt');
    });

    test('logManualStudy throws ApiException if stopAt is before or equal to startAt', () async {
      final startAt = DateTime(2026, 8, 14, 11, 0, 0);
      final stopAt = DateTime(2026, 8, 14, 10, 0, 0);

      expect(
        () => timerRepo.logManualStudy(
          subjectId: 10,
          subjectTitle: 'História',
          startAt: startAt,
          stopAt: stopAt,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('TimerNotifier.logManualStudy updates state todayTotalMs and subject studyMs', () async {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
      );
      await notifier.loadSubjects();

      final startAt = DateTime(2026, 8, 14, 10, 0, 0);
      final stopAt = DateTime(2026, 8, 14, 11, 0, 0);

      final success = await notifier.logManualStudy(
        subjectId: 10,
        subjectTitle: 'História',
        startAt: startAt,
        stopAt: stopAt,
      );

      expect(success, true);
      expect(notifier.state.todayTotalMs, 3600000);
      expect(notifier.state.subjects.first.studyMs, 1800000 + 3600000);
      expect(notifier.state.currentSubject?.studyMs, 1800000 + 3600000);
    });
  });
}
