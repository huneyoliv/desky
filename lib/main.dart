import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/env_config.dart';
import 'core/services/discord_rpc_coordinator.dart';
import 'core/services/discord_rpc_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/localization/app_translation.dart';
import 'features/auth/auth_notifier.dart';
import 'features/settings/settings_notifier.dart';
import 'features/timer/timer_notifier.dart';
import 'shared/widgets/app_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();
  await initializeDateFormatting();

  // Preload SharedPreferences for instant, synchronous settings and language hydration
  final prefs = await SharedPreferences.getInstance();

  // Initialize Desktop Window Manager
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1024, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Desky - Focus & Study Timer',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
  });

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DeskyApp(),
    ),
  );
}

class DeskyApp extends ConsumerStatefulWidget {
  const DeskyApp({super.key});

  @override
  ConsumerState<DeskyApp> createState() => _DeskyAppState();
}

class _DeskyAppState extends ConsumerState<DeskyApp>
    with WindowListener, WidgetsBindingObserver {
  bool _isExiting = false;
  StreamSubscription<ProcessSignal>? _sigtermSub;
  StreamSubscription<ProcessSignal>? _sigintSub;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    _setupSignalHandlers();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setPreventClose(true);
      } catch (_) {}
      ref.read(authStateProvider.notifier).checkAuthStatus();
      ref.read(discordRpcCoordinatorProvider);
    });
  }

  void _setupSignalHandlers() {
    if (!Platform.isWindows) {
      try {
        _sigtermSub = ProcessSignal.sigterm.watch().listen((_) async {
          await _handleAppExit();
        });
        _sigintSub = ProcessSignal.sigint.watch().listen((_) async {
          await _handleAppExit();
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sigtermSub?.cancel();
    _sigintSub?.cancel();
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleAppExit() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      final timerNotifier = ref.read(timerNotifierProvider.notifier);
      final timerState = ref.read(timerNotifierProvider);
      final hasActiveSession = timerState.isRunning ||
          timerState.isPaused ||
          timerState.sessionStartAt != null ||
          (timerState.sessionElapsedMs - timerState.lastSyncedSessionElapsedMs > 0);

      if (hasActiveSession) {
        await timerNotifier.stopStudy().timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
      }
    } catch (_) {}

    try {
      final rpcService = ref.read(discordRpcServiceProvider);
      await rpcService.clearPresence();
      rpcService.dispose();
    } catch (_) {}

    try {
      await windowManager.destroy();
    } catch (_) {}

    exit(0);
  }

  @override
  void onWindowClose() async {
    await _handleAppExit();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _handleAppExit();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final translation = ref.watch(appTranslationProvider);

    return MaterialApp.router(
      title: 'Desky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: Locale(translation.languageCode.split('-').first),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('pt'),
        Locale('en', 'US'),
        Locale('en'),
        Locale('es', 'ES'),
        Locale('es'),
        Locale('ko', 'KR'),
        Locale('ko'),
        Locale('ja', 'JP'),
        Locale('ja'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('zh'),
      ],
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: DragToResizeArea(
            child: Material(
              color: AppColors.background,
              clipBehavior: Clip.antiAlias,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Column(
                      children: [
                        const AppTitleBar(title: 'Desky'),
                        Expanded(child: child ?? const SizedBox.shrink()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
