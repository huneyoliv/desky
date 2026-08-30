class TimetableBlock {
  final int id;
  final int subjectId;
  final String subjectTitle;
  final int colorInt;
  final int dayOfWeek;
  final int startHour;
  final int endHour;

  const TimetableBlock({
    required this.id,
    required this.subjectId,
    required this.subjectTitle,
    required this.colorInt,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
  });

  factory TimetableBlock.fromJson(Map<String, dynamic> json) {
    return TimetableBlock(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subjectId: (json['subject_id'] ?? json['subjectId'] as num?)?.toInt() ?? 0,
      subjectTitle: (json['subject_title'] ?? json['subjectTitle'] ?? 'Matéria').toString(),
      colorInt: (json['color'] ?? json['colorInt'] as num?)?.toInt() ?? 4292557552,
      dayOfWeek: (json['day_of_week'] ?? json['dayOfWeek'] as num?)?.toInt() ?? 1,
      startHour: (json['start_hour'] ?? json['startHour'] as num?)?.toInt() ?? 8,
      endHour: (json['end_hour'] ?? json['endHour'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'subject_title': subjectTitle,
      'color': colorInt,
      'day_of_week': dayOfWeek,
      'start_hour': startHour,
      'end_hour': endHour,
    };
  }
}
