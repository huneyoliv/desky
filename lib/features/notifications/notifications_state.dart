import '../../data/models/notification_model.dart';

class NotificationsState {
  final bool isLoading;
  final String? errorMessage;
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationsState({
    this.isLoading = false,
    this.errorMessage,
    this.notifications = const [],
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<NotificationModel>? notifications,
    int? unreadCount,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
