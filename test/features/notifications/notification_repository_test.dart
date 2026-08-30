import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/notification_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';

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
  group('NotificationRepository Tests', () {
    late MockApiClient mockApiClient;
    late NotificationRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = NotificationRepository(apiClient: mockApiClient);
    });

    test('NotificationModel.fromJson parses JSON correctly', () {
      final json = {
        'id': 10,
        'title': 'Aviso de Grupo',
        'content': 'Você recebeu um alerta do líder.',
        'type': 'warning',
        'is_read': false,
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, 10);
      expect(model.title, 'Aviso de Grupo');
      expect(model.message, 'Você recebeu um alerta do líder.');
      expect(model.isRead, isFalse);
    });

    test('fetchNotifications returns parsed list', () async {
      mockApiClient.getResponse = {
        's': true,
        'notices': [
          {
            'id': 1,
            'title': 'Chacoalhão!',
            'content': 'Líder te chacoalhou.',
            'type': 'shake',
          }
        ]
      };

      final list = await repository.fetchNotifications();

      expect(list.length, 1);
      expect(list.first.title, 'Chacoalhão!');
    });

    test('markAsRead returns true on success', () async {
      mockApiClient.postResponse = {'s': true};
      final result = await repository.markAsRead(1);
      expect(result, isTrue);
    });
  });
}
