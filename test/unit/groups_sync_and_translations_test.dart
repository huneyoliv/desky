import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/core/localization/app_translation.dart';

void main() {
  group('Groups Sync & Serialization Tests', () {
    test('GroupModel parses YPT API keys correctly without mc conflict', () {
      final json = {
        'id': 12345,
        't': 'Grupo de Estudos Medicina',
        'c': 'Vestibular',
        'gt': 10,
        'jc': 8,
        'mp': 30,
        'ip': true,
        'on': 'Líder Alice',
        'ou': 999,
        'sn': 'Regras do grupo',
        'cam': true,
      };

      final group = GroupModel.fromJson(json);
      expect(group.id, equals(12345));
      expect(group.name, equals('Grupo de Estudos Medicina'));
      expect(group.category, equals('Vestibular'));
      expect(group.dailyGoalHours, equals(10));
      expect(group.membersCount, equals(8));
      expect(group.maxCapacity, equals(30));
      expect(group.isPrivate, isTrue);
      expect(group.leaderName, equals('Líder Alice'));
      expect(group.leaderUserId, equals(999));
      expect(group.notice, equals('Regras do grupo'));
      expect(group.isCamStudy, isTrue);

      final encoded = group.toJson();
      final decodedGroup = GroupModel.fromJson(encoded);
      expect(decodedGroup.id, equals(group.id));
      expect(decodedGroup.name, equals(group.name));
      expect(decodedGroup.membersCount, equals(8));
      expect(decodedGroup.maxCapacity, equals(30));
    });

    test('UserModel serializes and deserializes userGroups correctly for caching', () {
      final userJson = {
        'id': 100,
        'n': 'Bob',
        'e': 'bob@test.com',
        'stm': 'Foco nos estudos',
        'ct': 'Concurso',
        'ci': 2,
        'pv': 15,
        'fl': 250,
        'gs': [
          {
            'id': 10,
            'n': 'Grupo 1',
            'c': 'Geral',
            'gt': 6,
            'jc': 5,
            'mp': 20,
            'ip': false,
            'on': 'Admin',
            'ou': 1,
            'cam': false,
          },
          {
            'id': 20,
            'n': 'Grupo 2',
            'c': 'TI',
            'gt': 8,
            'jc': 12,
            'mp': 50,
            'ip': true,
            'on': 'Admin 2',
            'ou': 2,
            'cam': true,
          }
        ],
      };

      final user = UserModel.fromJson(userJson, 'test_jwt_token');
      expect(user.userGroups.length, equals(2));
      expect(user.userGroups[0].name, equals('Grupo 1'));
      expect(user.userGroups[1].name, equals('Grupo 2'));

      final cachedJson = user.toJson();
      expect(cachedJson['gs'], isA<List>());
      expect((cachedJson['gs'] as List).length, equals(2));

      final restoredUser = UserModel.fromJson(cachedJson, 'test_jwt_token');
      expect(restoredUser.userGroups.length, equals(2));
      expect(restoredUser.userGroups[0].id, equals(10));
      expect(restoredUser.userGroups[1].id, equals(20));
      expect(restoredUser.userGroups[1].isCamStudy, isTrue);
    });
  });

  group('AppTranslation Fallbacks & 5 Items Validation', () {
    test('Item 1: profile translation returns only Perfil/Profile and never Perfil do grupo', () {
      const translationPt = AppTranslation(languageCode: 'pt', translations: {});
      const translationEn = AppTranslation(languageCode: 'en', translations: {});
      const translationKo = AppTranslation(languageCode: 'ko', translations: {});

      expect(translationPt.tr('profile'), equals('Perfil'));
      expect(translationEn.tr('profile'), equals('Profile'));
      expect(translationKo.tr('profile'), equals('프로필'));
      expect(translationPt.tr('profile'), isNot(contains('grupo')));
    });

    test('Item 2: Planner, Timetable and Days of Week translate across locales', () {
      const translationPt = AppTranslation(languageCode: 'pt', translations: {});
      const translationEn = AppTranslation(languageCode: 'en', translations: {});
      const translationEs = AppTranslation(languageCode: 'es', translations: {});

      expect(translationPt.tr('planner'), equals('Planner'));
      expect(translationEn.tr('planner'), equals('Planner'));
      expect(translationPt.tr('timetable'), equals('Grade Horária'));
      expect(translationEn.tr('timetable'), equals('Timetable'));
      expect(translationEs.tr('timetable'), equals('Horario'));

      expect(translationPt.tr('monday'), equals('Segunda-feira'));
      expect(translationEn.tr('monday'), equals('Monday'));
      expect(translationEs.tr('monday'), equals('Lunes'));
    });

    test('Item 3: Groups, Explore and Members translate across locales', () {
      const translationPt = AppTranslation(languageCode: 'pt', translations: {});
      const translationEn = AppTranslation(languageCode: 'en', translations: {});

      expect(translationPt.tr('my_groups'), equals('Meus Grupos'));
      expect(translationEn.tr('my_groups'), equals('My Groups'));
      expect(translationPt.tr('explore'), equals('Explorar Grupos'));
      expect(translationEn.tr('explore'), equals('Explore Groups'));
      expect(translationPt.tr('members'), equals('membros'));
      expect(translationEn.tr('members'), equals('members'));
    });

    test('Item 4: Timer, Today Total and Pomodoro phases translate across locales', () {
      const translationPt = AppTranslation(languageCode: 'pt', translations: {});
      const translationEn = AppTranslation(languageCode: 'en', translations: {});
      const translationKo = AppTranslation(languageCode: 'ko', translations: {});

      expect(translationPt.tr('timer'), equals('Cronômetro'));
      expect(translationEn.tr('timer'), equals('Timer'));
      expect(translationKo.tr('timer'), equals('타이머'));

      expect(translationPt.tr('today_total_study_time'), equals('Tempo Total de Hoje'));
      expect(translationEn.tr('today_total_study_time'), equals('Total Time Today'));

      expect(translationPt.tr('focus'), equals('Foco'));
      expect(translationEn.tr('focus'), equals('Focus'));
      expect(translationPt.tr('short_break'), equals('Pausa Curta'));
      expect(translationEn.tr('short_break'), equals('Short Break'));
    });
  });
}
