import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/rank_entry_model.dart';

void main() {
  group('RankEntryModel Tests', () {
    test('fromJson parses rank entry accurately from API json format', () {
      final json = {
        'ud': 1001,
        'n': 'Alice Estudos',
        'sd': 5,
        'ct': 'Medicina',
        'hasCustomAvatar': false,
        'dl': {
          'sm': 18000000,
        },
      };

      final entry = RankEntryModel.fromJson(json, 1);
      expect(entry.rank, equals(1));
      expect(entry.userId, equals(1001));
      expect(entry.userName, equals('Alice Estudos'));
      expect(entry.studiconId, equals(5));
      expect(entry.studyMs, equals(18000000));
      expect(entry.categoryName, equals('Medicina'));
      expect(entry.avatarUrl, contains('5/normal1.png'));
    });

    test('fromJson handles fallback fields gracefully', () {
      final json = {
        'userId': 2002,
        'userName': 'Bob Concurseiro',
        'sm': 7200000,
        'c': 'Concursos',
      };

      final entry = RankEntryModel.fromJson(json, 4);
      expect(entry.rank, equals(4));
      expect(entry.userId, equals(2002));
      expect(entry.userName, equals('Bob Concurseiro'));
      expect(entry.studyMs, equals(7200000));
      expect(entry.categoryName, equals('Concursos'));
      expect(entry.studiconId, equals(-1));
    });
  });
}
