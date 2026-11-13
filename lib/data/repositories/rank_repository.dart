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
    DateTime? referenceDate,
  }) async {
    try {
      final now = referenceDate ?? DateTime.now();

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

  /// Study milliseconds per day ('yyyy-MM-dd') for any date range.
  Future<Map<String, int>> fetchDailyStudyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    final data = await fetchUserStats(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
    final rawLogs = data['ls'];
    final byDay = <String, int>{};
    if (rawLogs is List) {
      for (final log in rawLogs) {
        if (log is Map<String, dynamic>) {
          final day = log['dt'] as String? ?? '';
          if (day.isEmpty) continue;
          byDay[day] = (byDay[day] ?? 0) + (log['sm'] as int? ?? 0);
        }
      }
    }
    return byDay;
  }

  /// Minutes studied per hour, keyed by 'yyyy-MM-dd' with 24 buckets each.
  ///
  /// Every session carries `st` (ISO start) and `sm` (duration), so the minutes
  /// land on the hours that were actually studied instead of one daily block.
  Future<Map<String, List<int>>> fetchHourlyStudyMinutes({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    final data = await fetchUserStats(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    final byDay = <String, List<int>>{};
    for (final day in _eachDay(startDate, endDate)) {
      byDay[day] = List.filled(24, 0);
    }

    final rawLogs = data['ls'];
    if (rawLogs is List) {
      for (final log in rawLogs) {
        if (log is! Map<String, dynamic>) continue;
        final day = _normalizeDay(log['dt'] as String? ?? '');
        if (day.isEmpty) continue;
        final buckets = byDay.putIfAbsent(day, () => List.filled(24, 0));

        final sessions = log['ls'];
        if (sessions is! List) continue;
        for (final session in sessions) {
          if (session is! Map<String, dynamic>) continue;
          final minutes = ((session['sm'] as int? ?? 0) / 60000).round();
          if (minutes <= 0) continue;
          final start = DateTime.tryParse(session['st'] as String? ?? '')?.toLocal();
          if (start == null) continue;

          var remaining = minutes;
          var hour = start.hour;
          // The first hour only takes the part of it that was studied.
          var capacity = 60 - start.minute;
          while (remaining > 0 && hour < 24) {
            final take = remaining < capacity ? remaining : capacity;
            buckets[hour] += take;
            remaining -= take;
            hour++;
            capacity = 60;
          }
        }
      }
    }

    return byDay;
  }

  static String _normalizeDay(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}'
        '-${parsed.day.toString().padLeft(2, '0')}';
  }

  static Iterable<String> _eachDay(String startDate, String endDate) sync* {
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null || end == null) return;
    for (var day = DateTime(start.year, start.month, start.day);
        !day.isAfter(DateTime(end.year, end.month, end.day));
        day = day.add(const Duration(days: 1))) {
      yield '${day.year}-${day.month.toString().padLeft(2, '0')}'
          '-${day.day.toString().padLeft(2, '0')}';
    }
  }

  /// Reserved key for studied time that carries no session subject.
  static const String unknownSubjectKey = '__unknown__';

  /// Study milliseconds per day and subject for any date range.
  ///
  /// Returns 'yyyy-MM-dd' -> subject -> ms, so a series can be stacked per day.
  Future<Map<String, Map<String, int>>> fetchSubjectDailyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    final data = await fetchUserStats(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    final byDay = <String, Map<String, int>>{};
    final rawLogs = data['ls'];
    if (rawLogs is! List) return byDay;

    for (final log in rawLogs) {
      if (log is! Map<String, dynamic>) continue;
      final day = _normalizeDay(log['dt'] as String? ?? '');
      if (day.isEmpty) continue;
      final buckets = byDay.putIfAbsent(day, () => <String, int>{});

      final sessions = log['ls'];
      var attributed = false;
      if (sessions is List) {
        for (final session in sessions) {
          if (session is! Map<String, dynamic>) continue;
          final subject = (session['sb'] as String? ?? '').trim();
          final ms = session['sm'] as int? ?? 0;
          if (subject.isEmpty || ms <= 0) continue;
          buckets[subject] = (buckets[subject] ?? 0) + ms;
          attributed = true;
        }
      }
      if (!attributed) {
        final ms = log['sm'] as int? ?? 0;
        if (ms > 0) buckets[unknownSubjectKey] = ms;
      }
    }

    return byDay;
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
