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
import 'core/diagnostics/crash_log.dart';
import 'core/pdf/macos_document_channel.dart';
import 'core/pdf/pdf_open_request.dart';
import 'core/pdf/single_instance_channel.dart';
import 'core/window/overlay_window_channel.dart';
import 'core/window/window_state.dart';
import 'core/window/window_state_store.dart';
import 'core/services/discord_rpc_coordinator.dart';
import 'core/services/discord_rpc_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/localization/app_translation.dart';
import 'features/auth/auth_notifier.dart';
import 'features/settings/settings_notifier.dart';
import 'features/settings/theme_notifier.dart';
import 'features/timer/focus_mode_notifier.dart';
import 'features/timer/timer_notifier.dart';
import 'shared/widgets/app_title_bar.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep decoded images bounded (default is 100 MB): the app shows many small
  // avatars, so a smaller cache keeps the desktop footprint low.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  // Uncaught errors go, redacted and size-bounded, to crash.log in the app
  // support folder.
  await CrashLog.install();

  // Abrir um PDF pela associacao de arquivos: o caminho chega como argumento.
  final initialPdf = PdfOpenRequest.parse(args);

  // Uma segunda instancia apenas encaminha o arquivo para a que ja esta aberta.
  // Sem argumento, o comportamento de instancia unica e mantido.
  SingleInstanceChannel? instanceChannel;
  if (Platform.isWindows || Platform.isLinux) {
    final singleInstance = await SingleInstanceChannel.startOrForward(
      initialPdf.path ?? '',
    );
    if (singleInstance.shouldExit) {
      // O arquivo foi encaminhado para a instancia aberta; nada mais a fazer.
      exit(0);
    }
    // Em `degraded` o canal e nulo, mas o app continua: sem instancia unica e
    // melhor do que um processo que encerra sem abrir janela nem avisar nada.
    instanceChannel = singleInstance.channel;
  }
  await EnvConfig.init();
  // Linux without a keyring would abort inside the keyring plugin.
  await initSecureStorage();
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
  final storedSize = await windowStateStore.readSize();
  Size? visibleArea;
  var displays = <Rect>[];
  try {
    final all = await screenRetriever.getAllDisplays();
    displays = [
      for (final d in all) (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size),
    ];
    final display = await screenRetriever.getPrimaryDisplay();
    visibleArea = display.visibleSize ?? display.size;
  } catch (_) {
    // Sem informacao do monitor: resolveWindowState usa o tamanho padrao.
  }
  // Reopen on the monitor it was closed on, at the same place; the size is
  // limited by THAT monitor, not the primary one.
  final placement = resolveWindowPlacement(
    storedPosition: await windowStateStore.readPosition(),
    size: storedSize ?? kDefaultWindowSize,
    displays: displays,
  );
  final restoredWindow = resolveWindowState(
    storedSize: storedSize,
    storedMaximized: await windowStateStore.readMaximized(),
    visibleArea: placement.display?.size ?? visibleArea,
  );

  final windowOptions = WindowOptions(
    size: restoredWindow.size,
    minimumSize: restoredWindow.minimumSize,
    center: placement.position == null,
    backgroundColor: Platform.isMacOS ? AppColors.background : Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Desky - Focus & Study Timer',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (Platform.isWindows) {
      await windowManager.setAsFrameless();
    }
    if (placement.position != null) {
      try {
        await windowManager.setBounds(placement.position! & restoredWindow.size);
      } catch (_) {}
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
      child: DeskyApp(
        initialPdf: initialPdf,
        instanceChannel: instanceChannel,
      ),
    ),
  );
}

class DeskyApp extends ConsumerStatefulWidget {
  const DeskyApp({
    super.key,
    this.initialPdf = PdfOpenRequest.none,
    this.instanceChannel,
  });

  /// Pedido de abertura vindo da linha de comando.
  final PdfOpenRequest initialPdf;

  /// Canal de instancia unica, quando este processo e o primario.
  final SingleInstanceChannel? instanceChannel;

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
  Offset? _lastNormalPosition;
  bool _lastMaximized = false;

  /// Abertura de PDF pendente: so navegamos depois de autenticado, porque o
  /// redirect do router manda para /login enquanto a sessao nao estiver pronta.
  PdfOpenRequest? _pendingPdf;
  StreamSubscription<String>? _instanceSub;
  bool _pdfFailureReported = false;

  WindowStateStore get _windowStore =>
      _windowStateStore ??= WindowStateStore(
        prefs: ref.read(sharedPreferencesProvider),
      );

  @override
  void initState() {
    super.initState();
    _pendingPdf = widget.initialPdf.shouldOpen || widget.initialPdf.failed
        ? widget.initialPdf
        : null;
    // macOS: o Finder entrega o documento por Apple Event, nao por argumento.
    MacOsDocumentChannel.listen((path) {
      final request = PdfOpenRequest.parse([path]);
      if (request.shouldOpen) _openPdf(request.path!);
    });
    _instanceSub = widget.instanceChannel?.incoming.listen((payload) {
      // Outra instancia mandou um caminho: trata como novo pedido.
      final request = PdfOpenRequest.parse([payload]);
      if (request.shouldOpen) {
        _openPdf(request.path!);
      }
    });
    _primeWindowState();
    // OBS overlay mode lives in the native runner; keep it in sync.
    ref.listenManual<bool>(
      settingsNotifierProvider.select((s) => s.obsOverlayMode),
      (_, enabled) => OverlayWindowChannel.setOverlayMode(enabled),
      fireImmediately: true,
    );
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

  void _openPdf(String path) {
    if (!mounted) return;
    ref.read(routerProvider).go('/smartbook', extra: path);
  }

  /// Consome o pedido pendente quando a sessao fica autenticada.
  void _flushPendingPdf() {
    final request = _pendingPdf;
    if (request == null) return;
    if (!ref.read(authStateProvider).isAuthenticated) return;
    _pendingPdf = null;
    if (request.shouldOpen) {
      _openPdf(request.path!);
      return;
    }
    if (request.failed && !_pdfFailureReported) {
      _pdfFailureReported = true;
      final t = ref.read(appTranslationProvider);
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t.tr('pdf_open_failed', fallback: 'Could not open the file')}: '
              '\${request.fileName ?? ''}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    _instanceSub?.cancel();
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
        final b = await windowManager.getBounds();
        _lastNormalSize = b.size;
        _lastNormalPosition = b.topLeft;
      }
    } catch (_) {}
  }

  /// Grava o estado com o tamanho "normal": o de uma janela maximizada nunca e
  /// salvo como tamanho de restauracao.
  ///
  /// The position is saved too, so the window reopens on the same monitor and
  /// spot. The mini player and full screen are temporary: their bounds are
  /// never saved over the normal ones.
  Future<void> _saveWindowState() async {
    try {
      final focus = ref.read(focusModeProvider);
      if (focus.isMiniPlayer || focus.isFullscreen) return;
      final maximized = await windowManager.isMaximized();
      if (!maximized) {
        final b = await windowManager.getBounds();
        _lastNormalSize = b.size;
        _lastNormalPosition = b.topLeft;
      }
      _lastMaximized = maximized;
      await _windowStore.save(size: _lastNormalSize, maximized: maximized, position: _lastNormalPosition);
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
  void onWindowMoved() {
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
  void didChangePlatformBrightness() {
    ref.read(themeNotifierProvider.notifier).updateSystemBrightness();
    super.didChangePlatformBrightness();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _handleAppExit();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    // Quando a sessao fica autenticada, abre o PDF que veio por argumento.
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingPdf());
      }
    });
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
