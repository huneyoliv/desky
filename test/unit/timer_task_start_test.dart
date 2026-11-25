import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(customDio: Dio());

  final List<Map<String, dynamic>> payloads = [];

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    expect(path, '/study/start');
    payloads.add(Map<String, dynamic>.from(data as Map));
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'s': true},
      statusCode: 200,
    );
  }
}

class _FakeTimerRepository extends TimerRepository {
  int? receivedTaskId;
  bool startResult = true;
  Object? startError;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
    int? taskId,
  }) async {
    receivedTaskId = taskId;
    if (startError != null) throw startError!;
    return startResult;
  }

  @override
  Future<Map<String, dynamic>?> fetchDailyLog(
    DateTime date, {
    Duration? gmtOffset,
    int resetHour = 5,
  }) async => null;
}

class _FakeSubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String language = 'pt',
    String timezone = 'UTC',
    int version = 1,
  }) async {
    return const SubjectFetchResult(
      subjects: [SubjectModel(id: 9, title: 'Física', colorInt: 4292557552)],
      todayTotalMs: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TimerRepository sends taskId only when supplied', () async {
    final api = _FakeApiClient();
    final repo = TimerRepository(apiClient: api);

    await repo.startStudy(
      subjectTitle: 'Física',
      subjectId: 9,
      startAt: DateTime.utc(2026, 11, 20),
      taskId: 77,
    );
    await repo.startStudy(
      subjectTitle: 'Física',
      subjectId: 9,
      startAt: DateTime.utc(2026, 11, 20),
    );

    expect(api.payloads[0]['taskId'], 77);
    expect(api.payloads[1]['taskId'], isNull);
    expect(api.payloads[0]['subject_id'], 9);
    expect(api.payloads[0]['deviceModel'], isNotEmpty);
  });

  test('TimerNotifier forwards a task id to the repository', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeTimerRepository();
    final notifier = TimerNotifier(
      timerRepository: repo,
      subjectRepository: _FakeSubjectRepository(),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;

    await notifier.startStudy(taskId: 77);

    expect(repo.receivedTaskId, 77);
    expect(notifier.state.isRunning, isTrue);
    expect(notifier.state.currentSubject?.id, 9);
  });

  test('rejected start does not mark the timer as running', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeTimerRepository()..startResult = false;
    final notifier = TimerNotifier(
      timerRepository: repo,
      subjectRepository: _FakeSubjectRepository(),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;

    await notifier.startStudy(taskId: 77);

    expect(repo.receivedTaskId, 77);
    expect(notifier.state.isRunning, isFalse);
    expect(notifier.state.sessionStartAt, isNull);
  });

  test('transport exception preserves the offline local start', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeTimerRepository()..startError = StateError('offline');
    final notifier = TimerNotifier(
      timerRepository: repo,
      subjectRepository: _FakeSubjectRepository(),
    );
    addTearDown(notifier.dispose);
    await notifier.ready;

    await notifier.startStudy(taskId: 77);

    expect(repo.receivedTaskId, 77);
    expect(notifier.state.isRunning, isTrue);
    expect(notifier.state.sessionStartAt, isNotNull);
  });
}
