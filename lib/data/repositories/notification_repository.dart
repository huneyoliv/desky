import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.fetchUnreadCount();
});

class NotificationRepository {
  final ApiClient _apiClient;
  final SharedPreferences? _prefs;

  static const String keyDeletedNoticeIds = 'deleted_notification_ids';

  NotificationRepository({
    ApiClient? apiClient,
    SharedPreferences? prefs,
  })  : _apiClient = apiClient ?? ApiClient(),
        _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<Set<int>> getDeletedIds() async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList(keyDeletedNoticeIds) ?? [];
      return list.map((s) => int.tryParse(s)).whereType<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDeletedIds(Iterable<int> ids) async {
    try {
      final prefs = await _getPrefs();
      final current = (prefs.getStringList(keyDeletedNoticeIds) ?? [])
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toSet();
      current.addAll(ids);
      await prefs.setStringList(
        keyDeletedNoticeIds,
        current.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<List<NotificationModel>> fetchNotifications({int page = 1, bool isNew = false}) async {
    final deletedIds = await getDeletedIds();

    try {
      final response = await _apiClient.get(
        '/user/notifications?page=$page&is_new=$isNew',
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final list = data['ns'] ?? data['notices'] ?? data['list'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => NotificationModel.fromJson(item))
              .where((item) => !deletedIds.contains(item.id))
              .toList();
        }
      }
    } catch (_) {}

    try {
      final response = await _apiClient.get('/notice/list');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['ns'] ?? data['notices'] ?? data['list'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => NotificationModel.fromJson(item))
              .where((item) => !deletedIds.contains(item.id))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await _apiClient.post(
        '/notice/read',
        data: {'noticeID': notificationId, 'id': notificationId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiClient.post(
        '/user/notifications/read-all',
        data: {'all': true},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}

    try {
      final response = await _apiClient.post('/notice/read-all');
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> deleteNotification(int notificationId) async {
    await saveDeletedIds([notificationId]);
    await markAsRead(notificationId);

    try {
      await _apiClient.post(
        '/user/notifications/delete',
        data: {'id': notificationId, 'noticeID': notificationId},
      );
    } catch (_) {}

    try {
      await _apiClient.post(
        '/notice/delete',
        data: {'id': notificationId},
      );
    } catch (_) {}

    return true;
  }

  Future<bool> deleteAllRead({List<int>? readIds}) async {
    if (readIds != null && readIds.isNotEmpty) {
      await saveDeletedIds(readIds);
    }

    try {
      await _apiClient.post('/user/notifications/delete-read');
    } catch (_) {}

    return true;
  }

  Future<int> fetchUnreadCount() async {
    final deletedIds = await getDeletedIds();

    try {
      final response = await _apiClient.get('/user/notifications?page=1&is_new=true');
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final list = data['ns'] ?? data['notices'] ?? data['list'];
        if (list is List) {
          final items = list
              .whereType<Map<String, dynamic>>()
              .map((item) => NotificationModel.fromJson(item))
              .where((item) => !deletedIds.contains(item.id) && !item.isRead);
          return items.length;
        }
      }
    } catch (_) {}

    try {
      final response = await _apiClient.get('/notice/unread_count');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['unread_count'] ?? data['cnt'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
