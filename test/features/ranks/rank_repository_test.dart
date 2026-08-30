import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/rank_entry_model.dart';

void main() {
  group('RankEntryModel Tests', () {
    test('fromJson parses rank entry response from HAR schema correctly', () {
      final json = {
        'ud': 13579179,
        'n': 'Dra. K',
        'ct': 'Concurso',
        'sd': 279,
        'dl': {
          'sm': 48467445,
        }
      };
      final entry = RankEntryModel.fromJson(json, 1);

      expect(entry.rank, equals(1));
      expect(entry.userId, equals(13579179));
      expect(entry.userName, equals('Dra. K'));
      expect(entry.studyMs, equals(48467445));
      expect(entry.studiconId, equals(279));
      expect(entry.categoryName, equals('Concurso'));
    });
  });
}
