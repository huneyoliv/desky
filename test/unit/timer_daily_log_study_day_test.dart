import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(customDio: Dio());

  final List<String> getPaths = <String>[];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
    getPaths.add(path);
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{
        's': true,
        'dl': <String, dynamic>{},
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{'s': true, 'ss': <dynamic>[]},
      statusCode: 200,
    );
  }
}

class _RecordingTimerRepository extends TimerRepository {
  Duration? receivedGmtOffset;
  int? receivedResetHour;

  @override
  Future<Map<String, dynamic>?> fetchDailyLog(
    DateTime date, {
    Duration? gmtOffset,
    int resetHour = 5,
  }) async {
    receivedGmtOffset = gmtOffset;
    receivedResetHour = resetHour;
    return null;
  }
}

void main() {
  group('TimerRepository daily log study-day boundary', () {
    late _RecordingApiClient apiClient;
    late TimerRepository repository;

    setUp(() {
      apiClient = _RecordingApiClient();
      repository = TimerRepository(apiClient: apiClient);
    });

    test('uses the previous Sri Lanka study day immediately before 05:00',
        () async {
      await repository.fetchDailyLog(
        DateTime.utc(2026, 11, 23, 23, 29, 59),
        gmtOffset: const Duration(hours: 5, minutes: 30),
        resetHour: 5,
      );

      expect(apiClient.getPaths, <String>['/logs/day?date=2026-11-23']);
    });

    test('starts the new Sri Lanka study day exactly at 05:00', () async {
      await repository.fetchDailyLog(
        DateTime.utc(2026, 11, 23, 23, 30),
        gmtOffset: const Duration(hours: 5, minutes: 30),
        resetHour: 5,
      );

      expect(apiClient.getPaths, <String>['/logs/day?date=2026-11-24']);
    });

    test('honors a non-default midnight reset immediately before the boundary',
        () async {
      await repository.fetchDailyLog(
        DateTime.utc(2026, 11, 23, 18, 29, 59),
        gmtOffset: const Duration(hours: 5, minutes: 30),
        resetHour: 0,
      );

      expect(apiClient.getPaths, <String>['/logs/day?date=2026-11-23']);
    });

    test('honors a non-default midnight reset exactly at the boundary',
        () async {
      await repository.fetchDailyLog(
        DateTime.utc(2026, 11, 23, 18, 30),
        gmtOffset: const Duration(hours: 5, minutes: 30),
        resetHour: 0,
      );

      expect(apiClient.getPaths, <String>['/logs/day?date=2026-11-24']);
    });
  });

  test('TimerNotifier supplies its effective country rule to reconciliation',
      () async {
    final timerRepository = _RecordingTimerRepository();
    final notifier = TimerNotifier(
      timerRepository: timerRepository,
      subjectRepository: SubjectRepository(apiClient: _RecordingApiClient()),
      gmtOffset: const Duration(hours: 5, minutes: 30),
      dayResetHour: 0,
    );

    await notifier.ready;

    expect(timerRepository.receivedGmtOffset,
        const Duration(hours: 5, minutes: 30));
    expect(timerRepository.receivedResetHour, 0);
    notifier.dispose();
  });
}
