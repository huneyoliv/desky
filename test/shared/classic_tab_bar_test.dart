import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/shared/widgets/classic_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _bar(String route) => ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWith((ref) async => 3),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: ClassicTabBar(currentRoute: route))),
    );

void main() {
  testWidgets('the Notice tab pings with the unread count', (tester) async {
    tester.view.physicalSize = const Size(1600, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_bar('/home'));
    await tester.pump();
    expect(find.byKey(const ValueKey('classic-tab-/notifications')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(_bar('/notifications'));
    await tester.pump();
    expect(find.text('3'), findsNothing, reason: 'no ping while reading them');
  });
}
