import '../../core/utils/json_utils.dart';

/// A single task on the To-Do list.
///
/// The field names mirror what the official app exposes in its own diagnostics
/// (`startAt`, `repeatedWeekDays`, `repeatCount`, task status), so a future sync
/// with the API would not need a translation layer. Everything here is stored
/// locally: the API's creation route answers 500 to every payload and the read
/// route never returned an element, so a server-backed list cannot be built.
class TodoModel {
  const TodoModel({
    required this.id,
    required this.title,
    this.note = '',
    required this.day,
    this.startMinute,
    this.done = false,
    this.completedAt,
    required this.createdAt,
  });

  /// Local identifier: the creation timestamp in milliseconds.
  final int id;
  final String title;
  final String note;

  /// Day the task belongs to, as 'yyyy-MM-dd'. Kept as a string to avoid
  /// timezone drift when the value is only ever compared and displayed.
  final String day;

  /// Minute of the day the task starts at, or null when it has no time.
  final int? startMinute;

  final bool done;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get hasTime => startMinute != null;

  /// 'HH:mm' or empty when the task has no time.
  String get timeLabel {
    final minute = startMinute;
    if (minute == null) return '';
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  TodoModel copyWith({
    String? title,
    String? note,
    String? day,
    int? startMinute,
    bool clearStartMinute = false,
    bool? done,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TodoModel(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      day: day ?? this.day,
      startMinute: clearStartMinute ? null : (startMinute ?? this.startMinute),
      done: done ?? this.done,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
    );
  }

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: safeInt(json['id']),
      title: safeString(json['title']).trim(),
      note: safeString(json['note']),
      day: safeString(json['day']),
      startMinute: json['startMinute'] == null
          ? null
          : safeInt(json['startMinute'], -1) < 0
              ? null
              : safeInt(json['startMinute']),
      done: safeBool(json['done']),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(safeString(json['completedAt'])),
      createdAt: DateTime.tryParse(safeString(json['createdAt'])) ??
          DateTime.fromMillisecondsSinceEpoch(safeInt(json['id'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'day': day,
      'startMinute': startMinute,
      'done': done,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}