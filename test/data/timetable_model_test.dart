import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/timetable_model.dart';

void main() {
  group('TimetableBlock Tests', () {
    test('fromJson parses timetable JSON correctly', () {
      final json = {
        'id': 101,
        'subject_id': 119611290,
        'subject_title': 'Raciocínio Lógico',
        'color': 4293227379,
        'day_of_week': 1,
        'start_hour': 8,
        'end_hour': 10,
      };

      final block = TimetableBlock.fromJson(json);

      expect(block.id, 101);
      expect(block.subjectId, 119611290);
      expect(block.subjectTitle, 'Raciocínio Lógico');
      expect(block.colorInt, 4293227379);
      expect(block.dayOfWeek, 1);
      expect(block.startHour, 8);
      expect(block.endHour, 10);
    });

    test('toJson produces correct map', () {
      const block = TimetableBlock(
        id: 102,
        subjectId: 12,
        subjectTitle: 'Matemática',
        colorInt: 4292557552,
        dayOfWeek: 3,
        startHour: 14,
        endHour: 16,
      );

      final json = block.toJson();

      expect(json['id'], 102);
      expect(json['subject_id'], 12);
      expect(json['subject_title'], 'Matemática');
      expect(json['color'], 4292557552);
      expect(json['day_of_week'], 3);
      expect(json['start_hour'], 14);
      expect(json['end_hour'], 16);
    });
  });
}
