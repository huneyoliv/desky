import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/services/update_service.dart';

class MockAdapter implements HttpClientAdapter {
  final int statusCode;
  final dynamic responseData;
  final bool throwError;

  MockAdapter({
    this.statusCode = 200,
    this.responseData,
    this.throwError = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (throwError) {
      throw DioException(
        requestOptions: options,
        error: 'Network failure',
        type: DioExceptionType.connectionError,
      );
    }

    return ResponseBody.fromString(
      responseData is String ? responseData : '',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('UpdateService Tests', () {
    test('fetchLatestRelease parses valid release JSON', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter(
        statusCode: 200,
        responseData: '{"id":1,"tag_name":"v1.0.1","name":"Release 1.0.1","body":"Test","html_url":"https://github.com","assets":[]}',
      );

      final service = UpdateService(dio: dio);
      final release = await service.fetchLatestRelease();

      expect(release, isNotNull);
      expect(release!.tagName, 'v1.0.1');
      expect(release.cleanVersion, '1.0.1');
    });

    test('fetchLatestRelease handles 404 gracefully', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter(
        statusCode: 404,
        responseData: '{"message":"Not Found"}',
      );

      final service = UpdateService(dio: dio);
      final release = await service.fetchLatestRelease();

      expect(release, isNull);
    });

    test('fetchLatestRelease handles connection failure gracefully without throwing', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter(throwError: true);

      final service = UpdateService(dio: dio);
      final release = await service.fetchLatestRelease();

      expect(release, isNull);
    });
  });
}
