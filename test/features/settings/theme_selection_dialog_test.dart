import 'package:desky/core/theme/app_theme.dart';
import 'package:desky/core/theme/theme_palette.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/theme_notifier.dart';
import 'package:desky/features/settings/widgets/theme_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final initialPalette in [
    DeskyThemePalette.daylightLilac,
    DeskyThemePalette.porcelainSky,
  ]) {
    final targetPalette = initialPalette.id == 'daylight_lilac'
        ? DeskyThemePalette.porcelainSky
        : DeskyThemePalette.daylightLilac;
    final targetName = targetPalette.id == 'daylight_lilac'
        ? 'Lilás Diurno'
        : 'Céu Porcelana';

    testWidgets(
      'real theme dialog scrolls and persists at 640x480: ${initialPalette.id}',
      (tester) async {
        tester.view.physicalSize = const Size(640, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
        addTearDown(
          tester.platformDispatcher.clearPlatformBrightnessTestValue,
        );

        SharedPreferences.setMockInitialValues({
          SettingsRepository.keyThemePreset: initialPalette.id,
          SettingsRepository.keyDarkThemePreset: 'amoled_lilac',
          SettingsRepository.keyLightThemePreset: initialPalette.id,
        });
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: Consumer(
              builder: (context, ref, _) => MaterialApp(
                theme: AppTheme.buildTheme(ref.watch(themeNotifierProvider)),
                home: Scaffold(
                  body: Center(
                    child: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () => ThemeSelectionDialog.show(context),
                        child: const Text('Abrir tema'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Abrir tema'));
        await tester.pumpAndSettle();
        expect(find.byType(ThemeSelectionDialog), findsOneWidget);
        expect(find.text('Sistema'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Sistema'));
        await tester.pumpAndSettle();
        final systemContainer = ProviderScope.containerOf(
          tester.element(find.byType(ThemeSelectionDialog)),
        );
        expect(systemContainer.read(themeNotifierProvider.notifier).isSystemMode, isTrue);
        expect(tester.widget<Text>(find.text('Sistema')).style?.fontWeight, FontWeight.bold);
        expect(
          prefs.getString(SettingsRepository.keyThemePreset),
          ThemeNotifier.systemThemeId,
        );
        expect(
          prefs.getString(SettingsRepository.keyLightThemePreset),
          initialPalette.id,
        );

        await tester.dragUntilVisible(
          find.text(targetName),
          find.byType(ListView),
          const Offset(0, -120),
        );
        await tester.ensureVisible(find.text(targetName));
        await tester.pumpAndSettle();
        expect(find.text(targetName), findsOneWidget);
        await tester.tap(find.text(targetName));
        await tester.pumpAndSettle();

        expect(
          prefs.getString(SettingsRepository.keyThemePreset),
          targetPalette.id,
        );
        expect(
          prefs.getString(SettingsRepository.keyLightThemePreset),
          targetPalette.id,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ThemeSelectionDialog)),
        );
        expect(container.read(themeNotifierProvider.notifier).isSystemMode, isFalse);
        expect(tester.takeException(), isNull);

        final closeButton = find.descendant(
          of: find.byType(ThemeSelectionDialog),
          matching: find.byType(ElevatedButton),
        );
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
        expect(find.byType(ThemeSelectionDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
