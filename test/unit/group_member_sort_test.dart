import 'package:desky/data/models/group_member_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupMemberModel & Partitioning Tests', () {
    test('GroupMemberModel.fromJson parses fields correctly', () {
      final json = {
        'ud': 16300695,
        'n': 'Longkun',
        'sd': 354,
        'hasCustomAvatar': false,
        'dl': {
          'is': true,
          'ip': false,
          'sm': 18000000,
          'ss': 1786320000,
        },
      };

      final member = GroupMemberModel.fromJson(json);
      expect(member.userId, 16300695);
      expect(member.name, 'Longkun');
      expect(member.studiconId, 354);
      expect(member.isStudying, true);
      expect(member.isPaused, false);
      expect(member.studyMs, 18000000);
      expect(member.sessionStartMs, 1786320000);
    });

    test('avatarUrl resolves correct pose for studying, paused and idle states', () {
      const activeMember = GroupMemberModel(
        userId: 1,
        name: 'Alice',
        studiconId: 100,
        isStudying: true,
        isPaused: false,
        studyMs: 12000000,
        hasCustomAvatar: false,
      );
      expect(activeMember.avatarUrl, contains('/sc.v2/100/sweat3.png'));

      const pausedMember = GroupMemberModel(
        userId: 2,
        name: 'Bob',
        studiconId: 100,
        isStudying: true,
        isPaused: true,
        studyMs: 5000000,
        hasCustomAvatar: false,
      );
      expect(pausedMember.avatarUrl, contains('/sc.v2/100/smoke1.png'));

      const idleMember = GroupMemberModel(
        userId: 3,
        name: 'Charlie',
        studiconId: 100,
        isStudying: false,
        isPaused: false,
        studyMs: 3600000,
        hasCustomAvatar: false,
      );
      expect(idleMember.avatarUrl, contains('/sc.v2/100/normal1.png'));
    });

    test('Partitioning separates studying members from resting members correctly', () {
      final members = [
        const GroupMemberModel(
          userId: 1,
          name: 'Alice',
          studiconId: 1,
          isStudying: true,
          isPaused: false,
          studyMs: 10000,
          hasCustomAvatar: false,
        ),
        const GroupMemberModel(
          userId: 2,
          name: 'Bob',
          studiconId: 2,
          isStudying: false,
          isPaused: false,
          studyMs: 50000,
          hasCustomAvatar: false,
        ),
        const GroupMemberModel(
          userId: 3,
          name: 'Charlie',
          studiconId: 3,
          isStudying: true,
          isPaused: true,
          studyMs: 30000,
          hasCustomAvatar: false,
        ),
        const GroupMemberModel(
          userId: 4,
          name: 'David',
          studiconId: 4,
          isStudying: true,
          isPaused: false,
          studyMs: 90000,
          hasCustomAvatar: false,
        ),
      ];

      final studying = members.where((m) => m.isStudying && !m.isPaused).toList()
        ..sort((a, b) => b.studyMs.compareTo(a.studyMs));

      final resting = members.where((m) => !m.isStudying || m.isPaused).toList()
        ..sort((a, b) => b.studyMs.compareTo(a.studyMs));

      expect(studying.length, 2);
      expect(studying[0].name, 'David');
      expect(studying[1].name, 'Alice');

      expect(resting.length, 2);
      expect(resting[0].name, 'Bob');
      expect(resting[1].name, 'Charlie');
    });

    test('Sorting handles studyMs ties alphabetically', () {
      final members = [
        const GroupMemberModel(
          userId: 1,
          name: 'Zara',
          studiconId: 1,
          isStudying: true,
          isPaused: false,
          studyMs: 5000,
          hasCustomAvatar: false,
        ),
        const GroupMemberModel(
          userId: 2,
          name: 'Ana',
          studiconId: 2,
          isStudying: true,
          isPaused: false,
          studyMs: 5000,
          hasCustomAvatar: false,
        ),
      ];

      members.sort((a, b) {
        final cmp = b.studyMs.compareTo(a.studyMs);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });

      expect(members[0].name, 'Ana');
      expect(members[1].name, 'Zara');
    });
  });
}
