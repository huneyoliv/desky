import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/models/chat_message_model.dart';

void main() {
  group('Group Models Tests', () {
    test('GroupModel parses API json accurately', () {
      final json = {
        'id': 5001,
        't': 'Focados em Medicina 2026',
        'c': 'Vestibular',
        'gt': 10,
        'jc': 35,
        'mp': 50,
        'ip': false,
        'on': 'Líder Gabriel',
        'ou': 99,
        'sn': 'Bem-vindos ao grupo de estudos diários!',
        'cam': false,
      };

      final group = GroupModel.fromJson(json);
      expect(group.id, equals(5001));
      expect(group.name, equals('Focados em Medicina 2026'));
      expect(group.category, equals('Vestibular'));
      expect(group.dailyGoalHours, equals(10));
      expect(group.membersCount, equals(35));
      expect(group.maxCapacity, equals(50));
      expect(group.isPrivate, isFalse);
      expect(group.leaderName, equals('Líder Gabriel'));
      expect(group.leaderUserId, equals(99));
      expect(group.notice, equals('Bem-vindos ao grupo de estudos diários!'));

      final exported = group.toJson();
      expect(exported['id'], equals(5001));
      expect(exported['n'], equals('Focados em Medicina 2026'));
    });

    test('GroupMemberModel parses status and avatar accurate values', () {
      final json = {
        'ud': 777,
        'n': 'Mariana',
        'sd': 12,
        'hasCustomAvatar': false,
        'dl': {
          'is': true,
          'ia': false,
          'sm': 14400000,
          'ss': 1700000000,
        },
      };

      final member = GroupMemberModel.fromJson(json);
      expect(member.userId, equals(777));
      expect(member.name, equals('Mariana'));
      expect(member.studiconId, equals(12));
      expect(member.isStudying, isTrue);
      expect(member.isPaused, isFalse);
      expect(member.studyMs, equals(14400000));
      expect(member.sessionStartMs, equals(1700000000));
      expect(member.avatarUrl, contains('/12/'));
      // Sem `dl.st` utilizavel, o contador local nao tem base.
      expect(member.sessionStartedAt, isNull);
    });

    test('GroupMemberModel le dl.st em UTC para o contador local', () {
      final json = {
        'ud': 778,
        'n': 'Bruno',
        'dl': {
          'is': true,
          'ia': false,
          'sm': 0,
          'st': '2026-11-18T13:30:00Z',
        },
      };

      final member = GroupMemberModel.fromJson(json);

      expect(member.sessionStartedAt, isNotNull);
      expect(member.sessionStartedAt!.toUtc(),
          equals(DateTime.utc(2026, 11, 18, 13, 30)));
    });

    test('GroupMemberModel ignora dl.st que nao e timestamp', () {
      for (final bad in ['', 'nao-e-data', '123']) {
        final member = GroupMemberModel.fromJson({
          'ud': 779,
          'n': 'Carla',
          'dl': {'is': true, 'st': bad},
        });

        expect(member.sessionStartedAt, isNull, reason: 'st invalido: "$bad"');
      }
    });

    test('GroupMemberModel aceita dl.st com offset nao-UTC', () {
      final member = GroupMemberModel.fromJson({
        'ud': 780,
        'n': 'Davi',
        'dl': {'is': true, 'st': '2026-11-18T10:30:00+05:30'},
      });

      expect(member.sessionStartedAt, isNotNull);
      expect(member.sessionStartedAt!.toUtc(),
          equals(DateTime.utc(2026, 11, 18, 5, 0)));
    });

    test('ChatMessageModel parses message and reaction maps', () {
      final json = {
        'idx': 9001,
        'uid': 101,
        'nn': 'Lucas',
        'st': 377,
        'msg': 'Bora bater a meta de 6 horas hoje!',
        'type': 'text',
        'ca': 1700000000000,
        'reactions': {
          '🔥': [101, 102, 103],
          '👏': [104],
        },
      };

      final msg = ChatMessageModel.fromJson(json);
      expect(msg.id, equals(9001));
      expect(msg.senderId, equals(101));
      expect(msg.senderName, equals('Lucas'));
      expect(msg.message, equals('Bora bater a meta de 6 horas hoje!'));
      expect(msg.reactions['🔥'], equals([101, 102, 103]));
      expect(msg.reactions['👏'], equals([104]));
    });
  });
}
