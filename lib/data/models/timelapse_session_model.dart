import 'dart:convert';

class TimelapseSession {
  final String id;
  final String subjectName;
  final int subjectColorInt;
  final DateTime startTime;
  final int durationSeconds;
  final int frameIntervalSeconds;
  final List<String> framePaths;
  final String? thumbnailPath;

  const TimelapseSession({
    required this.id,
    required this.subjectName,
    required this.subjectColorInt,
    required this.startTime,
    required this.durationSeconds,
    this.frameIntervalSeconds = 5,
    required this.framePaths,
    this.thumbnailPath,
  });

  int get frameCount => framePaths.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectName': subjectName,
      'subjectColorInt': subjectColorInt,
      'startTime': startTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'frameIntervalSeconds': frameIntervalSeconds,
      'framePaths': framePaths,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory TimelapseSession.fromJson(Map<String, dynamic> json) {
    return TimelapseSession(
      id: json['id'] as String,
      subjectName: json['subjectName'] as String? ?? 'Estudo',
      subjectColorInt: json['subjectColorInt'] as int? ?? 4292557552,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      frameIntervalSeconds: json['frameIntervalSeconds'] as int? ?? 5,
      framePaths: (json['framePaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static TimelapseSession decode(String source) =>
      TimelapseSession.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
