import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/services/discord_rpc_service.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DiscordRpcService - Formatting and Helpers', () {
    test('formatStudyDuration formats milliseconds to hours and minutes correctly', () {
      expect(DiscordRpcService.formatStudyDuration(0), '00h 00m');
      expect(DiscordRpcService.formatStudyDuration(60000), '00h 01m');
      expect(DiscordRpcService.formatStudyDuration(3600000), '01h 00m');
      expect(DiscordRpcService.formatStudyDuration(7500000), '02h 05m');
      expect(DiscordRpcService.formatStudyDuration(36000000), '10h 00m');
    });
  });

  group('DiscordRpcService - Payload Construction', () {
    const mockUser = UserModel(
      id: 12345,
      name: 'TestUser',
      email: 'test@example.com',
      studiconId: 1,
      jwtToken: 'mock_jwt_token',
    );

    const mockSubject = SubjectModel(
      id: 10,
      title: 'Matemática',
      colorInt: 4292557552,
    );

    test('buildPayload returns correct Studying state in Portuguese', () {
      final translation = AppTranslation(languageCode: 'pt');
      final sessionStart = DateTime(2026, 9, 4, 8, 0, 0);
      final timerState = TimerState(
        isRunning: true,
        isPaused: false,
        sessionElapsedMs: 1800000, // 30 min
        todayTotalMs: 3600000,      // 1 hour -> sweat1
        currentSubject: mockSubject,
        sessionStartAt: sessionStart,
      );

      final payload = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: mockUser,
        translation: translation,
      );

      expect(payload, isNotNull);
      expect(payload!.details, 'Matemática');
      expect(payload.state, 'Estudando');
      expect(payload.smallImage, contains('assets/icons/icon.png'));
      expect(payload.smallText, 'Desky');
      expect(payload.largeImage, contains('/sc.v2/1/sweat1.png'));
      expect(payload.largeText, contains('01h 00m'));
      expect(payload.startTime, isNotNull);
    });

    test('buildPayload localizes Studying state for other languages', () {
      final sessionStart = DateTime(2026, 9, 4, 8, 0, 0);
      final timerState = TimerState(
        isRunning: true,
        currentSubject: mockSubject,
        sessionStartAt: sessionStart,
      );

      // English
      final payloadEn = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: mockUser,
        translation: const AppTranslation(languageCode: 'en'),
      );
      expect(payloadEn, isNotNull);
      expect(payloadEn!.details, 'Matemática');
      expect(payloadEn.state, 'Studying');

      // Spanish
      final payloadEs = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: mockUser,
        translation: const AppTranslation(languageCode: 'es'),
      );
      expect(payloadEs, isNotNull);
      expect(payloadEs!.details, 'Matemática');
      expect(payloadEs.state, 'Estudiando');

      // Korean
      final payloadKo = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: mockUser,
        translation: const AppTranslation(languageCode: 'ko'),
      );
      expect(payloadKo, isNotNull);
      expect(payloadKo!.details, 'Matemática');
      expect(payloadKo.state, '공부 중');

      // Japanese
      final payloadJa = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: mockUser,
        translation: const AppTranslation(languageCode: 'ja'),
      );
      expect(payloadJa, isNotNull);
      expect(payloadJa!.details, 'Matemática');
      expect(payloadJa.state, '勉強中');

      // Simplified Chinese
      final payloadZh = DiscordRpcService.buildPayload(
        timerState: timerState,
        user: mockUser,
        translation: const AppTranslation(languageCode: 'zh-cn'),
      );
      expect(payloadZh, isNotNull);
      expect(payloadZh!.details, 'Matemática');
      expect(payloadZh.state, '学习中');
    });

    test('buildPayload alters large image according to elapsed time poses', () {
      final translation = AppTranslation(languageCode: 'pt');

      // < 1h -> normal1
      final pNormal = DiscordRpcService.buildPayload(
        timerState: const TimerState(isRunning: true, todayTotalMs: 1800000),
        user: mockUser,
        translation: translation,
      );
      expect(pNormal, isNotNull);
      expect(pNormal!.largeImage, contains('/sc.v2/1/normal1.png'));

      // >= 2h -> sweat2
      final pSweat2 = DiscordRpcService.buildPayload(
        timerState: const TimerState(isRunning: true, todayTotalMs: 7200000),
        user: mockUser,
        translation: translation,
      );
      expect(pSweat2, isNotNull);
      expect(pSweat2!.largeImage, contains('/sc.v2/1/sweat2.png'));

      // >= 4h -> smoke1
      final pSmoke1 = DiscordRpcService.buildPayload(
        timerState: const TimerState(isRunning: true, todayTotalMs: 14400000),
        user: mockUser,
        translation: translation,
      );
      expect(pSmoke1, isNotNull);
      expect(pSmoke1!.largeImage, contains('/sc.v2/1/smoke1.png'));

      // >= 8h -> fire1
      final pFire1 = DiscordRpcService.buildPayload(
        timerState: const TimerState(isRunning: true, todayTotalMs: 28800000),
        user: mockUser,
        translation: translation,
      );
      expect(pFire1, isNotNull);
      expect(pFire1!.largeImage, contains('/sc.v2/1/fire1.png'));

      // >= 10h -> explosion1
      final pExplosion1 = DiscordRpcService.buildPayload(
        timerState: const TimerState(isRunning: true, todayTotalMs: 36000000),
        user: mockUser,
        translation: translation,
      );
      expect(pExplosion1, isNotNull);
      expect(pExplosion1!.largeImage, contains('/sc.v2/1/explosion1.png'));
    });

    test('buildPayload returns correct Paused and Idle states', () {
      final translation = AppTranslation(languageCode: 'pt');

      // Paused state
      final pPaused = DiscordRpcService.buildPayload(
        timerState: const TimerState(
          isRunning: false,
          isPaused: true,
          currentSubject: mockSubject,
        ),
        user: mockUser,
        translation: translation,
      );
      expect(pPaused, isNotNull);
      expect(pPaused!.details, 'Matemática');
      expect(pPaused.state, 'Em pausa');
      expect(pPaused.startTime, isNull);
      expect(pPaused.largeImage, contains('/sc.v2/1/smoke1.png'));

      // Idle state
      final pIdle = DiscordRpcService.buildPayload(
        timerState: const TimerState(isRunning: false, isPaused: false),
        user: mockUser,
        translation: translation,
      );
      expect(pIdle, isNull);
    });
  });

  group('Settings - Discord RPC Preferences', () {
    test('SettingsRepository defaults to true for discordRpcEnabled and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs: prefs);

      // Default value
      expect(await repo.getDiscordRpcEnabled(), isTrue);

      // Save false
      await repo.saveDiscordRpcEnabled(false);
      expect(await repo.getDiscordRpcEnabled(), isFalse);

      // Save true
      await repo.saveDiscordRpcEnabled(true);
      expect(await repo.getDiscordRpcEnabled(), isTrue);
    });

    test('SettingsNotifier toggles discordRpcEnabled and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs: prefs);
      final notifier = SettingsNotifier(repo);

      await notifier.init();
      expect(notifier.state.discordRpcEnabled, isTrue);

      await notifier.toggleDiscordRpc(false);
      expect(notifier.state.discordRpcEnabled, isFalse);
      expect(await repo.getDiscordRpcEnabled(), isFalse);

      await notifier.toggleDiscordRpc(true);
      expect(notifier.state.discordRpcEnabled, isTrue);
      expect(await repo.getDiscordRpcEnabled(), isTrue);
    });
  });
}
