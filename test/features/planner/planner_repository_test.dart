import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/models/todo_item_model.dart';

import 'package:desky/core/utils/study_date_helper.dart';

void main() {
  group('Planner Models Tests', () {
    test('DDayModel calculates daysRemaining and label correctly', () {
      final studyToday = StudyDateHelper.getStudyDate();
      final targetFuture = studyToday.add(const Duration(days: 10));
      final dday = DDayModel(
        id: 1,
        title: 'Prova',
        targetDate: targetFuture,
        colorInt: 4294948685,
      );

      expect(dday.daysRemaining, equals(10));
      expect(dday.label, equals('D-10'));
    });

    test('TodoItemModel parses study-plan HAR JSON response correctly', () {
      final json = {
        'id': 111625709,
        't': 'Resolver questões',
        'sa': '2026-08-25T00:05:00.000Z',
        's': 1,
        'sd': 119611290,
      };

      final item = TodoItemModel.fromJson(json);
      expect(item.id, equals(111625709));
      expect(item.title, equals('Resolver questões'));
      expect(item.subjectId, equals(119611290));
      expect(item.isCompleted, isTrue);
      expect(item.dateYmd, equals('2026-08-25'));
      expect(item.isRecurring, isFalse);
    });

    test('TodoItemModel parses recurrence_rule and isRecurring correctly', () {
      final json = {
        'id': 111626006,
        't': 'Estudar exatas',
        'sa': '2026-08-10T00:15:00.000Z',
        's': null,
        'sd': 119736077,
        'rr': {
          'id': 111626006,
          'i': 1,
          'f': 1,
          'w': [1, 2, 3, 4, 5],
          'e': '2026-09-09T21:15:00.000'
        }
      };

      final item = TodoItemModel.fromJson(json);
      expect(item.id, equals(111626006));
      expect(item.isRecurring, isTrue);
      expect(item.recurrenceRule, isNotNull);
      expect(item.recurrenceRule!.daysOfWeek, equals([1, 2, 3, 4, 5]));
      expect(item.recurrenceRule!.endDate, equals('2026-09-09T21:15:00.000'));
    });
  });
}
