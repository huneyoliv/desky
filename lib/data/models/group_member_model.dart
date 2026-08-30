import '../../core/cdn/cdn_resolver.dart';
import '../../core/utils/json_utils.dart';

class GroupMemberModel {
  final int userId;
  final String name;
  final int studiconId;
  final bool isStudying;
  final bool isPaused;
  final int studyMs;
  final int? sessionStartMs;
  final bool hasCustomAvatar;
  final String? currentSubject;
  final int? subjectColor;

  const GroupMemberModel({
    required this.userId,
    required this.name,
    required this.studiconId,
    required this.isStudying,
    this.isPaused = false,
    required this.studyMs,
    this.sessionStartMs,
    required this.hasCustomAvatar,
    this.currentSubject,
    this.subjectColor,
  });

  String get avatarUrl => CdnResolver.userAvatarUrl(
        userId: userId,
        hasCustomAvatar: hasCustomAvatar,
        studiconId: studiconId,
        isStudying: isStudying,
        isPaused: isPaused,
        studyMs: studyMs,
      );

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final dl = json['dl'] is Map ? json['dl'] as Map<String, dynamic> : null;
    final isStudying = safeBool(dl?['is'] ?? json['isStudying'] ?? json['is']);
    final isPaused = safeBool(dl?['ia'] ?? dl?['ip'] ?? json['isPaused'] ?? json['ia'] ?? json['ip']);

    int studiconId = safeInt(json['sd'] ?? json['si'] ?? json['studiconID'] ?? json['studiconId'], -1);
    if (studiconId == -1 && json['sm'] != null && json['st'] != null) {
      studiconId = safeInt(json['st'], -1);
    }

    int studyMs;
    if (dl != null && (dl['sm'] != null || dl['tp'] != null)) {
      studyMs = safeInt(dl['sm'] ?? dl['tp'], 0);
    } else if (json['studyMs'] != null || json['sm'] != null) {
      studyMs = safeInt(json['studyMs'] ?? json['sm'], 0);
    } else if (json['st'] != null) {
      final rawSt = safeInt(json['st'], 0);
      studyMs = (rawSt > 0 && rawSt < 500000000) ? rawSt * 1000 : rawSt;
    } else {
      final rawTime = safeInt(
        json['tp'] ?? json['time'] ?? json['totalTime'] ?? json['cnt'] ?? json['duration'],
        0,
      );
      studyMs = (rawTime > 0 && rawTime < 500000000) ? rawTime * 1000 : rawTime;
    }

    final sessionStart = dl?['ss'] != null ? safeInt(dl?['ss']) : null;

    return GroupMemberModel(
      userId: safeInt(json['ud'] ?? json['userId'] ?? json['id']),
      name: safeString(json['n'] ?? json['name'] ?? json['nickname'], 'Membro').trim(),
      studiconId: studiconId,
      isStudying: isStudying,
      isPaused: isPaused,
      studyMs: studyMs,
      sessionStartMs: sessionStart,
      hasCustomAvatar: safeBool(json['hasCustomAvatar']),
      currentSubject: dl?['sn'] != null || dl?['sb'] != null
          ? safeString(dl?['sn'] ?? dl?['sb'])
          : null,
      subjectColor: dl?['co'] != null ? safeInt(dl?['co']) : null,
    );
  }
}
