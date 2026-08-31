import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/env_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/localization/app_translation.dart';
import 'features/auth/auth_notifier.dart';
import 'features/settings/settings_notifier.dart';
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
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
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

class _DeskyAppState extends ConsumerState<DeskyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).checkAuthStatus();
    });
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
