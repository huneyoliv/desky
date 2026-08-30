import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/utils/color_utils.dart';
import 'package:desky/data/models/subject_model.dart';

void main() {
  group('SubjectModel Tests', () {
    test('fromJson and toJson parse subject attributes correctly', () {
      final json = {
        'id': 100,
        'tt': 'Matemática Avançada',
        'sm': 18000000,
        'or': 1,
        'co': 4292557552,
        'dl': false,
        'ia': false,
      };

      final subject = SubjectModel.fromJson(json);
      expect(subject.id, equals(100));
      expect(subject.title, equals('Matemática Avançada'));
      expect(subject.studyMs, equals(18000000));
      expect(subject.order, equals(1));
      expect(subject.colorInt, equals(4292557552));
      expect(subject.isDeleted, isFalse);
      expect(subject.isArchived, isFalse);

      final exported = subject.toJson();
      expect(exported['id'], equals(100));
      expect(exported['tt'], equals('Matemática Avançada'));
      expect(exported['sm'], equals(18000000));
      expect(exported['co'], equals(4292557552));
    });

    test('ColorUtils converts ARGB integer to Color correctly', () {
      const color = Color(0xFFFF5722);
      final intVal = ColorUtils.toArgbInt(color);
      final reconstructed = ColorUtils.fromArgbInt(intVal);

      expect(reconstructed.a, closeTo(color.a, 0.01));
      expect(reconstructed.r, closeTo(color.r, 0.01));
      expect(reconstructed.g, closeTo(color.g, 0.01));
      expect(reconstructed.b, closeTo(color.b, 0.01));
    });

    test('copyWith updates specific properties without modifying others', () {
      const subject = SubjectModel(
        id: 1,
        title: 'Física',
        colorInt: 4292557552,
        studyMs: 3600000,
      );

      final updated = subject.copyWith(title: 'Física Moderna', studyMs: 7200000);
      expect(updated.id, equals(1));
      expect(updated.title, equals('Física Moderna'));
      expect(updated.studyMs, equals(7200000));
      expect(updated.colorInt, equals(4292557552));
    });
  });
}
