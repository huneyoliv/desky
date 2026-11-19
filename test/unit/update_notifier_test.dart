import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/constants/app_constants.dart';
import 'package:desky/core/services/update_service.dart';
import 'package:desky/features/updates/models/update_model.dart';
import 'package:desky/features/updates/update_notifier.dart';
import 'package:dio/dio.dart';

class FakeUpdateService extends UpdateService {
  AppRelease? simulatedRelease;
  bool shouldThrow = false;
  bool? lastBetaChannel;
  int channelCalls = 0;

  FakeUpdateService({this.simulatedRelease});

  @override
  Future<AppRelease?> fetchLatestRelease({CancelToken? cancelToken}) async {
    if (shouldThrow) {
      throw Exception('Server unreachable');
    }
    return simulatedRelease;
  }

  @override
  Future<AppRelease?> fetchReleaseForChannel({
    required bool betaChannel,
    CancelToken? cancelToken,
  }) async {
    lastBetaChannel = betaChannel;
    channelCalls++;
    return fetchLatestRelease(cancelToken: cancelToken);
  }
}

void main() {
  group('UpdateNotifier Tests', () {
    test('initializes and triggers update check', () async {
      final fakeRelease = const AppRelease(
        id: 10,
        tagName: 'v1.2.0',
        name: 'Desky 1.2.0',
        body: 'Improvements',
        htmlUrl: 'https://github.com',
      );

      final service = FakeUpdateService(simulatedRelease: fakeRelease);
      final notifier = UpdateNotifier(service: service, currentVersion: '1.0.0');

      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(notifier.state.hasUpdate, isTrue);
      expect(notifier.state.latestRelease?.tagName, 'v1.2.0');
      expect(notifier.state.isChecking, isFalse);
    });

    test('detects when app is up to date', () async {
      final fakeRelease = const AppRelease(
        id: 10,
        tagName: 'v1.0.0',
        name: 'Desky 1.0.0',
        body: 'Current version',
        htmlUrl: 'https://github.com',
      );

      final service = FakeUpdateService(simulatedRelease: fakeRelease);
      final notifier = UpdateNotifier(service: service, currentVersion: '1.0.0');

      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(notifier.state.hasUpdate, isFalse);
      expect(notifier.state.latestRelease?.tagName, 'v1.0.0');
    });

    test('default constructor uses AppConstants.appVersion and marks as up to date', () async {
      final fakeRelease = AppRelease(
        id: 1,
        tagName: 'v${AppConstants.appVersion}',
        name: 'Desky ${AppConstants.appVersion}',
        body: 'Release notes',
        htmlUrl: 'https://github.com',
      );

      final service = FakeUpdateService(simulatedRelease: fakeRelease);
      final notifier = UpdateNotifier(service: service);

      expect(notifier.state.currentVersion, AppConstants.appVersion);

      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(notifier.state.hasUpdate, isFalse);
      expect(notifier.state.latestRelease?.tagName, 'v${AppConstants.appVersion}');
    });

    test('handles errors during update check', () async {
      final service = FakeUpdateService();
      service.shouldThrow = true;

      final notifier = UpdateNotifier(service: service, currentVersion: '1.0.0');
      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(notifier.state.errorMessage, isNotNull);
      expect(notifier.state.hasUpdate, isFalse);
      expect(notifier.state.isChecking, isFalse);
    });

    test('canal beta e repassado ao servico', () async {
      final service = FakeUpdateService(
        simulatedRelease: const AppRelease(
          id: 12,
          tagName: 'v1.2.0-beta.2',
          name: 'Desky 1.2.0-beta.2',
          body: 'Beta',
          htmlUrl: 'https://github.com',
        ),
      );

      final notifier = UpdateNotifier(
        service: service,
        currentVersion: '1.2.0-beta.1',
        betaChannel: true,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(service.lastBetaChannel, isTrue);
      // beta.2 e maior que beta.1: o canal beta precisa oferecer a atualizacao.
      expect(notifier.state.hasUpdate, isTrue);
    });

    test('alternar o canal refaz a checagem', () async {
      final service = FakeUpdateService(
        simulatedRelease: const AppRelease(
          id: 13,
          tagName: 'v1.2.0-beta.1',
          name: 'Desky 1.2.0-beta.1',
          body: 'Beta',
          htmlUrl: 'https://github.com',
        ),
      );

      final notifier = UpdateNotifier(service: service, currentVersion: '1.1.7');
      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(service.lastBetaChannel, isFalse);

      await notifier.setBetaChannel(true);
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(service.lastBetaChannel, isTrue);
      expect(notifier.betaChannel, isTrue);
    });

    test('setBetaChannel com o mesmo valor nao refaz a checagem', () async {
      final service = FakeUpdateService(
        simulatedRelease: const AppRelease(
          id: 14,
          tagName: 'v1.2.0',
          name: 'Desky 1.2.0',
          body: 'Estavel',
          htmlUrl: 'https://github.com',
        ),
      );

      final notifier = UpdateNotifier(service: service, currentVersion: '1.1.7');
      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await notifier.setBetaChannel(false);

      expect(service.channelCalls, equals(1),
          reason: 'so a checagem inicial; sem mudanca de canal, nenhuma outra');
      expect(notifier.betaChannel, isFalse);
    });
  });
}
