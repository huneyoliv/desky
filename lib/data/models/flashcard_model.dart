import 'package:flutter/material.dart';
import '../../core/utils/color_utils.dart';

class FlashcardDeckModel {
  final int id;
  final String title;
  final String? description;
  final int colorInt;
  final int cardCount;
  final int studiedTodayCount;
  final DateTime createdAt;

  const FlashcardDeckModel({
    required this.id,
    required this.title,
    this.description,
    required this.colorInt,
    this.cardCount = 0,
    this.studiedTodayCount = 0,
    required this.createdAt,
  });

  Color get color => ColorUtils.fromArgbInt(colorInt);

  factory FlashcardDeckModel.fromJson(Map<String, dynamic> json) {
    return FlashcardDeckModel(
      id: json['id'] as int? ?? 0,
      title: json['name'] as String? ?? json['title'] as String? ?? 'Baralho',
      description: json['description'] as String?,
      colorInt: json['color'] as int? ?? 4292557552,
      cardCount: json['card_count'] as int? ?? json['count'] as int? ?? 0,
      studiedTodayCount: json['studied_today'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] is int
              ? json['created_at'] as int
              : DateTime.tryParse(json['created_at'].toString())?.millisecondsSinceEpoch ??
                  DateTime.now().millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'description': description,
      'color': colorInt,
      'card_count': cardCount,
      'studied_today': studiedTodayCount,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  FlashcardDeckModel copyWith({
    int? id,
    String? title,
    String? description,
    int? colorInt,
    int? cardCount,
    int? studiedTodayCount,
    DateTime? createdAt,
  }) {
    return FlashcardDeckModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      colorInt: colorInt ?? this.colorInt,
      cardCount: cardCount ?? this.cardCount,
      studiedTodayCount: studiedTodayCount ?? this.studiedTodayCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FlashcardModel {
  final int id;
  final int deckId;
  final String front;
  final String back;
  final String? hint;
  final int reviewCount;
  final int easeFactor; // e.g. 1 (hard), 2 (good), 3 (easy)
  final bool isMastered;
  final DateTime? lastReviewedAt;

  const FlashcardModel({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.hint,
    this.reviewCount = 0,
    this.easeFactor = 2,
    this.isMastered = false,
    this.lastReviewedAt,
  });

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'] as int? ?? 0,
      deckId: json['book_id'] as int? ?? json['deck_id'] as int? ?? 0,
      front: json['question'] as String? ?? json['front'] as String? ?? '',
      back: json['answer'] as String? ?? json['back'] as String? ?? '',
      hint: json['hint'] as String?,
      reviewCount: json['review_count'] as int? ?? 0,
      easeFactor: json['ease_factor'] as int? ?? 2,
      isMastered: json['is_mastered'] as bool? ?? false,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_reviewed_at'] is int
              ? json['last_reviewed_at'] as int
              : DateTime.tryParse(json['last_reviewed_at'].toString())?.millisecondsSinceEpoch ??
                  DateTime.now().millisecondsSinceEpoch)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': deckId,
      'question': front,
      'answer': back,
      'hint': hint,
      'review_count': reviewCount,
      'ease_factor': easeFactor,
      'is_mastered': isMastered,
      'last_reviewed_at': lastReviewedAt?.millisecondsSinceEpoch,
    };
  }

  FlashcardModel copyWith({
    int? id,
    int? deckId,
    String? front,
    String? back,
    String? hint,
    int? reviewCount,
    int? easeFactor,
    bool? isMastered,
    DateTime? lastReviewedAt,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      reviewCount: reviewCount ?? this.reviewCount,
      easeFactor: easeFactor ?? this.easeFactor,
      isMastered: isMastered ?? this.isMastered,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}
