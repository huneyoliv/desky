import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/profile/profile_screen.dart';

void main() {
  testWidgets('ProfileScreen renders user profile information and settings options', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.pumpWidget(
      ProviderScope(
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
          home: const ProfileScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Estudante Focado'), findsOneWidget);
    expect(find.text('foco@desky.com'), findsOneWidget);
    expect(find.textContaining('Rumo à aprovação!'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsNothing);
  });
}
