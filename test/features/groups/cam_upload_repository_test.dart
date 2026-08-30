import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/cam_upload_repository.dart';

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
  group('CamUploadRepository Tests', () {
    late MockApiClient mockApiClient;
    late CamUploadRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = CamUploadRepository(apiClient: mockApiClient);
    });

    test('uploadCamPhoto returns formatted CDN URL on success', () async {
      mockApiClient.postResponse = {
        's': true,
        'path': '/cam/2026-08-11/100.jpg',
      };

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final url = await repository.uploadCamPhoto(
        groupId: 1,
        imageBytes: bytes,
        dateYmd: '2026-08-11',
        userId: 100,
      );

      expect(url, 'https://alicdn.tgclab.com/cam/2026-08-11/100.jpg');
    });
  });
}
