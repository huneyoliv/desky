// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';

class MockTimerRepository extends TimerRepository {
  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
  }) async => true;

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async => {'s': true};
}

class MockSubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String? language,
    String? timezone,
    int? version,
  }) async {
    return const SubjectFetchResult(
      subjects: [
        SubjectModel(id: 1, title: 'Matemática', colorInt: 4292557552),
      ],
      todayTotalMs: 120000,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Timer Tab-Switch State Persistence Tests (Issue #3)', () {
    test('TimerNotifier does not dispose or reset when authStateProvider updates (e.g. group refresh)', () async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final container = ProviderContainer(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial auth state with user
      final authNotifier = container.read(authStateProvider.notifier);
      authNotifier.state = const AuthState(
        user: UserModel(
          id: 10,
          studiconId: 300,
          name: 'Estudante Teste',
          email: 'test@desky.app',
          jwtToken: 'fake_jwt_token',
          userGroups: [],
        ),
      );

      final timerNotifier = container.read(timerNotifierProvider.notifier);
      await timerNotifier.loadSubjects();

      // 2. Start study session
      await timerNotifier.startStudy();
      final initialTimerState = container.read(timerNotifierProvider);
      expect(initialTimerState.isRunning, isTrue);
      expect(initialTimerState.isPaused, isFalse);

      // 3. Simulate navigating to /groups where refreshUserGroups() updates user with groups
      authNotifier.state = authNotifier.state.copyWith(
        user: authNotifier.state.user!.copyWith(
          userGroups: const [
            GroupModel(
              id: 99,
              name: 'Grupo de Estudos',
              category: 'Geral',
              dailyGoalHours: 8,
              membersCount: 5,
              maxCapacity: 50,
              isPrivate: false,
              leaderName: 'Líder Teste',
            ),
          ],
        ),
      );

      // 4. Assert timerNotifierProvider did NOT reset or re-instantiate
      final afterGroupRefreshState = container.read(timerNotifierProvider);
      expect(afterGroupRefreshState.isRunning, isTrue,
          reason: 'Timer must continue running even when authState updates from group refresh');
      expect(afterGroupRefreshState.currentSubject?.id, equals(1));
    });

    test('Wall-clock elapsed time computes exact delta even if ticks are throttled', () async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final container = ProviderContainer(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
        ],
      );
      addTearDown(container.dispose);

      final timerNotifier = container.read(timerNotifierProvider.notifier);
      await timerNotifier.loadSubjects();

      await timerNotifier.startStudy();
      expect(container.read(timerNotifierProvider).isRunning, isTrue);

      // Set sessionStartAt to 15 seconds in the past
      final pastTime = DateTime.now().subtract(const Duration(seconds: 15));
      timerNotifier.state = timerNotifier.state.copyWith(sessionStartAt: pastTime);

      // Wait a moment for periodic tick or invoke directly by starting another second
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final state = container.read(timerNotifierProvider);
      expect(state.sessionElapsedMs, greaterThanOrEqualTo(15000),
          reason: 'Wall-clock elapsed calculation must reflect true difference without losing seconds');
    });

    test('Changing dayResetHour updates notifier via listener without resetting running session', () async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final container = ProviderContainer(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
        ],
      );
      addTearDown(container.dispose);

      final timerNotifier = container.read(timerNotifierProvider.notifier);
      await timerNotifier.loadSubjects();
      await timerNotifier.startStudy();

      expect(container.read(timerNotifierProvider).isRunning, isTrue);

      // Update dayResetHour in settings
      container.read(settingsNotifierProvider.notifier).setDayResetHour(7);

      // Verify timer is still running
      final state = container.read(timerNotifierProvider);
      expect(state.isRunning, isTrue);
    });

    test('User logout properly triggers handleLogout on timer', () async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final container = ProviderContainer(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
        ],
      );
      addTearDown(container.dispose);

      final authNotifier = container.read(authStateProvider.notifier);
      authNotifier.state = const AuthState(
        user: UserModel(
          id: 1,
          studiconId: 10,
          name: 'User',
          email: 'u@test.com',
          jwtToken: 'fake_jwt_token',
        ),
      );

      final timerNotifier = container.read(timerNotifierProvider.notifier);
      await timerNotifier.loadSubjects();
      await timerNotifier.startStudy();

      expect(container.read(timerNotifierProvider).isRunning, isTrue);

      // Simulate logout
      authNotifier.state = const AuthState();

      final stateAfterLogout = container.read(timerNotifierProvider);
      expect(stateAfterLogout.isRunning, isFalse);
      expect(stateAfterLogout.sessionElapsedMs, equals(0));
    });

    testWidgets('Widget navigation between TimerScreen and another screen preserves running state', (tester) async {
      final timerRepo = MockTimerRepository();
      final subjectRepo = MockSubjectRepository();

      final container = ProviderContainer(
        overrides: [
          timerRepositoryProvider.overrideWithValue(timerRepo),
          subjectRepositoryProvider.overrideWithValue(subjectRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Start study in container
      final notifier = container.read(timerNotifierProvider.notifier);
      await notifier.loadSubjects();
      await notifier.startStudy();

      int currentTab = 0; // 0 = Home, 1 = Groups

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: currentTab == 0
                      ? const TimerScreen()
                      : const Center(child: Text('Groups Screen')),
                  bottomNavigationBar: Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => currentTab = 0),
                        child: const Text('Home Tab'),
                      ),
                      TextButton(
                        onPressed: () {
                          // Simulate switching tab and group refresh
                          container.read(authStateProvider.notifier).state = const AuthState(
                            user: UserModel(
                              id: 1,
                              studiconId: 5,
                              name: 'T',
                              email: 't@test.com',
                              jwtToken: 'fake_jwt_token',
                            ),
                          );
                          setState(() => currentTab = 1);
                        },
                        child: const Text('Groups Tab'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // TimerScreen is visible and running
      expect(find.text('PAUSAR'), findsOneWidget);
      expect(find.text('PARAR'), findsOneWidget);
      expect(find.text('INICIAR'), findsNothing);

      // Switch to Groups tab
      await tester.tap(find.text('Groups Tab'));
      await tester.pumpAndSettle();

      expect(find.text('Groups Screen'), findsOneWidget);
      expect(find.text('PAUSAR'), findsNothing);

      // Switch back to Home tab
      await tester.tap(find.text('Home Tab'));
      await tester.pumpAndSettle();

      // Verify TimerScreen is back and still running!
      expect(find.text('PAUSAR'), findsOneWidget);
      expect(find.text('PARAR'), findsOneWidget);
      expect(find.text('INICIAR'), findsNothing);
      expect(container.read(timerNotifierProvider).isRunning, isTrue);
    });
  });
}
