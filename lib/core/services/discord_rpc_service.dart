import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cdn/cdn_resolver.dart';
import '../config/env_config.dart';
import '../localization/app_translation.dart';
import '../../data/models/user_model.dart';
import '../../features/timer/timer_notifier.dart';

class DiscordPresencePayload {
  final String details;
  final String state;
  final String largeImage;
  final String largeText;
  final String smallImage;
  final String smallText;
  final DateTime? startTime;
  final String? buttonLabel;
  final String? buttonUrl;

  const DiscordPresencePayload({
    required this.details,
    required this.state,
    required this.largeImage,
    required this.largeText,
    required this.smallImage,
    required this.smallText,
    this.startTime,
    this.buttonLabel,
    this.buttonUrl,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscordPresencePayload &&
        other.details == details &&
        other.state == state &&
        other.largeImage == largeImage &&
        other.largeText == largeText &&
        other.smallImage == smallImage &&
        other.smallText == smallText &&
        other.startTime == startTime &&
        other.buttonLabel == buttonLabel &&
        other.buttonUrl == buttonUrl;
  }

  @override
  int get hashCode => Object.hash(
        details,
        state,
        largeImage,
        largeText,
        smallImage,
        smallText,
        startTime,
        buttonLabel,
        buttonUrl,
      );
}

class DiscordRpcService {
  final String _clientId;
  bool _initialized = false;
  bool _connected = false;
  DiscordPresencePayload? _lastPayload;

  DiscordRpcService({String? clientId})
      : _clientId = clientId ?? EnvConfig.discordClientId;

  static String formatStudyDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static DiscordPresencePayload buildPayload({
    required TimerState timerState,
    required UserModel? user,
    required AppTranslation translation,
  }) {
    final isRunning = timerState.isRunning;
    final isPaused = timerState.isPaused;
    final isStudying = isRunning || isPaused;
    final studyMs = timerState.todayTotalMs;
    final studiconId = user?.studiconId ?? (timerState.studiconId > 0 ? timerState.studiconId : -1);
    final hasCustomAvatar = user?.hasCustomAvatar ?? false;
    final userId = user?.id ?? 0;
    final dailyGoalMs = timerState.dailyGoalMinutes * 60 * 1000;

    final avatarUrl = CdnResolver.userAvatarUrl(
      userId: userId,
      hasCustomAvatar: hasCustomAvatar,
      studiconId: studiconId,
      isStudying: isStudying,
      isPaused: isPaused,
      studyMs: studyMs,
      dailyGoalMs: dailyGoalMs,
    );

    final totalTimeFormatted = formatStudyDuration(studyMs);
    final totalTimeLabel = translation.tr('today_study_time', fallback: 'Tempo Total');
    final largeImageTooltip = '$totalTimeLabel: $totalTimeFormatted';

    final stateText = translation.tr('discord_powered_by', fallback: 'Powered by Desky');
    final smallImageTooltip = 'Desky - Focus & Study';

    String detailsText;
    DateTime? startTime;

    if (isRunning) {
      final studyingLabel = translation.tr('discord_studying', fallback: 'Estudando');
      final subjectTitle = timerState.currentSubject?.title;
      detailsText = subjectTitle != null && subjectTitle.isNotEmpty
          ? '$studyingLabel: $subjectTitle'
          : studyingLabel;
      startTime = timerState.sessionStartAt ?? DateTime.now();
    } else if (isPaused) {
      final pausedLabel = translation.tr('discord_paused', fallback: 'Em pausa');
      final subjectTitle = timerState.currentSubject?.title;
      detailsText = subjectTitle != null && subjectTitle.isNotEmpty
          ? '$pausedLabel: $subjectTitle'
          : pausedLabel;
      startTime = null;
    } else {
      detailsText = translation.tr('discord_idle', fallback: 'No Desky');
      startTime = null;
    }

    return DiscordPresencePayload(
      details: detailsText,
      state: stateText,
      largeImage: avatarUrl,
      largeText: largeImageTooltip,
      smallImage: 'desky_logo',
      smallText: smallImageTooltip,
      startTime: startTime,
      buttonLabel: 'Desky',
      buttonUrl: 'https://desky.app',
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        await FlutterDiscordRPC.initialize(_clientId);
        _initialized = true;
      } catch (_) {
        _initialized = false;
      }
    }
  }

  Future<void> connect() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized || _connected) return;
    try {
      await FlutterDiscordRPC.instance.connect();
      _connected = true;
    } catch (_) {
      _connected = false;
    }
  }

  Future<void> updatePresence(DiscordPresencePayload payload) async {
    if (_lastPayload == payload && _connected) return;

    try {
      if (!_connected) {
        await connect();
      }
      if (!_initialized || !_connected) return;

      final buttons = <RPCButton>[];
      if (payload.buttonLabel != null && payload.buttonUrl != null) {
        buttons.add(RPCButton(
          label: payload.buttonLabel!,
          url: payload.buttonUrl!,
        ));
      }

      await FlutterDiscordRPC.instance.setActivity(
        activity: RPCActivity(
          details: payload.details,
          state: payload.state,
          assets: RPCAssets(
            largeImage: payload.largeImage,
            largeText: payload.largeText,
            smallImage: payload.smallImage,
            smallText: payload.smallText,
          ),
          timestamps: payload.startTime != null
              ? RPCTimestamps(start: payload.startTime!.millisecondsSinceEpoch)
              : null,
          buttons: buttons.isNotEmpty ? buttons : null,
        ),
      );

      _lastPayload = payload;
      _connected = true;
    } catch (_) {
      _connected = false;
    }
  }

  Future<void> clearPresence() async {
    _lastPayload = null;
    if (!_initialized || !_connected) return;
    try {
      await FlutterDiscordRPC.instance.clearActivity();
    } catch (_) {
      _connected = false;
    }
  }

  void dispose() {
    if (_initialized) {
      try {
        clearPresence();
        FlutterDiscordRPC.instance.disconnect();
        FlutterDiscordRPC.instance.dispose();
      } catch (_) {}
    }
    _connected = false;
    _initialized = false;
  }
}

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final service = DiscordRpcService();
  ref.onDispose(() => service.dispose());
  return service;
});
