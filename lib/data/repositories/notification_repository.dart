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

    return [];
  }

  /// Real route from the official binary: `/notice/read` and
  /// `/user/notifications/read-all` answer 404 on the live API.
  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await _apiClient.post(
        '/user/read-notice',
        data: {'noticeID': notificationId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  /// No bulk route exists, so every unread notice is marked individually.
  Future<bool> markAllAsRead({Iterable<int> ids = const []}) async {
    var allOk = true;
    for (final id in ids) {
      final ok = await markAsRead(id);
      if (!ok) allOk = false;
    }
    return allOk;
  }

  /// The API exposes no delete route for user notifications
  /// (`/user/notifications/delete` and `/notice/delete` are 404), so the item is
  /// marked read and hidden locally.
  Future<bool> deleteNotification(int notificationId) async {
    await saveDeletedIds([notificationId]);
    await markAsRead(notificationId);
    return true;
  }

  /// Same as [deleteNotification]: there is no server route, so read notices are
  /// hidden locally.
  Future<bool> deleteAllRead({List<int>? readIds}) async {
    if (readIds != null && readIds.isNotEmpty) {
      await saveDeletedIds(readIds);
    }
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

    // `/notice/unread_count` answers 404; the live counter is
    // `/community/notifications/unread-count` and belongs to the community feed,
    // so the unread notices from `ns` remain the source of truth here.
    return 0;
  }
}
