import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? postResponse;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: postResponse,
      statusCode: 200,
    );
  }
}

void main() {
  group('TimerNotifier Day Reset Tests', () {
    late MockApiClient mockApiClient;
    late SubjectRepository subjectRepo;
    late TimerRepository timerRepo;

    setUp(() {
      mockApiClient = MockApiClient();
      mockApiClient.postResponse = {
        's': true,
        'ss': [
          {
            'id': 10,
            'tt': 'Matemática',
            'co': 4292557552,
            'or': 100,
            'sm': 7200000,
          }
        ],
        'dl': {
          'sm': 7200000,
          'rm': 600,
        },
      };
      subjectRepo = SubjectRepository(apiClient: mockApiClient);
      timerRepo = TimerRepository(apiClient: mockApiClient);
    });

    test('initializes with todayTotalMs and todayRestMs from server and observes dayResetHour', () async {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
        dayResetHour: 6,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.todayTotalMs, equals(7200000));
      expect(notifier.state.todayRestMs, equals(600 * 1000));
      expect(notifier.state.subjects.isNotEmpty, isTrue);
      expect(notifier.state.lastStudyDate.isNotEmpty, isTrue);

      notifier.dispose();
    });

    test('setDayResetHour updates reset hour and triggers date rollover if date changed', () async {
      final notifier = TimerNotifier(
        timerRepository: timerRepo,
        subjectRepository: subjectRepo,
        dayResetHour: 5,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.todayTotalMs, equals(7200000));

      notifier.setDayResetHour(7);
      expect(notifier.state.lastStudyDate.isNotEmpty, isTrue);

      notifier.dispose();
    });
  });
}
