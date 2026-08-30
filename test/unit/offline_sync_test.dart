import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/offline_session_model.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/offline_sync_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/offline_sync_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  group('Offline Sync Queue Tests', () {
    late SharedPreferences prefs;
    late TimerRepository timerRepo;
    late SubjectRepository subjectRepo;
    late OfflineSyncRepository offlineRepo;
    bool simulateServerFailure = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      simulateServerFailure = false;

      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path.contains('/study/stop') || options.path.contains('/logs/v2/study/save')) {
          if (simulateServerFailure) {
            return {'status': 500, 'data': '{"s":false,"m":"Network/Server error"}'};
          }
          return {
            'status': 200,
            'data': '{"s":true,"dl":{"sm":3600000,"tp":3600000}}',
          };
        }
        if (options.path.contains('/user/v2/splash-login') ||
            options.path.contains('/user/v2/reload/info')) {
          return {
            'status': 200,
            'data': '{"s":true,"ss":[{"id":1,"tt":"Matemática","co":4292557552,"sm":0,"or":100,"dl":false,"ia":false}]}',
          };
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      timerRepo = TimerRepository(apiClient: ApiClient(customDio: dio));
      subjectRepo = SubjectRepository(apiClient: ApiClient(customDio: dio));
      offlineRepo = OfflineSyncRepository(timerRepository: timerRepo, prefs: prefs);
    });

    test('OfflineSessionModel serialization and deserialization', () {
      final now = DateTime.now();
      final model = OfflineSessionModel(
        id: '123_45',
        subjectId: 45,
        subjectTitle: 'Química',
        startAt: now.subtract(const Duration(minutes: 30)),
        stopAt: now,
        studyMs: 1800000,
        createdAt: now,
        retryCount: 1,
        lastError: 'Timeout',
      );

      final json = model.toJson();
      final fromJson = OfflineSessionModel.fromJson(json);

      expect(fromJson.id, '123_45');
      expect(fromJson.subjectId, 45);
      expect(fromJson.subjectTitle, 'Química');
      expect(fromJson.studyMs, 1800000);
      expect(fromJson.retryCount, 1);
      expect(fromJson.lastError, 'Timeout');
    });

    test('OfflineSyncRepository enqueues, reads, and clears sessions', () async {
      final startAt = DateTime(2026, 8, 14, 14, 0);
      final stopAt = DateTime(2026, 8, 14, 15, 0);

      await offlineRepo.enqueueSession(
        subjectId: 1,
        subjectTitle: 'Matemática',
        startAt: startAt,
        stopAt: stopAt,
        studyMs: 3600000,
      );

      var pending = await offlineRepo.getPendingSessions();
      expect(pending.length, 1);
      expect(pending.first.subjectTitle, 'Matemática');
      expect(pending.first.studyMs, 3600000);

      await offlineRepo.removeSession(pending.first.id);
      pending = await offlineRepo.getPendingSessions();
      expect(pending.isEmpty, true);
    });

    test('syncAllPending successfully drains queue when server responds OK', () async {
      await offlineRepo.enqueueSession(
        subjectId: 1,
        subjectTitle: 'Matemática',
        startAt: DateTime.now().subtract(const Duration(hours: 1)),
        stopAt: DateTime.now(),
        studyMs: 3600000,
      );

      final result = await offlineRepo.syncAllPending();
      expect(result.totalSynced, 1);
      expect(result.totalFailed, 0);
      expect(result.remaining, 0);

      final pending = await offlineRepo.getPendingSessions();
      expect(pending.isEmpty, true);
    });

    test('syncAllPending retains failed sessions with incremented retry count', () async {
      simulateServerFailure = true;

      await offlineRepo.enqueueSession(
        subjectId: 1,
        subjectTitle: 'Matemática',
        startAt: DateTime.now().subtract(const Duration(hours: 1)),
        stopAt: DateTime.now(),
        studyMs: 3600000,
      );

      final result = await offlineRepo.syncAllPending();
      expect(result.totalSynced, 0);
      expect(result.totalFailed, 1);
      expect(result.remaining, 1);

      final pending = await offlineRepo.getPendingSessions();
      expect(pending.length, 1);
      expect(pending.first.retryCount, 1);
    });

    test('TimerNotifier enqueues offline session when stopStudy encounters error', () async {
      simulateServerFailure = true;

      final timerNotifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
        offlineSyncRepository: offlineRepo,
      );

      await timerNotifier.loadSubjects();
      timerNotifier.selectSubject(
        const SubjectModel(id: 1, title: 'Matemática', colorInt: 4292557552),
      );

      timerNotifier.state = timerNotifier.state.copyWith(
        isRunning: true,
        sessionElapsedMs: 1800000,
        sessionStartAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      await timerNotifier.stopStudy();

      final pending = await offlineRepo.getPendingSessions();
      expect(pending.length, 1);
      expect(pending.first.subjectTitle, 'Matemática');
      expect(pending.first.studyMs, 1800000);
    });

    test('OfflineSyncNotifier syncNow updates pending state properly', () async {
      final notifier = OfflineSyncNotifier(repository: offlineRepo);

      await notifier.enqueueSession(
        subjectId: 1,
        subjectTitle: 'Matemática',
        startAt: DateTime.now().subtract(const Duration(minutes: 45)),
        stopAt: DateTime.now(),
        studyMs: 2700000,
      );

      expect(notifier.state.hasPending, true);
      expect(notifier.state.pendingCount, 1);

      final res = await notifier.syncNow();
      expect(res.totalSynced, 1);
      expect(notifier.state.hasPending, false);
      expect(notifier.state.pendingCount, 0);
    });
  });
}
