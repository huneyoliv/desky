import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/update_service.dart';
import '../settings/settings_notifier.dart';
import 'models/update_model.dart';

import '../../core/utils/package_helper.dart';

class UpdateState {
  final String currentVersion;
  final bool isChecking;
  final bool hasUpdate;
  final AppRelease? latestRelease;
  final String? errorMessage;
  final DateTime? lastCheckedAt;

  const UpdateState({
    this.currentVersion = AppConstants.appVersion,
    this.isChecking = false,
    this.hasUpdate = false,
    this.latestRelease,
    this.errorMessage,
    this.lastCheckedAt,
  });

  UpdateState copyWith({
    String? currentVersion,
    bool? isChecking,
    bool? hasUpdate,
    AppRelease? latestRelease,
    String? errorMessage,
    DateTime? lastCheckedAt,
    bool clearError = false,
  }) {
    return UpdateState(
      currentVersion: currentVersion ?? this.currentVersion,
      isChecking: isChecking ?? this.isChecking,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      latestRelease: latestRelease ?? this.latestRelease,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _service;
  CancelToken? _cancelToken;

  /// Whether checks should include pre-releases. Mutable so flipping the
  /// setting re-checks through the new channel without recreating the notifier.
  bool betaChannel;

  UpdateNotifier({
    required UpdateService service,
    String currentVersion = AppConstants.appVersion,
    this.betaChannel = false,
  })  : _service = service,
        super(UpdateState(currentVersion: currentVersion)) {
    if (!PackageHelper.isStoreOrMsix) {
      checkForUpdates();
    }
  }

  /// Switches channel and re-checks, so the badge reflects the new channel
  /// immediately instead of waiting for the next app start.
  Future<void> setBetaChannel(bool value) async {
    if (betaChannel == value) return;
    betaChannel = value;
    if (PackageHelper.isStoreOrMsix) return;
    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    if (PackageHelper.isStoreOrMsix) return;
    if (state.isChecking) return;

    state = state.copyWith(isChecking: true, clearError: true);
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final release = await _service.fetchReleaseForChannel(
        betaChannel: betaChannel,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;

      if (release == null) {
        state = state.copyWith(
          isChecking: false,
          lastCheckedAt: DateTime.now(),
        );
        return;
      }

      final hasUpdate = release.isNewerThan(state.currentVersion);

      state = state.copyWith(
        isChecking: false,
        hasUpdate: hasUpdate,
        latestRelease: release,
        lastCheckedAt: DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isChecking: false,
        errorMessage: e.toString(),
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}

final updateNotifierProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final service = ref.watch(updateServiceProvider);
  final betaChannel = ref.watch(
    settingsNotifierProvider.select((settings) => settings.betaChannel),
  );
  final notifier = UpdateNotifier(
    service: service,
    betaChannel: betaChannel,
  );
  // Keep the notifier in sync when the user flips the toggle.
  ref.listen<bool>(
    settingsNotifierProvider.select((settings) => settings.betaChannel),
    (_, next) => notifier.setBetaChannel(next),
  );
  return notifier;
});
