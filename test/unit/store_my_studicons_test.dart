import 'package:desky/core/cdn/cdn_resolver.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/store_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Store and Meus Avatares Tests', () {
    test('CdnResolver.studiconUrl resolves -1 as default orange doll', () {
      final defaultUrl = CdnResolver.studiconUrl(-1, StudiconPose.normal1);
      final zeroUrl = CdnResolver.studiconUrl(0, StudiconPose.normal1);

      expect(defaultUrl, contains('/sc.v2/-1/normal1.png'));
      expect(zeroUrl, contains('/sc.v2/-1/normal1.png'));
    });

    test('StoreRepository.fetchMyStudicons includes default orange avatar -1', () async {
      final repo = StoreRepository();
      final myItems = await repo.fetchMyStudicons(-1);

      expect(myItems.any((item) => item.id == -1), true);
      final defaultItem = myItems.firstWhere((item) => item.id == -1);
      expect(defaultItem.isEquipped, true);
      expect(defaultItem.name, contains('Padrão'));
    });

    test('UserModel.fromJson ignores pv and defaults to -1 when sd/ssd/csd are -1', () {
      final json = {
        'id': 16300695,
        'n': 'Longkun',
        'e': 'longkun@test.com',
        'p': {
          'pv': 46,
          'dv': 0,
          'stm': 'Status test',
          'csd': -1,
          'ssd': -1,
        },
        'scs': [],
      };

      final user = UserModel.fromJson(json, 'test-jwt');
      expect(user.studiconId, equals(-1));
      expect(user.ownedStudiconIds, isEmpty);
    });

    test('UserModel.fromJson parses custom equipped studicon from sd/ssd/csd', () {
      final json = {
        'id': 16300695,
        'n': 'Longkun',
        'e': 'longkun@test.com',
        'p': {
          'pv': 55,
          'sd': 354,
        },
        'scs': [354, 100],
      };

      final user = UserModel.fromJson(json, 'test-jwt');
      expect(user.studiconId, equals(354));
      expect(user.ownedStudiconIds, contains(354));
      expect(user.ownedStudiconIds, contains(100));
    });
  });
}
