import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('parses ownedStudiconIds from int array in scs', () {
      final json = {
        'id': 16300695,
        'n': 'Estudante',
        'e': 'test@example.com',
        'sd': 46,
        'scs': [46, 52, 100],
      };

      final user = UserModel.fromJson(json, 'token_123');
      expect(user.id, 16300695);
      expect(user.name, 'Estudante');
      expect(user.studiconId, 46);
      expect(user.ownedStudiconIds, [46, 52, 100]);
    });

    test('parses ownedStudiconIds from map list with various keys (id, sc, sd, studiconId)', () {
      final json = {
        'id': 16300695,
        'name': 'Estudante',
        'email': 'test@example.com',
        'sd': 46,
        'scs': [
          {'id': 46},
          {'sc': 52},
          {'sd': 88},
          {'studiconId': 105},
        ],
      };

      final user = UserModel.fromJson(json, 'token_123');
      expect(user.ownedStudiconIds, [46, 52, 88, 105]);
    });

    test('parses ownedStudiconIds from my or ownedStudiconIds fallback', () {
      final json = {
        'id': 16300695,
        'my': [10, 20, 30],
      };

      final user = UserModel.fromJson(json, 'token_123');
      expect(user.ownedStudiconIds, [10, 20, 30]);
    });

    test('copyWith updates ownedStudiconIds correctly', () {
      final user = UserModel(
        id: 1,
        name: 'User',
        email: 'user@test.com',
        jwtToken: 'token',
        studiconId: 46,
        ownedStudiconIds: [46],
      );

      final updated = user.copyWith(ownedStudiconIds: [46, 52, 60]);
      expect(updated.ownedStudiconIds, [46, 52, 60]);
      expect(updated.id, 1);
    });

    test('toJson and fromJson maintain data integrity', () {
      final original = UserModel(
        id: 12345,
        name: 'Test Name',
        email: 'test@example.com',
        jwtToken: 'token_abc',
        studiconId: 46,
        flamesBalance: 250,
        ownedStudiconIds: [46, 77, 88],
      );

      final json = original.toJson();
      final restored = UserModel.fromJson(json, 'token_abc');

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.studiconId, original.studiconId);
      expect(restored.flamesBalance, original.flamesBalance);
      expect(restored.ownedStudiconIds, original.ownedStudiconIds);
    });
  });
}
