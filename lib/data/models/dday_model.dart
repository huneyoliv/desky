import 'package:flutter/material.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/study_date_helper.dart';

class DDayModel {
  final int id;
  final String title;
  final DateTime targetDate;
  final int colorInt;

  const DDayModel({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.colorInt,
  });

  Color get color => ColorUtils.fromArgbInt(colorInt);

  int get daysRemaining {
    final now = DateTime.now();
    final today = StudyDateHelper.getStudyDate(now);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  String get label {
    final days = daysRemaining;
    if (days > 0) return 'D-$days';
    if (days == 0) return 'D-DAY';
    return 'D+${-days}';
  }

  factory DDayModel.fromJson(Map<String, dynamic> json) {
    return DDayModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'D-Day',
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'] as String)
          : DateTime.now(),
      colorInt: json['color'] as int? ?? 4294948685,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'targetDate': targetDate.toIso8601String(),
      'color': colorInt,
    };
  }
}
