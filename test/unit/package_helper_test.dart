import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/utils/package_helper.dart';
import 'package:desky/features/updates/update_notifier.dart';
import 'package:desky/core/services/update_service.dart';
import 'package:desky/features/updates/models/update_model.dart';
import 'package:dio/dio.dart';

class FakeUpdateService implements UpdateService {
  int fetchCalls = 0;

  @override
  Future<AppRelease?> fetchLatestRelease({CancelToken? cancelToken}) async {
    fetchCalls++;
    return const AppRelease(
      id: 99,
      tagName: 'v2.0.0',
      name: 'v2.0.0',
      body: 'New release',
      htmlUrl: 'https://github.com',
    );
  }
}

void main() {
  group('PackageHelper & Store Update Suppression Tests', () {
    tearDown(() {
      PackageHelper.isStoreOrMsixOverride = null;
    });

    test('PackageHelper respects isStoreOrMsixOverride', () {
      PackageHelper.isStoreOrMsixOverride = true;
      expect(PackageHelper.isStoreOrMsix, isTrue);

      PackageHelper.isStoreOrMsixOverride = false;
      expect(PackageHelper.isStoreOrMsix, isFalse);
    });

    test('UpdateNotifier suppresses update checks in Store / MSIX environment', () async {
      PackageHelper.isStoreOrMsixOverride = true;
      final service = FakeUpdateService();
      final notifier = UpdateNotifier(service: service);

      expect(notifier.state.hasUpdate, isFalse);
      expect(notifier.state.isChecking, isFalse);
      expect(service.fetchCalls, 0);

      await notifier.checkForUpdates();
      expect(service.fetchCalls, 0);
    });

    test('UpdateNotifier allows update checks in non-store environment', () async {
      PackageHelper.isStoreOrMsixOverride = false;
      final service = FakeUpdateService();
      final notifier = UpdateNotifier(service: service);

      await Future.delayed(const Duration(milliseconds: 20));
      while (notifier.state.isChecking) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(notifier.state.hasUpdate, isTrue);
      expect(service.fetchCalls, 1);
    });

    test('PackageHelper returns boolean when running on host', () {
      PackageHelper.isStoreOrMsixOverride = null;
      expect(PackageHelper.isStoreOrMsix, isA<bool>());
    });
  });
}
