import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/oauth/oauth_user_info.dart';
import 'package:desky/features/auth/login_screen.dart';
import 'package:desky/features/auth/signup_screen.dart';

void main() {
  testWidgets('LoginScreen displays Account Not Found confirmation dialog correctly', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify LoginScreen loaded
    expect(find.byType(LoginScreen), findsOneWidget);

    final state = tester.state<LoginScreenState>(find.byType(LoginScreen));
    const fakeOAuthUser = OAuthUserInfo(
      provider: 'Google',
      socialId: '1234567890',
      email: 'novousuario@gmail.com',
      name: 'Novo Usuário',
    );

    state.showAccountNotFoundDialog(state.context, fakeOAuthUser);
    await tester.pumpAndSettle();

    // Verify dialog elements
    expect(find.text('Conta não encontrada'), findsOneWidget);
    expect(find.textContaining('novousuario@gmail.com'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Criar Conta'), findsOneWidget);

    // Tap "Criar Conta"
    await tester.tap(find.text('Criar Conta'));
    await tester.pumpAndSettle();

    // Verify SignUpScreen opened
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Concluir Cadastro'), findsOneWidget);
  });

  testWidgets('Account Not Found dialog can be dismissed with Cancelar', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final state = tester.state<LoginScreenState>(find.byType(LoginScreen));
    const fakeOAuthUser = OAuthUserInfo(
      provider: 'Google',
      socialId: '1234567890',
      email: 'outro@gmail.com',
      name: 'Outro Usuário',
    );

    state.showAccountNotFoundDialog(state.context, fakeOAuthUser);
    await tester.pumpAndSettle();

    expect(find.text('Conta não encontrada'), findsOneWidget);

    // Tap "Cancelar"
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Verify dialog dismissed and still on LoginScreen
    expect(find.text('Conta não encontrada'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignUpScreen), findsNothing);
  });
}
