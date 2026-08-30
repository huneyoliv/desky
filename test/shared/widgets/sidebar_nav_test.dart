import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/shared/widgets/sidebar_nav.dart';

class FakeTimerNotifier extends TimerNotifier {
  FakeTimerNotifier(TimerState initialState)
      : super(
          timerRepository: TimerRepository(),
          subjectRepository: SubjectRepository(),
        ) {
    state = initialState;
  }
}

void main() {
  testWidgets('SidebarNav does not render Desky branding or static ativas text', (tester) async {
    const mockUser = UserModel(
      id: 1,
      name: 'Estudante Teste',
      email: 'teste@example.com',
      studiconId: 1,
      jwtToken: 'token',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: mockUser),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          unreadNotificationCountProvider.overrideWith((ref) => 0),
          timerNotifierProvider.overrideWith(
            (ref) => FakeTimerNotifier(const TimerState(isRunning: false)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SidebarNav(currentRoute: '/home'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Desky'), findsNothing);
    expect(find.text('Ativas'), findsNothing);
    expect(find.text('Estudante Teste'), findsOneWidget);
    expect(find.text('Inativo'), findsOneWidget);
  });

  testWidgets('SidebarNav turns active/studying when timer is running', (tester) async {
    const mockUser = UserModel(
      id: 1,
      name: 'Estudante Teste',
      email: 'teste@example.com',
      studiconId: 1,
      jwtToken: 'token',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: mockUser),
          ),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          unreadNotificationCountProvider.overrideWith((ref) => 0),
          timerNotifierProvider.overrideWith(
            (ref) => FakeTimerNotifier(const TimerState(isRunning: true, isPaused: false)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SidebarNav(currentRoute: '/home'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Estudando'), findsOneWidget);
    expect(find.text('Inativo'), findsNothing);
  });
}
