class RecurrenceRuleModel {
  final int? id;
  final int frequency;
  final int interval;
  final List<int>? daysOfWeek;
  final String? endDate;

  const RecurrenceRuleModel({
    this.id,
    this.frequency = 1,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
  });

  factory RecurrenceRuleModel.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days_of_week'] ?? json['w'];
    List<int>? days;
    if (rawDays is List) {
      days = rawDays.whereType<num>().map((e) => e.toInt()).toList();
    }

    return RecurrenceRuleModel(
      id: json['id'] as int? ?? json['i'] as int?,
      frequency: json['recurrence_frequency'] as int? ?? json['f'] as int? ?? 1,
      interval: json['recurrence_interval'] as int? ?? json['i'] as int? ?? 1,
      daysOfWeek: days,
      endDate: json['end_date'] as String? ?? json['e'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recurrence_frequency': frequency,
      'recurrence_interval': interval,
      'days_of_week': daysOfWeek,
      'days_of_month': null,
      'start_date': null,
      'end_date': endDate,
      'total_occurrences': null,
    };
  }
}

class TodoItemModel {
  final int id;
  final int? subjectId;
  final String subjectTitle;
  final int subjectColorInt;
  final String title;
  final bool isCompleted;
  final String dateYmd;
  final int? parentId;
  final RecurrenceRuleModel? recurrenceRule;

  const TodoItemModel({
    required this.id,
    this.subjectId,
    required this.subjectTitle,
    required this.subjectColorInt,
    required this.title,
    required this.isCompleted,
    required this.dateYmd,
    this.parentId,
    this.recurrenceRule,
  });

  bool get isRecurring => recurrenceRule != null || (parentId != null && parentId! > 0);

  factory TodoItemModel.fromJson(Map<String, dynamic> json) {
    final title = json['t'] as String? ?? json['title'] as String? ?? '';
    final startAt = json['sa'] as String? ?? json['dateYmd'] as String? ?? '';
    final dateStr = startAt.length >= 10 ? startAt.substring(0, 10) : startAt;
    final score = json['s'];
    final isDone = (score is bool ? score : (score != null && score != 0)) || (json['isCompleted'] as bool? ?? false);

    final rawRr = json['rr'] ?? json['recurrence_rule'];
    RecurrenceRuleModel? rr;
    if (rawRr is Map<String, dynamic>) {
      rr = RecurrenceRuleModel.fromJson(rawRr);
    }

    final parentId = json['p'] as int? ?? json['pi'] as int? ?? json['parent_id'] as int?;

    return TodoItemModel(
      id: json['id'] as int? ?? 0,
      subjectId: json['sd'] as int? ?? json['subjectId'] as int?,
      subjectTitle: json['subjectTitle'] as String? ?? 'Geral',
      subjectColorInt: json['subjectColorInt'] as int? ?? 4292557552,
      title: title,
      isCompleted: isDone,
      dateYmd: dateStr,
      parentId: parentId,
      recurrenceRule: rr,
    );
  }

  TodoItemModel copyWith({
    int? id,
    int? subjectId,
    String? subjectTitle,
    int? subjectColorInt,
    String? title,
    bool? isCompleted,
    String? dateYmd,
    int? parentId,
    RecurrenceRuleModel? recurrenceRule,
  }) {
    return TodoItemModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      subjectColorInt: subjectColorInt ?? this.subjectColorInt,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dateYmd: dateYmd ?? this.dateYmd,
      parentId: parentId ?? this.parentId,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}
