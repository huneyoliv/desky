const int _defaultTimetableColor = 0xFFA78BFA;

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _parseHour(dynamic value) {
  if (value is num) return value.toInt().clamp(0, 24);
  final text = value?.toString() ?? '';
  final match = RegExp(r'^(\d{1,2})(?::\d{2})?').firstMatch(text);
  if (match != null) {
    return (int.tryParse(match.group(1)!) ?? 0).clamp(0, 24);
  }
  return DateTime.tryParse(text)?.hour ?? 0;
}

int _parseColor(dynamic value) {
  if (value is num) return value.toInt();
  final text = value?.toString() ?? '';
  final hex = text.startsWith('#') ? text.substring(1) : text;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return _defaultTimetableColor;
  return hex.length == 6 ? 0xFF000000 | parsed : parsed;
}

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
      id: _asInt(json['id'] ?? json['timetable_id'] ?? json['block_id']),
      subjectId: _asInt(json['subject_id'] ?? json['scid']),
      subjectTitle:
          (json['subject_title'] ?? json['subject'] ?? json['t'] ?? '').toString(),
      colorInt: _parseColor(json['color']),
      dayOfWeek: _asInt(json['day_of_week'] ?? json['lw']),
      startHour: _parseHour(json['start_hour'] ?? json['st']),
      endHour: _parseHour(json['end_hour'] ?? json['et']),
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
