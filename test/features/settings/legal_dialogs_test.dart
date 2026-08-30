import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/profile/profile_screen.dart';
import 'package:desky/features/settings/widgets/privacy_policy_dialog.dart';
import 'package:desky/features/settings/widgets/terms_of_service_dialog.dart';
import 'package:desky/features/settings/widgets/faq_help_dialog.dart';
import 'package:desky/features/settings/widgets/open_source_licenses_dialog.dart';

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
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('PrivacyPolicyDialog renders sections and dismisses on close', (tester) async {
    await tester.pumpWidget(buildTestWidget(const PrivacyPolicyDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PrivacyPolicyDialog), findsOneWidget);
    expect(find.textContaining('Política de Privacidade'), findsWidgets);
    expect(find.textContaining('Informações que Coletamos'), findsOneWidget);
    expect(find.textContaining('Live Study'), findsWidgets);
  });

  testWidgets('TermsOfServiceDialog renders terms content cleanly', (tester) async {
    await tester.pumpWidget(buildTestWidget(const TermsOfServiceDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TermsOfServiceDialog), findsOneWidget);
    expect(find.textContaining('Termos de Uso'), findsWidgets);
    expect(find.textContaining('Regras da Comunidade'), findsOneWidget);
  });

  testWidgets('FaqHelpDialog renders FAQ accordion tiles', (tester) async {
    await tester.pumpWidget(buildTestWidget(const FaqHelpDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FaqHelpDialog), findsOneWidget);
    expect(find.textContaining('Ajuda'), findsWidgets);
    expect(find.textContaining('Como funciona o Cronômetro'), findsOneWidget);
    expect(find.textContaining('Precisa de suporte'), findsOneWidget);

    await tester.tap(find.textContaining('Precisa de suporte'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('contact@yeolpumta.com'), findsOneWidget);
  });

  testWidgets('OpenSourceLicensesDialog lists packages and licenses', (tester) async {
    await tester.pumpWidget(buildTestWidget(const OpenSourceLicensesDialog()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(OpenSourceLicensesDialog), findsOneWidget);
    expect(find.text('Flutter SDK'), findsOneWidget);
    expect(find.text('flutter_riverpod'), findsOneWidget);
    expect(find.text('dio'), findsOneWidget);
  });

  testWidgets('ProfileScreen shows Legal & Support section and has tiles', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget(const ProfileScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Legal'), findsWidgets);
    expect(find.text('Política de Privacidade'), findsOneWidget);
    expect(find.textContaining('Termos de Uso'), findsOneWidget);
    expect(find.text('Licenças Open Source'), findsOneWidget);
  });
}
