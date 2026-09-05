import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/settings/settings_notifier.dart';
import '../../features/settings/settings_state.dart';
import '../../features/timer/timer_notifier.dart';
import '../localization/app_translation.dart';
import 'discord_rpc_service.dart';

class DiscordRpcCoordinator {
  final Ref _ref;
  final DiscordRpcService _rpcService;

  DiscordRpcCoordinator(this._ref, this._rpcService) {
    _init();
  }

  void _init() {
    Future.microtask(() async {
      await _rpcService.initialize();
      _syncPresence();
    });

    // Listen to changes in timer state
    _ref.listen<TimerState>(timerNotifierProvider, (prev, next) {
      _syncPresence();
    });

    // Listen to auth state changes (e.g. login, equip studicon)
    _ref.listen<AuthState>(authStateProvider, (prev, next) {
      _syncPresence();
    });

    // Listen to settings changes (e.g. toggle RPC, language change)
    _ref.listen<SettingsState>(settingsNotifierProvider, (prev, next) {
      if (prev?.discordRpcEnabled != next.discordRpcEnabled ||
          prev?.selectedLanguage != next.selectedLanguage) {
        _syncPresence();
      }
    });

    // Listen to translation changes
    _ref.listen<AppTranslation>(appTranslationProvider, (prev, next) {
      _syncPresence();
    });
  }

  void _syncPresence() {
    final settings = _ref.read(settingsNotifierProvider);
    if (!settings.discordRpcEnabled) {
      _rpcService.clearPresence();
      return;
    }

    final authState = _ref.read(authStateProvider);
    final user = authState.user;
    if (!authState.isAuthenticated || user == null) {
      _rpcService.clearPresence();
      return;
    }

    final timerState = _ref.read(timerNotifierProvider);
    if (!timerState.isRunning && !timerState.isPaused) {
      _rpcService.clearPresence();
      return;
    }

    final translation = _ref.read(appTranslationProvider);

    final payload = DiscordRpcService.buildPayload(
      timerState: timerState,
      user: user,
      translation: translation,
    );

    if (payload == null) {
      _rpcService.clearPresence();
      return;
    }

    _rpcService.updatePresence(payload);
  }
}

final discordRpcCoordinatorProvider = Provider<DiscordRpcCoordinator>((ref) {
  final rpcService = ref.watch(discordRpcServiceProvider);
  return DiscordRpcCoordinator(ref, rpcService);
});
