import 'dart:async';

import 'package:desky/data/models/notification_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/features/notifications/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledNotificationRepository extends NotificationRepository {
  int calls = 0;
  final List<Completer<int>> _responses = [];

  @override
  Future<int> fetchUnreadCount() {
    calls++;
    final response = Completer<int>();
    _responses.add(response);
    return response.future;
  }

  void completeCall(int call, int count) {
    _responses[call - 1].complete(count);
  }

  @override
  Future<List<NotificationModel>> fetchNotifications({
    int page = 1,
    bool isNew = false,
  }) async {
    return [];
  }

  @override
  Future<bool> markAllAsRead({Iterable<int> ids = const []}) async => true;
}

Widget _bell(NotificationRepository repository) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: NotificationBell()),
  );
}

void main() {
  testWidgets('polling ticks do not overlap an in-flight unread fetch', (
    tester,
  ) async {
    final repository = _ControlledNotificationRepository();

    await tester.pumpWidget(_bell(repository));
    expect(repository.calls, 1);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(repository.calls, 1);

    repository.completeCall(1, 0);
    await tester.pump();

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(repository.calls, 2);

    repository.completeCall(2, 0);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dispose cancels polling and ignores an in-flight response', (
    tester,
  ) async {
    final repository = _ControlledNotificationRepository();

    await tester.pumpWidget(_bell(repository));
    expect(repository.calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
    expect(repository.calls, 1);

    repository.completeCall(1, 1);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog close queues one refresh behind an in-flight fetch', (
    tester,
  ) async {
    final repository = _ControlledNotificationRepository();

    await tester.pumpWidget(_bell(repository));
    expect(repository.calls, 1);

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    repository.completeCall(1, 0);
    await tester.pump();
    await tester.pump();
    expect(repository.calls, 2);

    await tester.pump(const Duration(seconds: 30));
    expect(repository.calls, 2);

    repository.completeCall(2, 0);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
