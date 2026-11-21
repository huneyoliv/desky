import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/timer_repository.dart';

class _MockApiClient extends ApiClient {
  _MockApiClient() : super(customDio: Dio());

  dynamic response;
  Object? error;
  final List<String> paths = [];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
    paths.add(path);
    if (error != null) throw error!;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: response,
      statusCode: 200,
    );
  }
}

void main() {
  group('TimerRepository.syncTime', () {
    late _MockApiClient api;
    late TimerRepository repository;

    setUp(() {
      api = _MockApiClient();
      repository = TimerRepository(apiClient: api);
    });

    test('reads the compact live key t', () async {
      // Exact shape observed from GET /time/.
      api.response = {'s': true, 't': 1795226620479};

      final result = await repository.syncTime();

      expect(result.millisecondsSinceEpoch, equals(1795226620479));
      expect(api.paths.single, equals('/time/'));
    });

    test('does not fall back to the local clock when t is present', () async {
      // A fixed far-future instant proves the value came from the payload.
      api.response = {'s': true, 't': 4102444800000};
      final before = DateTime.now();

      final result = await repository.syncTime();

      expect(result.isAfter(before.add(const Duration(days: 365))), isTrue);
    });

    test('still accepts the verbose timestamp key', () async {
      api.response = {'s': true, 'timestamp': 1795226620479};
      final result = await repository.syncTime();
      expect(result.millisecondsSinceEpoch, equals(1795226620479));
    });

    test('accepts a numeric string', () async {
      api.response = {'t': '1795226620479'};
      final result = await repository.syncTime();
      expect(result.millisecondsSinceEpoch, equals(1795226620479));
    });

    test('falls back to the local clock when the key is missing', () async {
      api.response = {'s': true};
      final before = DateTime.now();
      final result = await repository.syncTime();
      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('falls back to the local clock on a network error', () async {
      api.error = DioException(
        requestOptions: RequestOptions(path: '/time/'),
        type: DioExceptionType.connectionError,
      );
      final result = await repository.syncTime();
      expect(result, isA<DateTime>());
      // The previous implementation threw here instead of degrading.
    });
  });
}
