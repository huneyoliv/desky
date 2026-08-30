import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/studicon_item_model.dart';

void main() {
  group('StudiconItemModel Tests', () {
    test('fromJson parses API studicon response correctly', () {
      final json = {
        'id': 377,
        'te': 'Desert Mascot',
        'tk': 'Korean Mascot',
        'category': 'Mascotes',
        'price': 150,
      };
      final model = StudiconItemModel.fromJson(json);

      expect(model.id, equals(377));
      expect(model.name, equals('Desert Mascot'));
      expect(model.previewUrl, equals('https://alicdn.tgclab.com/sc.v2/377/normal1.png'));
    });
  });
}
