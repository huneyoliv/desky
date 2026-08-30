import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/rank_entry_model.dart';

class RankRepository {
  final ApiClient _apiClient;

  RankRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<RankEntryModel>> fetchGlobalRanks({
    String period = 'day',
    int categoryId = 0,
    int countryId = ApiConstants.defaultCountryId,
    int page = 1,
  }) async {
    try {
      final now = DateTime.now();

      // The YPT ranking API requires the start-of-period reference date without zero-padding:
      // - 'day': today's date (e.g. 2026-8-25)
      // - 'week': Monday of the current week (e.g. 2026-8-24)
      // - 'month': 1st day of the month (e.g. 2026-8-1)
      final DateTime refDate;
      if (period == 'month') {
        refDate = DateTime(now.year, now.month, 1);
      } else if (period == 'week') {
        final monday = now.subtract(Duration(days: now.weekday - 1));
        refDate = DateTime(monday.year, monday.month, monday.day);
      } else {
        refDate = DateTime(now.year, now.month, now.day);
      }
      final dateStr = '${refDate.year}-${refDate.month}-${refDate.day}';

      final response = await _apiClient.get(
        '${ApiConstants.metadataCdnUrl}/logs/category/member/ranks'
        '?type=$period&countryID=$countryId&categoryID=$categoryId'
        '&groupID=0&isCam=false&date=$dateStr&page=$page',
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final list = data['ms'] ?? data['ranks'];
        if (list is List) {
          final startRank = (page - 1) * 20 + 1;
          return list
              .asMap()
              .entries
              .map((entry) => RankEntryModel.fromJson(
                  entry.value as Map<String, dynamic>, startRank + entry.key))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<int?> fetchMyCategoryRank({
    int categoryId = 0,
    int countryId = ApiConstants.defaultCountryId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/logs/my-category-rank?category_id=$categoryId&country_id=$countryId',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['s'] == true) {
        return data['mr'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> fetchUserStats({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _apiClient.post(
        '/logs/range/days',
        data: {
          'id': userId,
          'isMember': true,
          'startDate': startDate,
          'endDate': endDate,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        return data;
      }
    } catch (_) {}

    return {'ls': [], 'ss': []};
  }
}
