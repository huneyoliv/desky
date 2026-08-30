class OfflineSessionModel {
  final String id;
  final int subjectId;
  final String subjectTitle;
  final DateTime startAt;
  final DateTime stopAt;
  final int studyMs;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const OfflineSessionModel({
    required this.id,
    required this.subjectId,
    required this.subjectTitle,
    required this.startAt,
    required this.stopAt,
    required this.studyMs,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory OfflineSessionModel.fromJson(Map<String, dynamic> json) {
    return OfflineSessionModel(
      id: json['id'] as String,
      subjectId: json['subjectId'] as int,
      subjectTitle: json['subjectTitle'] as String,
      startAt: DateTime.fromMillisecondsSinceEpoch(json['startAt'] as int),
      stopAt: DateTime.fromMillisecondsSinceEpoch(json['stopAt'] as int),
      studyMs: json['studyMs'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'subjectTitle': subjectTitle,
      'startAt': startAt.millisecondsSinceEpoch,
      'stopAt': stopAt.millisecondsSinceEpoch,
      'studyMs': studyMs,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  OfflineSessionModel copyWith({
    String? id,
    int? subjectId,
    String? subjectTitle,
    DateTime? startAt,
    DateTime? stopAt,
    int? studyMs,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return OfflineSessionModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      startAt: startAt ?? this.startAt,
      stopAt: stopAt ?? this.stopAt,
      studyMs: studyMs ?? this.studyMs,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
