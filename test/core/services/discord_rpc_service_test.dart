import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/config/env_config.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/services/discord_rpc_service.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/features/timer/timer_notifier.dart';

void main() {
  group('EnvConfig Discord Client ID Validation', () {
    test('defaultDiscordClientId is a valid snowflake', () {
      expect(EnvConfig.defaultDiscordClientId, matches(RegExp(r'^\d{17,20}$')));
      expect(EnvConfig.defaultDiscordClientId, equals('1545409138211823747'));
    });

    test('discordClientId fallback returns default valid snowflake', () {
      final id = EnvConfig.discordClientId;
      expect(id, matches(RegExp(r'^\d{17,20}$')));
      expect(id, equals(EnvConfig.defaultDiscordClientId));
    });
  });

  group('DiscordRpcService Helper Methods', () {
    test('formatStudyDuration formats milliseconds correctly', () {
      expect(DiscordRpcService.formatStudyDuration(0), equals('00h 00m'));
      expect(DiscordRpcService.formatStudyDuration(60 * 1000), equals('00h 01m'));
      expect(DiscordRpcService.formatStudyDuration(3600 * 1000), equals('01h 00m'));
      expect(DiscordRpcService.formatStudyDuration(5400 * 1000), equals('01h 30m'));
      expect(DiscordRpcService.formatStudyDuration((12 * 3600 + 45 * 60) * 1000), equals('12h 45m'));
    });

    test('buildPayload creates active studying payload with subject and startTime', () {
      const translation = AppTranslation(languageCode: 'pt');
      const subject = SubjectModel(id: 1, title: 'Matemática', colorInt: 0xFF4F46E5, order: 0);
      final startTime = DateTime(2026, 9, 4, 10, 0, 0);
      final timerState = TimerState(
        isRunning: true,
        isPaused: false,
        currentSubject: subject,
        sessionStartAt: startTime,
        todayTotalMs: 3600000,
      );
      const user = UserModel(
        id: 12345,
        name: 'student',
        email: 'student@example.com',
        jwtToken: 'fake_jwt_token',
      );

      final payload = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: user,
        translation: translation,
      );

      expect(payload, isNotNull);
      expect(payload!.details, contains('Matemática'));
      expect(payload.state, equals('Estudando'));
      expect(payload.startTime, isNotNull);
      expect(payload.buttonLabel, equals('Desky'));
      expect(payload.buttonUrl, equals('https://desky.app'));
    });

    test('buildPayload creates paused payload with state Em pausa and without startTime', () {
      const translation = AppTranslation(languageCode: 'pt');
      const subject = SubjectModel(id: 2, title: 'Física', colorInt: 0xFF10B981, order: 1);
      final timerState = TimerState(
        isRunning: false,
        isPaused: true,
        currentSubject: subject,
        todayTotalMs: 1800000,
      );

      final payload = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: null,
        translation: translation,
      );

      expect(payload, isNotNull);
      expect(payload!.details, contains('Física'));
      expect(payload.state, equals('Em pausa'));
      expect(payload.startTime, isNull);
    });

    test('buildPayload returns null when timer is not studying (idle)', () {
      const translation = AppTranslation(languageCode: 'pt');
      final timerState = TimerState();

      final payload = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: null,
        translation: translation,
      );

      expect(payload, isNull);
    });
  });

  group('DiscordRpcService IPC Connection (Live when Discord open)', () {
    test('connect and updatePresence executes successfully without premature timeout', () async {
      final service = DiscordRpcService();
      await service.connect();

      if (Platform.isWindows && service.isConnected) {
        final payload = DiscordPresencePayload(
          details: 'No Desky Test Suite',
          largeImage: 'https://picf.tgclab.com/sc.v2/1/normal1.png',
          largeText: 'Tempo Total: 01h 00m',
          smallImage: 'https://raw.githubusercontent.com/huneyoliv/desky/main/assets/icons/icon.png',
          smallText: 'Desky',
        );
        await service.updatePresence(payload);
        expect(service.isConnected, isTrue);
      }

      service.dispose();
      expect(service.isConnected, isFalse);
    });
  });
}
