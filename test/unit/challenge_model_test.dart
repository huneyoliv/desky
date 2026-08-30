import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/challenge_model.dart';

void main() {
  group('ChallengeModel Tests', () {
    test('fromJson parses full challenge JSON accurately', () {
      final json = {
        'id': 10,
        'name': 'Maratona 100 Horas',
        'description': 'Estude 100 horas no mês',
        'rules': 'Mínimo de 3 horas por dia útil',
        'flame_cost': 100,
        'checkin_method': 'timer',
        'start_at': '2026-09-01T00:00:00.000Z',
        'end_at': '2026-09-30T23:59:59.000Z',
        'checkin_count': 5,
        'threshold': 0.85,
        'participants_count': 42,
        'status': 'active',
        'is_joined': true,
      };

      final challenge = ChallengeModel.fromJson(json);
      expect(challenge.id, equals(10));
      expect(challenge.name, equals('Maratona 100 Horas'));
      expect(challenge.description, equals('Estude 100 horas no mês'));
      expect(challenge.rules, equals('Mínimo de 3 horas por dia útil'));
      expect(challenge.flameCost, equals(100));
      expect(challenge.checkInMethod, equals('timer'));
      expect(challenge.startDate.year, equals(2026));
      expect(challenge.startDate.month, equals(9));
      expect(challenge.checkInCount, equals(5));
      expect(challenge.successThreshold, equals(0.85));
      expect(challenge.participantCount, equals(42));
      expect(challenge.status, equals('active'));
      expect(challenge.isJoined, isTrue);
    });

    test('fromJson handles empty/null json with safe fallback defaults', () {
      final challenge = ChallengeModel.fromJson({});
      expect(challenge.id, equals(0));
      expect(challenge.name, equals('Desafio de Estudos'));
      expect(challenge.flameCost, equals(50));
      expect(challenge.isJoined, isFalse);
      expect(challenge.successThreshold, equals(0.8));
    });
  });
}
