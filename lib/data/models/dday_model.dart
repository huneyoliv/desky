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

  /// The live API serialises a D-Day with compact keys:
  /// `{"id": 9369115, "tt": "QA", "dt": "2026-12-01", "st": null}`
  /// (`tt` = title, `dt` = date). The verbose keys are kept as fallbacks.
  factory DDayModel.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['tt'] ?? json['title'];
    final rawDate = json['dt'] ?? json['targetDate'] ?? json['date'];
    final rawColor = json['color'] ?? json['c'];
    return DDayModel(
      id: _asInt(json['id']),
      title: rawTitle?.toString() ?? 'D-Day',
      targetDate: _parseDate(rawDate),
      colorInt: _asInt(rawColor, 4294948685),
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

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString() ?? '';
    if (text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }
}
