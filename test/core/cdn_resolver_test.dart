import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/cdn/cdn_resolver.dart';

void main() {
  group('CdnResolver Tests', () {
    test('studiconUrl generates deterministic URLs for poses', () {
      expect(
        CdnResolver.studiconUrl(377, StudiconPose.normal1),
        equals('https://alicdn.tgclab.com/sc.v2/377/normal1.png'),
      );
      expect(
        CdnResolver.studiconUrl(377, StudiconPose.sweat1),
        equals('https://alicdn.tgclab.com/sc.v2/377/sweat1.png'),
      );
      expect(
        CdnResolver.studiconUrl(377, StudiconPose.ignite1),
        equals('https://alicdn.tgclab.com/sc.v2/377/ignite1.png'),
      );
    });

    test('studiconUrl fallback for invalid or negative id', () {
      expect(
        CdnResolver.studiconUrl(-1, StudiconPose.normal1),
        equals('https://alicdn.tgclab.com/sc.v2/-1/normal1.png'),
      );
      expect(
        CdnResolver.studiconUrl(0, StudiconPose.normal1),
        equals('https://alicdn.tgclab.com/sc.v2/-1/normal1.png'),
      );
    });

    test('userAvatarUrl returns custom photo URL if custom avatar is true', () {
      final url = CdnResolver.userAvatarUrl(
        userId: 16300695,
        hasCustomAvatar: true,
        studiconId: 377,
        isStudying: false,
        studyMs: 0,
      );
      expect(url, equals('https://alicdn.tgclab.com/user/profile/16300695.jpg'));
    });

    test('userAvatarUrl resolves pose based on studying state and duration', () {
      // Inactive -> normal1
      final inactiveUrl = CdnResolver.userAvatarUrl(
        userId: 16300695,
        hasCustomAvatar: false,
        studiconId: 377,
        isStudying: false,
        studyMs: 0,
      );
      expect(inactiveUrl, equals('https://alicdn.tgclab.com/sc.v2/377/normal1.png'));

      // Studying < 2h -> sweat1
      final shortStudyUrl = CdnResolver.userAvatarUrl(
        userId: 16300695,
        hasCustomAvatar: false,
        studiconId: 377,
        isStudying: true,
        studyMs: 3600000,
      );
      expect(shortStudyUrl, equals('https://alicdn.tgclab.com/sc.v2/377/sweat1.png'));

      // Studying > 2h (< 3h) -> sweat2
      final longStudyUrl = CdnResolver.userAvatarUrl(
        userId: 16300695,
        hasCustomAvatar: false,
        studiconId: 377,
        isStudying: true,
        studyMs: 7300000,
      );
      expect(longStudyUrl, equals('https://alicdn.tgclab.com/sc.v2/377/sweat2.png'));
    });

    test('camStudyUrl generates camera check URL', () {
      final url = CdnResolver.camStudyUrl('2026-08-09', 16300695);
      expect(url, equals('https://alicdn.tgclab.com/cam/2026-08-09/16300695'));
    });

    test('chatPhotoUrl resolves relative chat photo path', () {
      final url = CdnResolver.chatPhotoUrl('/chat/groups/6487271/thumb.jpg');
      expect(url, equals('https://alicdn.tgclab.com/chat/groups/6487271/thumb.jpg'));
    });

    test('audioUrl resolves audio CDN path', () {
      final url = CdnResolver.audioUrl('music/rain.mp3');
      expect(url, equals('https://alicdn.pallo.cn/music/rain.mp3'));
    });
  });
}
