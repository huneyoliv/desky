import '../../core/api/api_client.dart';
import '../models/timetable_model.dart';

class TimetableRepository {
  final ApiClient _apiClient;

  TimetableRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<TimetableBlock>> fetchTimetable() async {
    try {
      final response = await _apiClient.get('/timetable/timetables');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['timetables'] ?? data['t'] ?? data['blocks'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => TimetableBlock.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<TimetableBlock?> createBlock({
    required int subjectId,
    required String subjectTitle,
    required int colorInt,
    required int dayOfWeek,
    required int startHour,
    required int endHour,
  }) async {
    try {
      final response = await _apiClient.post(
        '/timetable/timetable',
        data: {
          'subject_id': subjectId,
          'subject_title': subjectTitle,
          'color': colorInt,
          'day_of_week': dayOfWeek,
          'start_hour': startHour,
          'end_hour': endHour,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final raw = data['timetable'] ?? data['t'] ?? data;
        if (raw is Map<String, dynamic>) {
          return TimetableBlock.fromJson(raw);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteBlock(int blockId) async {
    try {
      final response = await _apiClient.delete('/timetable/timetable/$blockId');
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }
}
