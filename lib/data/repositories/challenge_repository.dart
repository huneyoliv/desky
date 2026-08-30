import '../../core/api/api_client.dart';
import '../models/challenge_model.dart';

class ChallengeRepository {
  final ApiClient _apiClient;

  ChallengeRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<ChallengeModel>> fetchAvailableChallenges() async {
    try {
      final response = await _apiClient.get('/mission/challenges');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['challenges'] ?? data['c'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => ChallengeModel.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<ChallengeModel>> fetchMyChallenges() async {
    try {
      final response = await _apiClient.get('/mission/challenge/my');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['challenges'] ?? data['c'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => ChallengeModel.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> joinChallenge(int challengeId, int flameBet) async {
    try {
      final response = await _apiClient.post(
        '/mission/challenge/join',
        data: {
          'challengeID': challengeId,
          'flameBet': flameBet,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> cancelParticipation(int challengeId) async {
    try {
      final response = await _apiClient.post(
        '/mission/challenge/cancel',
        data: {'challengeID': challengeId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }
}
