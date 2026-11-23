import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/router/app_router.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/models/timetable_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timetable_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/planner/planner_screen.dart';
import 'package:desky/features/planner/timetable_screen.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/shared/widgets/sidebar_nav.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(AuthRepository()) {
    state = AuthState(
      user: UserModel(id: 1, name: 'Test', email: '', jwtToken: ''),
    );
  }
  @override
  Future<void> checkAuthStatus() async {}
}

class _FakePlannerRepository extends PlannerRepository {
  @override
  Future<List<DDayModel>> fetchDDays() async => [];
  @override
  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = 5,
  }) async => [];
}

class _FakeTimetableRepository extends TimetableRepository {
  @override
  Future<List<TimetableBlock>> fetchTimetable() async => [];
}

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: TimerRepository(),
          subjectRepository: SubjectRepository(),
        );
  @override
  Future<void> loadSubjects() async {}
  @override
  Future<void> reconcileWithServer() async {}
  bool _disposed = false;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

void main() {
  testWidgets('/todo redirects to the unified Planner without a duplicate tab',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => _FakeAuthNotifier()),
          timerNotifierProvider.overrideWith((ref) => _OfflineTimerNotifier()),
          plannerRepositoryProvider.overrideWithValue(_FakePlannerRepository()),
          timetableRepositoryProvider.overrideWithValue(
            _FakeTimetableRepository(),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp.router(routerConfig: ref.watch(routerProvider));
          },
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(routerProvider).go('/todo');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PlannerScreen), findsOneWidget);
    expect(SidebarNav.items.any((item) => item.route == '/todo'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
