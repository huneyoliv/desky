import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/env_config.dart';
import 'core/window/window_state.dart';
import 'core/window/window_state_store.dart';
import 'core/services/discord_rpc_coordinator.dart';
import 'core/services/discord_rpc_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/localization/app_translation.dart';
import 'features/auth/auth_notifier.dart';
import 'features/settings/settings_notifier.dart';
import 'features/settings/theme_notifier.dart';
import 'features/timer/timer_notifier.dart';
import 'shared/widgets/app_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();
  await initializeDateFormatting();

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Noto Color Emoji'], license);
  });

  // Preload SharedPreferences for instant, synchronous settings and language hydration
  final prefs = await SharedPreferences.getInstance();

  // Initialize Desktop Window Manager
  await windowManager.ensureInitialized();

  // Restaura o tamanho/estado salvos e, principalmente, limita tudo a area util
  // do monitor ATUAL: em telas 720p o tamanho padrao (1280x800) ficava mais alto
  // que a tela e, como a barra de titulo e desenhada pelo app (janela sem
  // moldura), ela abria fora da tela. O mesmo limite protege quem trocou de
  // monitor ou de resolucao desde a ultima execucao.
  final windowStateStore = WindowStateStore(prefs: prefs);
  Size? visibleArea;
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    visibleArea = display.visibleSize ?? display.size;
  } catch (_) {
    // Sem informacao do monitor: resolveWindowState usa o tamanho padrao.
  }
  final restoredWindow = resolveWindowState(
    storedSize: await windowStateStore.readSize(),
    storedMaximized: await windowStateStore.readMaximized(),
    visibleArea: visibleArea,
  );

  final windowOptions = WindowOptions(
    size: restoredWindow.size,
    minimumSize: restoredWindow.minimumSize,
    center: true,
    backgroundColor: Platform.isMacOS ? AppColors.background : Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Desky - Focus & Study Timer',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (Platform.isWindows) {
      await windowManager.setAsFrameless();
    }
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
    if (restoredWindow.maximized) {
      try {
        await windowManager.maximize();
      } catch (_) {}
    }
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

  /// O resize dispara a cada quadro, entao gravar em disco e adiado (debounce).
  static const Duration _windowStateDebounceDelay = Duration(milliseconds: 400);
  Timer? _windowStateDebounce;
  WindowStateStore? _windowStateStore;
  Size _lastNormalSize = kDefaultWindowSize;
  bool _lastMaximized = false;

  WindowStateStore get _windowStore =>
      _windowStateStore ??= WindowStateStore(
        prefs: ref.read(sharedPreferencesProvider),
      );

  @override
  void initState() {
    super.initState();
    _primeWindowState();
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
    _windowStateDebounce?.cancel();
    _sigtermSub?.cancel();
    _sigintSub?.cancel();
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleAppExit() async {
    if (_isExiting) return;
    _isExiting = true;
    // Antes de qualquer coisa: guarda tamanho/estado da janela.
    await _saveWindowState();
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

  Future<void> _primeWindowState() async {
    try {
      _lastMaximized = await windowManager.isMaximized();
      if (!_lastMaximized) {
        _lastNormalSize = await windowManager.getSize();
      }
    } catch (_) {}
  }

  /// Grava o estado com o tamanho "normal": o de uma janela maximizada nunca e
  /// salvo como tamanho de restauracao.
  Future<void> _saveWindowState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (!maximized) {
        _lastNormalSize = await windowManager.getSize();
      }
      _lastMaximized = maximized;
      await _windowStore.save(size: _lastNormalSize, maximized: maximized);
    } catch (_) {}
  }

  void _scheduleWindowStateSave() {
    _windowStateDebounce?.cancel();
    _windowStateDebounce = Timer(_windowStateDebounceDelay, () {
      _saveWindowState();
    });
  }

  @override
  void onWindowResize() {
    _scheduleWindowStateSave();
  }

  @override
  void onWindowMaximize() {
    _lastMaximized = true;
    _saveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _lastMaximized = false;
    _saveWindowState();
  }

  @override
  void onWindowClose() async {
    await _handleAppExit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        ref.read(timerNotifierProvider.notifier).reconcileWithServer();
      } catch (_) {}
    }
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
    final currentPalette = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: 'Desky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(currentPalette),
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
              color: currentPalette.background,
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
