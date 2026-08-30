import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/cdn/cdn_resolver.dart';

void main() {
  group('Studicon and CdnResolver Tests', () {
    test('studiconUrl generates valid CDN URLs for all poses', () {
      expect(CdnResolver.studiconUrl(10, StudiconPose.normal1), equals('https://alicdn.tgclab.com/sc.v2/10/normal1.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.sweat1), equals('https://alicdn.tgclab.com/sc.v2/10/sweat1.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.sweat2), equals('https://alicdn.tgclab.com/sc.v2/10/sweat2.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.sweat3), equals('https://alicdn.tgclab.com/sc.v2/10/sweat3.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.smoke1), equals('https://alicdn.tgclab.com/sc.v2/10/smoke1.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.smoke2), equals('https://alicdn.tgclab.com/sc.v2/10/smoke2.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.ignite1), equals('https://alicdn.tgclab.com/sc.v2/10/ignite1.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.ignite2), equals('https://alicdn.tgclab.com/sc.v2/10/ignite2.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.fire1), equals('https://alicdn.tgclab.com/sc.v2/10/fire1.png'));
      expect(CdnResolver.studiconUrl(10, StudiconPose.explosion1), equals('https://alicdn.tgclab.com/sc.v2/10/explosion1.png'));
    });

    test('resolvePose follows exact 10 time thresholds from official YPT APK', () {
      // Offline / Not studying
      expect(CdnResolver.resolvePose(isStudying: false, studyMs: 10000000), equals(StudiconPose.normal1));

      // Paused
      expect(CdnResolver.resolvePose(isStudying: true, isPaused: true, studyMs: 10000), equals(StudiconPose.smoke1));

      // < 1 hour (< 3.600.000 ms)
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 0), equals(StudiconPose.normal1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 3599999), equals(StudiconPose.normal1));

      // >= 1 hour (3.600.000 ms) -> sweat1
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 3600000), equals(StudiconPose.sweat1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 7199999), equals(StudiconPose.sweat1));

      // >= 2 hours (7.200.000 ms) -> sweat2
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 7200000), equals(StudiconPose.sweat2));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 10799999), equals(StudiconPose.sweat2));

      // >= 3 hours (10.800.000 ms) -> sweat3
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 10800000), equals(StudiconPose.sweat3));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 14399999), equals(StudiconPose.sweat3));

      // >= 4 hours (14.400.000 ms) -> smoke1
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 14400000), equals(StudiconPose.smoke1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 17999999), equals(StudiconPose.smoke1));

      // >= 5 hours (18.000.000 ms) -> smoke2
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 18000000), equals(StudiconPose.smoke2));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 21599999), equals(StudiconPose.smoke2));

      // >= 6 hours (21.600.000 ms) -> ignite1
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 21600000), equals(StudiconPose.ignite1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 25199999), equals(StudiconPose.ignite1));

      // >= 7 hours (25.200.000 ms) -> ignite2
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 25200000), equals(StudiconPose.ignite2));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 28799999), equals(StudiconPose.ignite2));

      // >= 8 hours (28.800.000 ms) -> fire1
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 28800000), equals(StudiconPose.fire1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 35999999), equals(StudiconPose.fire1));

      // >= 10 hours (36.000.000 ms) -> explosion1
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 36000000), equals(StudiconPose.explosion1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 50000000), equals(StudiconPose.explosion1));

      // Daily goal met triggers fire1 (or explosion1 if >= 10h)
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 7200000, dailyGoalMs: 7200000), equals(StudiconPose.fire1));
      expect(CdnResolver.resolvePose(isStudying: true, studyMs: 36000000, dailyGoalMs: 7200000), equals(StudiconPose.explosion1));
    });

    test('defaultStudiconAsset maps poses to official native APK assets', () {
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.normal1, isStudying: false), equals('assets/images/studicon/ic_user_off_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.normal1, isStudying: true), equals('assets/images/studicon/ic_user_on_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.sweat1), equals('assets/images/studicon/ic_user_sweat_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.sweat2), equals('assets/images/studicon/ic_user_sweat_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.sweat3), equals('assets/images/studicon/ic_user_sweat_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.smoke1), equals('assets/images/studicon/ic_user_smoke_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.smoke2), equals('assets/images/studicon/ic_user_smoke_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.ignite1), equals('assets/images/studicon/ic_user_fire_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.ignite2), equals('assets/images/studicon/ic_user_fire_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.fire1), equals('assets/images/studicon/ic_user_fire_s.png'));
      expect(CdnResolver.defaultStudiconAsset(StudiconPose.explosion1), equals('assets/images/studicon/ic_user_fire_s.png'));
    });

    test('userAvatarUrl handles custom avatar and dynamically selects poses', () {
      final customUrl = CdnResolver.userAvatarUrl(
        userId: 12345,
        hasCustomAvatar: true,
        studiconId: 10,
        isStudying: true,
        studyMs: 10000,
      );
      expect(customUrl, equals('https://alicdn.tgclab.com/user/profile/12345.jpg'));

      final fireUrl = CdnResolver.userAvatarUrl(
        userId: 12345,
        hasCustomAvatar: false,
        studiconId: 10,
        isStudying: true,
        studyMs: 28800000,
      );
      expect(fireUrl, contains('/10/fire1.png'));

      final smokeUrl = CdnResolver.userAvatarUrl(
        userId: 12345,
        hasCustomAvatar: false,
        studiconId: 10,
        isStudying: true,
        isPaused: true,
        studyMs: 1000,
      );
      expect(smokeUrl, contains('/10/smoke1.png'));
    });

    test('camStudyUrl and chatPhotoUrl format paths correctly', () {
      expect(CdnResolver.camStudyUrl('2026-08-16', 77), equals('https://alicdn.tgclab.com/cam/2026-08-16/77'));
      expect(CdnResolver.chatPhotoUrl('chat/img_123.jpg'), equals('https://alicdn.tgclab.com/chat/img_123.jpg'));
      expect(CdnResolver.chatPhotoUrl('https://example.com/custom.png'), equals('https://example.com/custom.png'));
    });
  });
}
