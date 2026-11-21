import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/timetable_model.dart';

/// Timetable (grade horaria) contract.
///
/// Verified live against `https://pi.tgclab.com`:
///  * `GET /timetable/timetables` -> `{"s": true, "rt": [ {id, t, sd, ed, st, et, lw, scid} ]}`
///  * `GET /timetable/detail/v70630?id=<ttid>` -> `{"s": true, "sb": [ ...blocks ]}`
///  * `DELETE /timetable/detail/v70630` with `{"id": <blockId>}` in the JSON body
///    -> `{"s": true}`, or `{"s": false, "m": "already removed"}` for an unknown id.
///
/// Block creation was verified live on the test account: the title uses `t`,
/// the container supplies `ttid`, `sd` and `ed`, and `c` carries the ARGB
/// colour. The third and final authorized attempt returned `s:true` and `rs`;
/// the block was reread through `sb` and deleted, leaving zero probe blocks.
class TimetableRepository {
  final ApiClient _apiClient;

  TimetableRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  static const String _timetablesPath = ApiConstants.timetableList;
  static const String _detailPath = ApiConstants.timetableDetail;

  /// Returns the blocks owned by the account.
  ///
  /// The list route returns timetable containers in `rt`. When the detail
  /// route exposes `sb`, those are the actual blocks and take precedence over
  /// the container summary; otherwise the summary remains a compatibility
  /// fallback for older servers.
  Future<List<TimetableBlock>> fetchTimetable() async {
    final response = await _apiClient.get(_timetablesPath);
    final data = response.data;
    if (data is! Map<String, dynamic>) return [];
    final list = data['rt'] ?? data['timetables'];
    if (list is! List) return [];

    final containers = list.whereType<Map<String, dynamic>>().toList();
    final blocks = <TimetableBlock>[];
    for (final container in containers) {
      final rawId = container['id'];
      final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
      if (id != null) {
        try {
          final detail = await _apiClient.get(
            _detailPath,
            queryParameters: {'id': id},
          );
          final detailData = detail.data;
          if (detailData is Map<String, dynamic> && detailData['sb'] is List) {
            blocks.addAll((detailData['sb'] as List)
                .whereType<Map<String, dynamic>>()
                .map(TimetableBlock.fromJson));
            continue;
          }
        } catch (_) {
          // Keep the summary fallback if the detail cannot be read.
        }
      }
      blocks.add(TimetableBlock.fromJson(container));
    }
    return blocks;
  }

  /// Resolves the container used for creation. Its dates and id are required
  /// together with the block colour in the live-verified create contract.
  Future<Map<String, dynamic>?> _resolveTimetable(int? timetableId) async {
    try {
      final response = await _apiClient.get(_timetablesPath);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['rt'] ?? data['timetables'];
        if (list is List) {
          final containers = list.whereType<Map<String, dynamic>>();
          for (final container in containers) {
            final rawId = container['id'];
            final id = rawId is num
                ? rawId.toInt()
                : int.tryParse(rawId?.toString() ?? '');
            if (id != null && (timetableId == null || id == timetableId)) {
              return container;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<TimetableBlock?> createBlock({
    required int subjectId,
    required String subjectTitle,
    required int colorInt,
    required int dayOfWeek,
    required int startHour,
    required int endHour,
    int? timetableId,
  }) async {
    final timetable = await _resolveTimetable(timetableId);
    if (timetable == null) return null;
    final rawId = timetable['id'];
    final ttid = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
    if (ttid == null) return null;
    try {
      final response = await _apiClient.post(
        _detailPath,
        data: {
          'ttid': ttid,
          't': subjectTitle,
          'lw': dayOfWeek,
          'st': _formatHour(startHour),
          'et': _formatHour(endHour),
          'scid': subjectId,
          'sd': timetable['sd'],
          'ed': timetable['ed'],
          // Live proof: without c the server returned s:false. Adding c
          // created the block (s:true, rs), which was reread and deleted.
          'c': colorInt,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final raw = data['rs'] ?? data['b'] ?? data['timetable'] ?? data['d'];
        if (raw is Map<String, dynamic>) {
          return TimetableBlock.fromJson(raw);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Deletes a block. The id travels in the JSON body, not in the path.
  Future<bool> deleteBlock(int blockId) async {
    try {
      final response = await _apiClient.delete(
        _detailPath,
        data: {'id': blockId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  static String _formatHour(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00:00';
}
