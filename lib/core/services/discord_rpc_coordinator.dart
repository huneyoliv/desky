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
      if (_ref.read(settingsNotifierProvider).discordRpcEnabled) {
        await _rpcService.initialize();
      }
      _syncPresence();
    });

    // Timer ticks: the service drops duplicates and rate limits updates.
    _ref.listen<TimerState>(timerNotifierProvider, (prev, next) {
      _syncPresence();
    });

    // Login/logout, equipped studicon.
    _ref.listen<AuthState>(authStateProvider, (prev, next) {
      _syncPresence();
    });

    _ref.listen<SettingsState>(settingsNotifierProvider, (prev, next) {
      if (prev?.discordRpcEnabled != next.discordRpcEnabled) {
        if (!next.discordRpcEnabled) {
          // Off means off: close the connection so nothing lingers on Discord.
          _rpcService.disconnect();
          return;
        }
        _syncPresence();
      } else if (prev?.selectedLanguage != next.selectedLanguage) {
        _syncPresence();
      }
    });

    _ref.listen<AppTranslation>(appTranslationProvider, (prev, next) {
      _syncPresence();
    });
  }

  void _syncPresence() {
    final settings = _ref.read(settingsNotifierProvider);
    if (!settings.discordRpcEnabled) return;

    final authState = _ref.read(authStateProvider);
    final user = authState.user;
    if (!authState.isAuthenticated || user == null) {
      _rpcService.setPresence(null);
      return;
    }

    _rpcService.setPresence(DiscordRpcService.buildPayload(
      timerState: _ref.read(timerNotifierProvider),
      user: user,
      translation: _ref.read(appTranslationProvider),
    ));
  }
}

final discordRpcCoordinatorProvider = Provider<DiscordRpcCoordinator>((ref) {
  final rpcService = ref.watch(discordRpcServiceProvider);
  return DiscordRpcCoordinator(ref, rpcService);
});
