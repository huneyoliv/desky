import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/theme/app_colors.dart';
import 'package:desky/core/theme/app_theme.dart';
import 'package:desky/core/theme/theme_palette.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/theme_notifier.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/widgets/theme_selection_dialog.dart';

void main() {
  group('DeskyThemePalette Model & Presets Tests', () {
    test('all 5 curated presets are defined with unique ids', () {
      expect(DeskyThemePalette.presets.length, equals(5));

      final ids = DeskyThemePalette.presets.map((p) => p.id).toSet();
      expect(ids.length, equals(5));
      expect(ids, containsAll([
        'amoled_lilac',
        'midnight_navy',
        'cyberpunk',
        'forest_emerald',
        'sunset_amber',
      ]));
    });

    test('fromId returns correct preset or defaults to amoled_lilac', () {
      expect(DeskyThemePalette.fromId('midnight_navy').id, equals('midnight_navy'));
      expect(DeskyThemePalette.fromId('cyberpunk').id, equals('cyberpunk'));
      expect(DeskyThemePalette.fromId('forest_emerald').id, equals('forest_emerald'));
      expect(DeskyThemePalette.fromId('sunset_amber').id, equals('sunset_amber'));
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
  });

  group('ThemeSelectionDialog Widget Tests', () {
    testWidgets('renders theme dialog and allows selecting another theme', (tester) async {
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

      // Verify all 5 theme options are rendered
      expect(find.byType(ThemeSelectionDialog), findsOneWidget);
      expect(find.text('AMOLED Lilás (Padrão)'), findsOneWidget);
      expect(find.text('Azul Meia-Noite'), findsOneWidget);
      expect(find.text('Cyberpunk Neon'), findsOneWidget);
      expect(find.text('Verde Esmeralda'), findsOneWidget);
      expect(find.text('Âmbar Dourado'), findsOneWidget);

      // Tap on Midnight Navy theme
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
