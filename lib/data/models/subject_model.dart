import 'package:flutter/material.dart';
import '../../core/utils/color_utils.dart';

class SubjectModel {
  final int id;
  final String title;
  final int studyMs;
  final int order;
  final int colorInt;
  final bool isDeleted;
  final bool isArchived;

  const SubjectModel({
    required this.id,
    required this.title,
    this.studyMs = 0,
    this.order = 100,
    required this.colorInt,
    this.isDeleted = false,
    this.isArchived = false,
  });

  Color get color => ColorUtils.fromArgbInt(colorInt);

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as int? ?? 0,
      title: json['tt'] as String? ?? 'Sem nome',
      studyMs: json['sm'] as int? ?? 0,
      order: json['or'] as int? ?? 100,
      colorInt: json['co'] as int? ?? 4292557552,
      isDeleted: json['dl'] as bool? ?? false,
      isArchived: json['ia'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tt': title,
      'sm': studyMs,
      'or': order,
      'co': colorInt,
      'dl': isDeleted,
      'ia': isArchived,
    };
  }

  SubjectModel copyWith({
    int? id,
    String? title,
    int? studyMs,
    int? order,
    int? colorInt,
    bool? isDeleted,
    bool? isArchived,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      studyMs: studyMs ?? this.studyMs,
      order: order ?? this.order,
      colorInt: colorInt ?? this.colorInt,
      isDeleted: isDeleted ?? this.isDeleted,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
