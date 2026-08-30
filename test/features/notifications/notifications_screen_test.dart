import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/notification_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/features/notifications/notifications_screen.dart';

class FakeNotificationRepository extends NotificationRepository {
  final List<NotificationModel> _mockItems;

  FakeNotificationRepository(this._mockItems);

  @override
  Future<List<NotificationModel>> fetchNotifications({int page = 1, bool isNew = false}) async {
    return _mockItems;
  }

  @override
  Future<bool> markAsRead(int notificationId) async => true;

  @override
  Future<bool> markAllAsRead() async => true;

  @override
  Future<bool> deleteNotification(int notificationId) async => true;

  @override
  Future<bool> deleteAllRead({List<int>? readIds}) async => true;
}

void main() {
  testWidgets('NotificationsScreen renders notifications list and cards', (tester) async {
    final items = [
      NotificationModel(
        id: 1,
        title: 'Estudo Iniciado',
        message: 'Você começou a estudar Português',
        type: 'study',
        createdAt: DateTime.now(),
        isRead: false,
      ),
      NotificationModel(
        id: 2,
        title: 'Novo Integrante',
        message: 'Ana entrou no Grupo Concursos',
        type: 'group',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
      ),
    ];

    final repo = FakeNotificationRepository(items);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Estudo Iniciado'), findsOneWidget);
    expect(find.text('Você começou a estudar Português'), findsOneWidget);
    expect(find.text('Novo Integrante'), findsOneWidget);
  });

  testWidgets('NotificationsScreen renders empty state when no notifications', (tester) async {
    final repo = FakeNotificationRepository([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
  });
}
