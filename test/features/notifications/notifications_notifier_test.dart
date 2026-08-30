import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/notification_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/features/notifications/notifications_notifier.dart';

class FakeNotificationRepository extends NotificationRepository {
  List<NotificationModel> mockNotifications;
  bool markAsReadCalled = false;
  bool markAllAsReadCalled = false;
  bool deleteNotificationCalled = false;
  bool deleteAllReadCalled = false;
  int? lastDeletedId;
  int? lastReadId;

  FakeNotificationRepository(this.mockNotifications);

  @override
  Future<List<NotificationModel>> fetchNotifications({int page = 1, bool isNew = false}) async {
    return mockNotifications;
  }

  @override
  Future<bool> markAsRead(int notificationId) async {
    markAsReadCalled = true;
    lastReadId = notificationId;
    return true;
  }

  @override
  Future<bool> markAllAsRead() async {
    markAllAsReadCalled = true;
    return true;
  }

  @override
  Future<bool> deleteNotification(int notificationId) async {
    deleteNotificationCalled = true;
    lastDeletedId = notificationId;
    return true;
  }

  List<int>? lastDeletedReadIds;

  @override
  Future<bool> deleteAllRead({List<int>? readIds}) async {
    deleteAllReadCalled = true;
    lastDeletedReadIds = readIds;
    return true;
  }
}

void main() {
  final sampleNotifications = [
    NotificationModel(
      id: 1,
      title: 'Despertador de Estudo',
      message: 'Hora de estudar Cálculo!',
      type: 'study',
      createdAt: DateTime.now(),
      isRead: false,
    ),
    NotificationModel(
      id: 2,
      title: 'Grupo de Estudos',
      message: 'Novo membro entrou no grupo',
      type: 'group',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
    NotificationModel(
      id: 3,
      title: 'Conquista Desbloqueada',
      message: 'Você atingiu 5 horas diárias!',
      type: 'achievement',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      isRead: false,
    ),
  ];

  group('NotificationsNotifier Tests', () {
    test('loadNotifications sets notifications and unreadCount correctly', () async {
      final repo = FakeNotificationRepository(List.from(sampleNotifications));
      final notifier = NotificationsNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.notifications.length, equals(3));
      expect(notifier.state.unreadCount, equals(2));
    });

    test('markAsRead updates isRead and unreadCount', () async {
      final repo = FakeNotificationRepository(List.from(sampleNotifications));
      final notifier = NotificationsNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.markAsRead(1);

      expect(notifier.state.notifications.firstWhere((n) => n.id == 1).isRead, isTrue);
      expect(notifier.state.unreadCount, equals(1));
      expect(repo.markAsReadCalled, isTrue);
      expect(repo.lastReadId, equals(1));
    });

    test('markAllAsRead marks all notifications as read and resets unreadCount to 0', () async {
      final repo = FakeNotificationRepository(List.from(sampleNotifications));
      final notifier = NotificationsNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.markAllAsRead();

      expect(notifier.state.notifications.every((n) => n.isRead), isTrue);
      expect(notifier.state.unreadCount, equals(0));
      expect(repo.markAllAsReadCalled, isTrue);
    });

    test('deleteNotification removes notification and recalculates unreadCount', () async {
      final repo = FakeNotificationRepository(List.from(sampleNotifications));
      final notifier = NotificationsNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.deleteNotification(1);

      expect(notifier.state.notifications.length, equals(2));
      expect(notifier.state.notifications.any((n) => n.id == 1), isFalse);
      expect(notifier.state.unreadCount, equals(1));
      expect(repo.deleteNotificationCalled, isTrue);
      expect(repo.lastDeletedId, equals(1));
    });

    test('deleteAllRead removes only read notifications', () async {
      final repo = FakeNotificationRepository(List.from(sampleNotifications));
      final notifier = NotificationsNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.deleteAllRead();

      expect(notifier.state.notifications.length, equals(2));
      expect(notifier.state.notifications.every((n) => !n.isRead), isTrue);
      expect(notifier.state.unreadCount, equals(2));
      expect(repo.deleteAllReadCalled, isTrue);
      expect(repo.lastDeletedReadIds, equals([2]));
    });
  });
}
