import 'dart:io';

import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/services/discord_rpc_service.dart';
import 'package:desky/core/services/update_service.dart';
import 'package:desky/core/theme/theme_palette.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/theme_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/updates/models/update_model.dart';
import 'package:desky/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widget_test.dart' show TestHttpOverrides;

class _OfflineAuthNotifier extends AuthNotifier {
  _OfflineAuthNotifier() : super(AuthRepository());

  @override
  Future<void> checkAuthStatus() async {}
}

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: TimerRepository(),
          subjectRepository: SubjectRepository(),
        );

  @override
  Future<void> loadSubjects() async {}

  @override
  Future<void> reconcileWithServer() async {}

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class _OfflineUpdateService extends UpdateService {
  @override
  Future<AppRelease?> fetchLatestRelease({CancelToken? cancelToken}) async =>
      null;

  @override
  Future<AppRelease?> fetchReleaseForChannel({
    required bool betaChannel,
    CancelToken? cancelToken,
  }) async =>
      null;
}

List<Override> _offlineOverrides(SharedPreferences prefs) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authStateProvider.overrideWith((ref) => _OfflineAuthNotifier()),
    timerNotifierProvider.overrideWith((ref) => _OfflineTimerNotifier()),
    appTranslationProvider.overrideWith(
      (ref) => AppTranslationNotifier(ref)
        ..state = const AppTranslation(languageCode: 'pt'),
    ),
    updateServiceProvider.overrideWithValue(_OfflineUpdateService()),
    discordRpcServiceProvider.overrideWith((ref) {
      // An empty client id is the service's existing no-op/offline path.
      final service = DiscordRpcService(clientId: '');
      ref.onDispose(service.dispose);
      return service;
    }),
  ];
}

void _expectAppPalette(
  WidgetTester tester,
  DeskyThemePalette palette,
) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  final theme = app.theme;
  expect(theme, isNotNull);
  expect(
    theme!.extension<DeskyThemeExtension>()?.palette.id,
    palette.id,
  );
  expect(theme.brightness, palette.brightness);
  expect(theme.scaffoldBackgroundColor, palette.background);
  expect(theme.colorScheme.surface, palette.surface);
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  group('DeskyApp platform brightness observer', () {
    late HttpOverrides? previousOverrides;

    setUp(() {
      previousOverrides = HttpOverrides.current;
      HttpOverrides.global = TestHttpOverrides();
    });

    tearDown(() {
      HttpOverrides.global = previousOverrides;
    });

    for (final lightPalette in [
      DeskyThemePalette.daylightLilac,
      DeskyThemePalette.porcelainSky,
    ]) {
      testWidgets(
        'dispatcher alone rebuilds System mode with ${lightPalette.id}',
        (tester) async {
          _useDesktopViewport(tester);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          SharedPreferences.setMockInitialValues({
            SettingsRepository.keyThemePreset: ThemeNotifier.systemThemeId,
            SettingsRepository.keyDarkThemePreset: 'midnight_navy',
            SettingsRepository.keyLightThemePreset: lightPalette.id,
          });
          final prefs = await SharedPreferences.getInstance();
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.light;

          await tester.pumpWidget(
            ProviderScope(
              overrides: _offlineOverrides(prefs),
              child: const DeskyApp(),
            ),
          );
          await tester.pumpAndSettle();
          _expectAppPalette(tester, lightPalette);

          // Deliberately do not call ThemeNotifier.updateSystemBrightness().
          // The setter injects a Flutter dispatcher notification; DeskyApp's
          // WidgetsBindingObserver must forward it and rebuild MaterialApp.
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          await tester.pump();
          _expectAppPalette(tester, DeskyThemePalette.midnightNavy);

          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.light;
          await tester.pump();
          _expectAppPalette(tester, lightPalette);
          expect(
            prefs.getString(SettingsRepository.keyThemePreset),
            ThemeNotifier.systemThemeId,
          );
          expect(
            prefs.getString(SettingsRepository.keyLightThemePreset),
            lightPalette.id,
          );

          await _unmountApp(tester);
        },
      );
    }

    testWidgets('dispatcher does not override an explicit light palette',
        (tester) async {
      _useDesktopViewport(tester);
      addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      SharedPreferences.setMockInitialValues({
        SettingsRepository.keyThemePreset: 'porcelain_sky',
        SettingsRepository.keyDarkThemePreset: 'midnight_navy',
        SettingsRepository.keyLightThemePreset: 'porcelain_sky',
      });
      final prefs = await SharedPreferences.getInstance();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _offlineOverrides(prefs),
          child: const DeskyApp(),
        ),
      );
      await tester.pumpAndSettle();
      _expectAppPalette(tester, DeskyThemePalette.porcelainSky);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      _expectAppPalette(tester, DeskyThemePalette.porcelainSky);
      expect(
        prefs.getString(SettingsRepository.keyThemePreset),
        'porcelain_sky',
      );

      await _unmountApp(tester);
    });
  });
}
