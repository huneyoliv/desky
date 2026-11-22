import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/theme/app_colors.dart';
import 'package:desky/core/theme/app_theme.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/theme_notifier.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/widgets/theme_selection_dialog.dart';

void main() {
  group('DeskyThemePalette Model & Presets Tests', () {
    test('all 9 curated presets are defined with unique ids', () {
      expect(DeskyThemePalette.presets.length, equals(9));

      final ids = DeskyThemePalette.presets.map((p) => p.id).toSet();
      expect(ids.length, equals(9));
      expect(ids, containsAll([
        'amoled_lilac',
        'midnight_navy',
        'cyberpunk',
        'forest_emerald',
        'sunset_amber',
        'sakura_pastel',
        'nordic_frost',
        'daylight_lilac',
        'porcelain_sky',
      ]));
    });

    test('fromId returns correct preset or defaults to amoled_lilac', () {
      expect(DeskyThemePalette.fromId('midnight_navy').id, equals('midnight_navy'));
      expect(DeskyThemePalette.fromId('cyberpunk').id, equals('cyberpunk'));
      expect(DeskyThemePalette.fromId('forest_emerald').id, equals('forest_emerald'));
      expect(DeskyThemePalette.fromId('sunset_amber').id, equals('sunset_amber'));
      expect(DeskyThemePalette.fromId('sakura_pastel').id, equals('sakura_pastel'));
      expect(DeskyThemePalette.fromId('nordic_frost').id, equals('nordic_frost'));
      expect(DeskyThemePalette.fromId('amoled_lilac').id, equals('amoled_lilac'));
      expect(DeskyThemePalette.fromId('unknown_id').id, equals('amoled_lilac'));
      expect(DeskyThemePalette.fromId(null).id, equals('amoled_lilac'));
    });

    test('buildTheme configures ThemeData and ThemeExtension accurately', () {
      final navyTheme = AppTheme.buildTheme(DeskyThemePalette.midnightNavy);

      expect(navyTheme.scaffoldBackgroundColor, equals(DeskyThemePalette.midnightNavy.background));
      expect(navyTheme.colorScheme.primary, equals(DeskyThemePalette.midnightNavy.primary));

      final extension = navyTheme.extension<DeskyThemeExtension>();
      expect(extension, isNotNull);
      expect(extension!.palette.id, equals('midnight_navy'));
    });
  });

  group('ThemeNotifier & Persistence Tests', () {
    late SharedPreferences prefs;
    late SettingsRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = SettingsRepository(prefs: prefs);
    });

    test('ThemeNotifier initializes with default theme when no preference stored', () {
      final notifier = ThemeNotifier(repository);
      expect(notifier.state.id, equals('amoled_lilac'));
    });

    test('ThemeNotifier initializes with stored preference', () async {
      await prefs.setString(SettingsRepository.keyThemePreset, 'forest_emerald');
      final notifier = ThemeNotifier(repository);
      expect(notifier.state.id, equals('forest_emerald'));
    });

    test('setTheme updates state and persists theme id', () async {
      final notifier = ThemeNotifier(repository);
      await notifier.setTheme(DeskyThemePalette.sunsetAmber);

      expect(notifier.state.id, equals('sunset_amber'));
      expect(prefs.getString(SettingsRepository.keyThemePreset), equals('sunset_amber'));
    });

    test('setThemeById updates state and persists theme id', () async {
      final notifier = ThemeNotifier(repository);
      await notifier.setThemeById('cyberpunk');

      expect(notifier.state.id, equals('cyberpunk'));
      expect(prefs.getString(SettingsRepository.keyThemePreset), equals('cyberpunk'));
    });

    testWidgets('system mode follows and reacts to operating system brightness',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.keyThemePreset: ThemeNotifier.systemThemeId,
        SettingsRepository.keyDarkThemePreset: 'midnight_navy',
        SettingsRepository.keyLightThemePreset: 'daylight_lilac',
      });
      // Recreate the repository after preparing values: the setUp repository
      // was created with the previous empty mock and already read AMOLED.
      prefs = await SharedPreferences.getInstance();
      repository = SettingsRepository(prefs: prefs);
      final notifier = ThemeNotifier(repository);
      addTearDown(notifier.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(notifier.state.id, 'daylight_lilac');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      // DeskyApp invokes this same callback when the OS reports the change.
      notifier.updateSystemBrightness();
      await tester.pump();
      expect(notifier.state.id, 'midnight_navy');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      notifier.updateSystemBrightness();
      await tester.pump();
      expect(notifier.state.id, 'daylight_lilac');

      // Rehydration keeps the System id and resolves the same persisted pair;
      // reacting to the OS must not turn it into an explicit palette choice.
      final restarted = ThemeNotifier(repository);
      addTearDown(restarted.dispose);
      await tester.pumpAndSettle();
      expect(restarted.isSystemMode, isTrue);
      expect(restarted.state.id, 'daylight_lilac');
      expect(prefs.getString(SettingsRepository.keyThemePreset), 'system');
      addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue,
      );
    });

    test('explicit system choice persists the light/dark pair', () async {
      final notifier = ThemeNotifier(repository);
      await notifier.setTheme(DeskyThemePalette.porcelainSky);
      await notifier.setSystemTheme();

      expect(notifier.isSystemMode, isTrue);
      expect(prefs.getString(SettingsRepository.keyThemePreset), 'system');
      expect(prefs.getString(SettingsRepository.keyLightThemePreset),
          'porcelain_sky');
      expect(prefs.getString(SettingsRepository.keyDarkThemePreset),
          'amoled_lilac');
    });

    test('existing explicit preference never migrates to system automatically',
        () async {
      await prefs.setString(SettingsRepository.keyThemePreset, 'forest_emerald');
      final notifier = ThemeNotifier(repository);
      expect(notifier.isSystemMode, isFalse);
      expect(notifier.state.id, 'forest_emerald');
      expect(prefs.getString(SettingsRepository.keyThemePreset),
          'forest_emerald');
    });
  });

  group('ThemeSelectionDialog Widget Tests', () {
    testWidgets('renders theme dialog and allows selecting another theme', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ThemeSelectionDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 9 palettes and the System option by making every item
      // visible before asserting or tapping it.
      Future<void> expectVisibleText(String text) async {
        await tester.dragUntilVisible(
          find.text(text),
          find.byType(ListView),
          const Offset(0, -120),
        );
        expect(find.text(text), findsOneWidget);
      }

      expect(find.byType(ThemeSelectionDialog), findsOneWidget);
      await expectVisibleText('Sistema');
      await expectVisibleText('AMOLED Lilás (Padrão)');
      await expectVisibleText('Azul Meia-Noite');
      await expectVisibleText('Cyberpunk Neon');
      await expectVisibleText('Verde Esmeralda');
      await expectVisibleText('Âmbar Dourado');
      await expectVisibleText('Sakura Pastel');
      await expectVisibleText('Geada Nórdica');
      await expectVisibleText('Lilás Diurno');
      await expectVisibleText('Céu Porcelana');

      // Tap on Midnight Navy theme after returning it to the viewport.
      await tester.dragUntilVisible(
        find.text('Azul Meia-Noite'),
        find.byType(ListView),
        const Offset(0, 120),
      );
      await tester.tap(find.text('Azul Meia-Noite'));
      await tester.pumpAndSettle();

      // Check that preference is persisted in SharedPreferences
      expect(prefs.getString(SettingsRepository.keyThemePreset), equals('midnight_navy'));
    });

    testWidgets('BuildContext extension and AppColors dynamic accessors match active palette', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(DeskyThemePalette.forestEmerald),
          home: Builder(
            builder: (context) {
              expect(context.appBackground, equals(DeskyThemePalette.forestEmerald.background));
              expect(context.appSurface, equals(DeskyThemePalette.forestEmerald.surface));
              expect(context.appCard, equals(DeskyThemePalette.forestEmerald.card));
              expect(context.appBorder, equals(DeskyThemePalette.forestEmerald.border));
              expect(context.appPrimary, equals(DeskyThemePalette.forestEmerald.primary));
              expect(context.appHeatmapL1, equals(DeskyThemePalette.forestEmerald.heatmapL1));
              expect(context.appHeatmapL4, equals(DeskyThemePalette.forestEmerald.heatmapL4));
              expect(AppColors.bg(context), equals(DeskyThemePalette.forestEmerald.background));
              expect(AppColors.pri(context), equals(DeskyThemePalette.forestEmerald.primary));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
