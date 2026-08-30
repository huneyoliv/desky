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
