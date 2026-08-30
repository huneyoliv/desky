import '../constants/api_constants.dart';

enum StudiconPose {
  mini('mini.png'),
  normal1('normal1.png'),
  sweat1('sweat1.png'),
  sweat2('sweat2.png'),
  sweat3('sweat3.png'),
  ignite1('ignite1.png'),
  ignite2('ignite2.png'),
  smoke1('smoke1.png'),
  smoke2('smoke2.png'),
  fire1('fire1.png'),
  explosion1('explosion1.png'),
  app('app.png');

  final String fileName;
  const StudiconPose(this.fileName);
}

class CdnResolver {
  CdnResolver._();

  static String studiconUrl(int studiconId, StudiconPose pose) {
    final safeId = studiconId <= 0 ? -1 : studiconId;
    return '${ApiConstants.mediaCdnUrl}/sc.v2/$safeId/${pose.fileName}';
  }

  /// Resolves the character pose based on study state, pause state, and study time.
  /// Follows the exact bytecode thresholds from the official YPT application:
  /// - < 1h: normal1
  /// - >= 1h (3.600.000 ms): sweat1
  /// - >= 2h (7.200.000 ms): sweat2
  /// - >= 3h (10.800.000 ms): sweat3
  /// - >= 4h (14.400.000 ms): smoke1
  /// - >= 5h (18.000.000 ms): smoke2
  /// - >= 6h (21.600.000 ms): ignite1
  /// - >= 7h (25.200.000 ms): ignite2
  /// - >= 8h (28.800.000 ms): fire1
  /// - >= 10h (36.000.000 ms): explosion1
  static StudiconPose resolvePose({
    required bool isStudying,
    bool isPaused = false,
    required int studyMs,
    int dailyGoalMs = 0,
  }) {
    if (!isStudying) {
      return StudiconPose.normal1;
    }
    if (isPaused) {
      return StudiconPose.smoke1;
    }
    if (dailyGoalMs > 0 && studyMs >= dailyGoalMs) {
      return studyMs >= 36000000 ? StudiconPose.explosion1 : StudiconPose.fire1;
    }
    if (studyMs >= 36000000) return StudiconPose.explosion1; // >= 10h
    if (studyMs >= 28800000) return StudiconPose.fire1;      // >= 8h
    if (studyMs >= 25200000) return StudiconPose.ignite2;    // >= 7h
    if (studyMs >= 21600000) return StudiconPose.ignite1;    // >= 6h
    if (studyMs >= 18000000) return StudiconPose.smoke2;     // >= 5h
    if (studyMs >= 14400000) return StudiconPose.smoke1;     // >= 4h
    if (studyMs >= 10800000) return StudiconPose.sweat3;     // >= 3h
    if (studyMs >= 7200000) return StudiconPose.sweat2;      // >= 2h
    if (studyMs >= 3600000) return StudiconPose.sweat1;      // >= 1h
    return StudiconPose.normal1;                             // < 1h
  }

  /// Maps a pose to the official native YPT default character asset.
  static String defaultStudiconAsset(
    StudiconPose pose, {
    bool isStudying = true,
  }) {
    if (!isStudying && pose == StudiconPose.normal1) {
      return 'assets/images/studicon/ic_user_off_s.png';
    }

    switch (pose) {
      case StudiconPose.sweat1:
      case StudiconPose.sweat2:
      case StudiconPose.sweat3:
        return 'assets/images/studicon/ic_user_sweat_s.png';
      case StudiconPose.smoke1:
      case StudiconPose.smoke2:
        return 'assets/images/studicon/ic_user_smoke_s.png';
      case StudiconPose.ignite1:
      case StudiconPose.ignite2:
      case StudiconPose.fire1:
      case StudiconPose.explosion1:
        return 'assets/images/studicon/ic_user_fire_s.png';
      case StudiconPose.normal1:
      case StudiconPose.mini:
      case StudiconPose.app:
        return isStudying
            ? 'assets/images/studicon/ic_user_on_s.png'
            : 'assets/images/studicon/ic_user_off_s.png';
    }
  }

  static String userAvatarUrl({
    required int userId,
    required bool hasCustomAvatar,
    required int studiconId,
    required bool isStudying,
    bool isPaused = false,
    required int studyMs,
    int dailyGoalMs = 0,
  }) {
    if (hasCustomAvatar) {
      return '${ApiConstants.mediaCdnUrl}/user/profile/$userId.jpg';
    }

    final pose = resolvePose(
      isStudying: isStudying,
      isPaused: isPaused,
      studyMs: studyMs,
      dailyGoalMs: dailyGoalMs,
    );

    return studiconUrl(studiconId, pose);
  }

  static String camStudyUrl(String dateYmd, int userId) {
    return '${ApiConstants.mediaCdnUrl}/cam/$dateYmd/$userId';
  }

  static String chatPhotoUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return '${ApiConstants.mediaCdnUrl}$path';
  }

  static String audioUrl(String path) {
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConstants.audioCdnUrl}/$cleanPath';
  }
}
