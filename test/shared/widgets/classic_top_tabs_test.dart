import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/shared/widgets/classic_top_tabs.dart';
import 'package:desky/shared/widgets/sidebar_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClassicTopTabs.activeRouteFor', () {
    test('maps every sidebar route, and detail pages, to their tab', () {
      for (final item in SidebarNav.items) {
        expect(ClassicTopTabs.activeRouteFor(item.route), item.route);
      }
      expect(ClassicTopTabs.activeRouteFor('/groups/12'), '/groups');
      expect(ClassicTopTabs.activeRouteFor('/groupsx'), isNull);
      expect(ClassicTopTabs.activeRouteFor('/login'), isNull);
    });
  });

  testWidgets('shows one tab per sidebar item and navigates with the same routes', (tester) async {
    tester.view.physicalSize = const Size(2400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: Column(
              children: [
                ClassicTopTabs(currentRoute: state.uri.path),
                Expanded(child: child),
              ],
            ),
          ),
          routes: [
            for (final item in SidebarNav.items)
              GoRoute(
                path: item.route,
                builder: (context, state) => Text('page ${item.route}'),
              ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => AuthNotifier(AuthRepository())
              ..state = const AuthState(
                user: UserModel(id: 1, name: 'T', email: 't@example.com', studiconId: 1, jwtToken: 'x'),
              ),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
          ),
          unreadNotificationCountProvider.overrideWith((ref) => 0),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    for (final item in SidebarNav.items) {
      expect(find.byKey(ValueKey('classic-top-tab-${item.route}')), findsOneWidget);
    }
    expect(find.text('page /home'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('classic-top-tab-/groups')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('page /groups'), findsOneWidget);
  });

  test('the top tabs setting is off by default and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs: prefs);
    expect(await repo.getClassicTopTabs(), isFalse);
    await repo.saveClassicTopTabs(true);
    expect(await repo.getClassicTopTabs(), isTrue);
    expect(prefs.getBool(SettingsRepository.keyClassicTopTabs), isTrue);
  });
}
