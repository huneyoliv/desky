import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/timer/focus_mode_notifier.dart';
import 'package:desky/shared/widgets/app_shell.dart';

void main() {
  testWidgets('AppShell shows sidebar when not in focus mode', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          focusModeProvider.overrideWith((ref) => FocusModeNotifier()),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const AppShell(
            currentRoute: '/timer',
            child: Text('Timer Screen Body'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Timer Screen Body'), findsOneWidget);
    expect(find.text('Sair do Foco'), findsNothing);
  });

  testWidgets('AppShell hides sidebar and shows exit button in strict focus mode', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final focusNotifier = FocusModeNotifier();
    await focusNotifier.toggleStrictFocus();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          focusModeProvider.overrideWith((ref) => focusNotifier),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const AppShell(
            currentRoute: '/timer',
            child: Text('Timer Screen Body'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Timer Screen Body'), findsOneWidget);
    expect(find.text('Sair do Foco'), findsOneWidget);
  });
}
