import '../../core/api/api_client.dart';
import '../models/challenge_model.dart';

/// Leitura de desafios.
///
/// Somente a listagem e comprovada: `GET /mission/challenges`, que devolve a
/// lista em `rs`. As antigas `fetchMyChallenges` (`/mission/challenge/my`) e
/// `joinChallenge`/`cancelParticipation` (`/mission/challenge/join` e `/cancel`)
/// foram removidas porque as tres rotas respondem `404` na API e nao existem no
/// APK oficial (que tem 20 rotas de missao, nenhuma com join/cancel).
class ChallengeRepository {
  final ApiClient _apiClient;

  ChallengeRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<ChallengeModel>> fetchAvailableChallenges() async {
    try {
      final response = await _apiClient.get('/mission/challenges');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // A API devolve a lista em `rs`; sem essa chave a aba ficava sempre vazia.
        final list = data['rs'] ?? data['challenges'] ?? data['c'];
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
}