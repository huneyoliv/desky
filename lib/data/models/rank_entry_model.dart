import '../../core/cdn/cdn_resolver.dart';
import '../../core/utils/json_utils.dart';

class RankEntryModel {
  final int rank;
  final int userId;
  final String userName;
  final int studiconId;
  final int studyMs;
  final String categoryName;
  final bool hasCustomAvatar;

  const RankEntryModel({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.studiconId,
    required this.studyMs,
    required this.categoryName,
    this.hasCustomAvatar = false,
  });

  String get avatarUrl => CdnResolver.userAvatarUrl(
        userId: userId,
        hasCustomAvatar: hasCustomAvatar,
        studiconId: studiconId,
        isStudying: false,
        studyMs: studyMs,
      );

  factory RankEntryModel.fromJson(Map<String, dynamic> json, int rankIndex) {
    final dl = json['dl'] is Map<String, dynamic> ? json['dl'] as Map<String, dynamic> : null;
    int studyMs;
    if (dl != null && (dl['sm'] != null || dl['tp'] != null)) {
      studyMs = safeInt(dl['sm'] ?? dl['tp'], 0);
    } else if (json['sm'] != null || json['studyMs'] != null) {
      studyMs = safeInt(json['sm'] ?? json['studyMs'], 0);
    } else {
      final rawTime = safeInt(json['st'] ?? json['tp'] ?? json['time'] ?? json['duration'], 0);
      if (rawTime > 0 && rawTime < 1000000) {
        studyMs = rawTime * 1000;
      } else {
        studyMs = rawTime;
      }
    }

    final studiconId = safeInt(json['sd'] ?? json['si'] ?? (json['sm'] != null ? json['st'] : null) ?? json['studiconID'] ?? json['studiconId'], -1);
    final category = safeString(json['ct'] ?? json['c'], 'Geral');

    return RankEntryModel(
      rank: safeInt(json['rank'], rankIndex),
      userId: safeInt(json['ud'] ?? json['userId']),
      userName: safeString(json['n'] ?? json['userName'], 'Usuário'),
      studiconId: studiconId,
      studyMs: studyMs,
      categoryName: category,
      hasCustomAvatar: safeBool(json['hasCustomAvatar']),
    );
  }
}
