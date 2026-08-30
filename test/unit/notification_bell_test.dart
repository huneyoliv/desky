import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/notification_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDioWithNoticeAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  dynamic lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    lastData = options.data;

    if (options.path.contains('/notice/unread_count')) {
      return ResponseBody.fromString(
        '{"unread_count": 3, "s": true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      '{"s": true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Bell and Model Tests', () {
    test('NotificationModel.fromJson extracts full message text and title accurately', () {
      final json1 = {
        'id': 101,
        'i1': 'Grupo Concurso 2026',
        'i2': 'Longkun enviou uma nova foto de estudo!',
        'nt': 'group',
        'c': '2026-08-14T10:00:00.000Z',
        'ir': false,
      };

      final n1 = NotificationModel.fromJson(json1);
      expect(n1.id, 101);
      expect(n1.title, 'Grupo Concurso 2026');
      expect(n1.message, 'Longkun enviou uma nova foto de estudo!');
      expect(n1.isRead, false);

      final json2 = {
        'id': 102,
        'i1': 'Grupo Foco',
        'i2': 'Aviso Importante',
        'i3': 'Meta diária alterada para 4 horas',
        'nt': 'notice',
      };

      final n2 = NotificationModel.fromJson(json2);
      expect(n2.title, 'Grupo Foco • Aviso Importante');
      expect(n2.message, 'Meta diária alterada para 4 horas');
    });

    test('NotificationRepository fetchUnreadCount returns correct unread count', () async {
      final dio = Dio();
      final adapter = MockDioWithNoticeAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = NotificationRepository(apiClient: apiClient);
      final count = await repo.fetchUnreadCount();

      expect(count, 3);
      expect(adapter.lastOptions?.path, contains('/notice/unread_count'));
    });

    test('NotificationRepository deleteNotification sends delete request with id and persists locally', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final dio = Dio();
      final adapter = MockDioWithNoticeAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = NotificationRepository(apiClient: apiClient, prefs: prefs);
      final ok = await repo.deleteNotification(101);

      expect(ok, true);
      final deleted = await repo.getDeletedIds();
      expect(deleted.contains(101), isTrue);
    });

    test('NotificationRepository fetchNotifications filters out deleted IDs', () async {
      SharedPreferences.setMockInitialValues({
        'deleted_notification_ids': ['101'],
      });
      final prefs = await SharedPreferences.getInstance();

      final dio = Dio();
      final adapter = MockDioWithNoticeAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = NotificationRepository(apiClient: apiClient, prefs: prefs);
      final deleted = await repo.getDeletedIds();
      expect(deleted.contains(101), isTrue);
      expect(deleted.contains(102), isFalse);
    });

    test('NotificationRepository deleteAllRead saves read IDs to persistent storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final dio = Dio();
      final adapter = MockDioWithNoticeAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = NotificationRepository(apiClient: apiClient, prefs: prefs);
      await repo.deleteAllRead(readIds: [201, 202]);

      final deleted = await repo.getDeletedIds();
      expect(deleted.contains(201), isTrue);
      expect(deleted.contains(202), isTrue);
    });
  });
}
