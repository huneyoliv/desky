import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/notification_repository.dart';
import 'notifications_state.dart';

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationsNotifier(repository);
});

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationRepository _repository;

  NotificationsNotifier(this._repository) : super(const NotificationsState()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repository.fetchNotifications();
      final unread = items.where((n) => !n.isRead).length;
      state = state.copyWith(
        isLoading: false,
        notifications: items,
        unreadCount: unread,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final updated = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final unread = updated.where((n) => !n.isRead).length;
    state = state.copyWith(notifications: updated, unreadCount: unread);

    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated, unreadCount: 0);

    await _repository.markAllAsRead();
  }

  Future<void> deleteNotification(int notificationId) async {
    final updated = state.notifications.where((n) => n.id != notificationId).toList();
    final unread = updated.where((n) => !n.isRead).length;
    state = state.copyWith(notifications: updated, unreadCount: unread);

    await _repository.deleteNotification(notificationId);
  }

  Future<void> deleteAllRead() async {
    final readIds = state.notifications.where((n) => n.isRead).map((n) => n.id).toList();
    final updated = state.notifications.where((n) => !n.isRead).toList();
    state = state.copyWith(notifications: updated, unreadCount: updated.length);

    await _repository.deleteAllRead(readIds: readIds);
  }
}
