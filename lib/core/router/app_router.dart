import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/auth/login_screen.dart';
import '../../features/timer/timer_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/planner/planner_screen.dart';
import '../../features/ranks/ranks_screen.dart';
import '../../features/store/store_screen.dart';
import '../../features/flashcards/flashcards_screen.dart';
import '../../features/smartbook/smartbook_screen.dart';
import '../../features/timelapse/timelapse_gallery_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/challenges/challenges_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../shared/widgets/app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(_, GoRouterState state) {
    final isAuthenticated = _ref.read(authStateProvider).isAuthenticated;
    final isLoggingIn = state.matchedLocation == '/login';

    if (!isAuthenticated && !isLoggingIn) return '/login';
    if (isAuthenticated && isLoggingIn) return '/home';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const TimerScreen(),
          ),
          GoRoute(
            path: '/groups',
            builder: (context, state) => const GroupsScreen(),
          ),
          GoRoute(
            path: '/planner',
            builder: (context, state) => const PlannerScreen(),
          ),
          GoRoute(
            path: '/ranks',
            builder: (context, state) => const RanksScreen(),
          ),
          GoRoute(
            path: '/store',
            builder: (context, state) => const StoreScreen(),
          ),
          GoRoute(
            path: '/flashcards',
            builder: (context, state) => const FlashcardsScreen(),
          ),
          GoRoute(
            path: '/smartbook',
            builder: (context, state) => const SmartBookScreen(),
          ),
          GoRoute(
            path: '/timelapse',
            builder: (context, state) => const TimelapseGalleryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/challenges',
            builder: (context, state) => const ChallengesScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});
