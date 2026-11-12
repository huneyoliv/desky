import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/rank_repository.dart';

class _StubApiClient extends ApiClient {
  _StubApiClient(this.response) : super(customDio: Dio());

  final Map<String, dynamic> response;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: response,
      statusCode: 200,
    );
  }
}

void main() {
  test('hourly minutes follow the start time of every session', () async {
    // Local start time, so the expectation holds in any timezone.
    final sessionStart = DateTime(2026, 11, 7, 21, 12);
    final apiClient = _StubApiClient({
      's': true,
      'ls': [
        {
          'dt': '2026-11-07',
          'sm': 5400000,
          'ls': [
            {'sb': 'Matemática', 'sm': 5400000, 'st': sessionStart.toIso8601String()},
          ],
        },
      ],
    });
    final repository = RankRepository(apiClient: apiClient);

    final byDay = await repository.fetchHourlyStudyMinutes(
      userId: 1,
      startDate: '2026-11-06',
      endDate: '2026-11-08',
    );

    expect(
      byDay.keys.toList()..sort(),
      equals(['2026-11-06', '2026-11-07', '2026-11-08']),
    );
    for (final buckets in byDay.values) {
      expect(buckets.length, equals(24));
    }

    // 90 minutes starting at 21:12: 48 minutes left in hour 21, 42 in hour 22.
    expect(byDay['2026-11-07']![21], equals(48));
    expect(byDay['2026-11-07']![22], equals(42));
    expect(byDay['2026-11-07']!.reduce((a, b) => a + b), equals(90));
    // A day without sessions stays empty instead of borrowing another day.
    expect(byDay['2026-11-06']!.every((minutes) => minutes == 0), isTrue);
    expect(byDay['2026-11-08']!.every((minutes) => minutes == 0), isTrue);
  });

  test('a session without a parseable start time is skipped', () async {
    final apiClient = _StubApiClient({
      's': true,
      'ls': [
        {
          'dt': '2026-11-07',
          'sm': 3600000,
          'ls': [
            {'sb': 'X', 'sm': 3600000, 'st': 'not-a-date'},
          ],
        },
      ],
    });
    final repository = RankRepository(apiClient: apiClient);

    final byDay = await repository.fetchHourlyStudyMinutes(
      userId: 1,
      startDate: '2026-11-07',
      endDate: '2026-11-07',
    );

    expect(byDay['2026-11-07']!.every((minutes) => minutes == 0), isTrue);
  });
}
