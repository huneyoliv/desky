import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/widgets/change_password_dialog.dart';
import 'package:desky/features/settings/widgets/study_preferences_dialog.dart';
import 'package:desky/features/settings/widgets/blocked_users_dialog.dart';
import 'package:desky/features/profile/profile_screen.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    const mockUser = UserModel(
      id: 1,
      name: 'Estudante Focado',
      email: 'foco@desky.com',
      statusMessage: 'Rumo à aprovação!',
      categoryName: 'Medicina',
      studiconId: 1,
      jwtToken: 'dummy_token',
      flamesBalance: 150,
    );

    return ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
        authStateProvider.overrideWith(
          (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: mockUser),
        ),
        settingsNotifierProvider.overrideWith(
          (ref) => SettingsNotifier(SettingsRepository()),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ChangePasswordDialog renders input fields and validates length', (tester) async {
    await tester.pumpWidget(buildTestWidget(const ChangePasswordDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ChangePasswordDialog), findsOneWidget);
    expect(find.textContaining('Alterar Senha'), findsWidgets);

    // Tap save without filling
    await tester.tap(find.text('Salvar'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('preencha todos os campos'), findsOneWidget);
  });

  testWidgets('StudyPreferencesDialog toggles options and selects reset hour', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget(const StudyPreferencesDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(StudyPreferencesDialog), findsOneWidget);
    expect(find.textContaining('Preferências de Estudo'), findsWidgets);
    expect(find.textContaining('Início do Dia de Estudo'), findsOneWidget);
    expect(find.textContaining('Exibir Tempo de Descanso'), findsOneWidget);
    expect(find.textContaining('Notificações de Cutucada'), findsOneWidget);
  });

  testWidgets('BlockedUsersDialog allows adding and unblocking users', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget(const BlockedUsersDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BlockedUsersDialog), findsOneWidget);
    expect(find.textContaining('Usuários Bloqueados'), findsWidgets);
    expect(find.textContaining('Você não tem nenhum usuário bloqueado'), findsOneWidget);

    // Enter nickname and block
    await tester.enterText(find.byType(TextField), 'spammer_user');
    await tester.tap(find.text('Bloquear'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('spammer_user'), findsOneWidget);
    expect(find.text('Desbloquear'), findsOneWidget);

    // Unblock
    await tester.tap(find.text('Desbloquear'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Você não tem nenhum usuário bloqueado'), findsOneWidget);
  });

  testWidgets('ProfileScreen shows Account Security and Study Preferences', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget(const ProfileScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Segurança da Conta'), findsWidgets);
    expect(find.textContaining('Preferências de Estudo'), findsWidgets);
    expect(find.text('Alterar Senha'), findsOneWidget);
    expect(find.text('Usuários Bloqueados'), findsOneWidget);
  });
}
