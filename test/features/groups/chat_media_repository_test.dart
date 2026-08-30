import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/sticker_model.dart';
import 'package:desky/data/repositories/chat_media_repository.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(customDio: Dio());

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: getResponse,
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
    return Response(
      requestOptions: RequestOptions(path: path),
      data: postResponse,
      statusCode: 200,
    );
  }
}

void main() {
  group('ChatMediaRepository Tests', () {
    late MockApiClient mockApiClient;
    late ChatMediaRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = ChatMediaRepository(apiClient: mockApiClient);
    });

    test('StickerSet.fromJson parses sticker sets correctly', () {
      final json = {
        'id': 1,
        'name': 'Foco & Estudo',
        'preview': 'set1_preview.png',
        'stickers': [
          {'id': 10, 'setId': 1, 'url': 'sticker1.png'}
        ]
      };

      final set = StickerSet.fromJson(json);

      expect(set.id, 1);
      expect(set.name, 'Foco & Estudo');
      expect(set.previewUrl, 'https://alicdn.tgclab.com/sticker/set1_preview.png');
      expect(set.stickers.length, 1);
      expect(set.stickers.first.url, 'https://alicdn.tgclab.com/sticker/sticker1.png');
    });

    test('fetchStickerSets parses API response correctly', () async {
      mockApiClient.getResponse = {
        's': true,
        'sets': [
          {
            'id': 1,
            'name': 'Pacote 1',
            'preview': 'p1.png',
            'stickers': []
          }
        ]
      };

      final sets = await repository.fetchStickerSets();

      expect(sets.length, 1);
      expect(sets.first.name, 'Pacote 1');
    });
  });
}
