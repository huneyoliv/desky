import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/study_date_helper.dart';

class TimerRepository {
  final ApiClient _apiClient;

  TimerRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.studyStart,
      data: {
        'subject': subjectTitle,
        'subject_id': subjectId,
        'deviceModel': 'Desktop',
        'taskId': null,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return data['s'] == true;
  }

  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.studyStop,
      data: {
        'subject': subjectTitle,
        'subject_id': subjectId,
        'startedAt': startAt.millisecondsSinceEpoch,
        'study_ms': studyMs,
        'deviceModel': 'Desktop',
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == true) {
      return data;
    }
    return null;
  }

  Future<bool> recordRest({
    required DateTime startAt,
    required DateTime stopAt,
    required int restMs,
    String deviceModel = ApiConstants.defaultDeviceModel,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.studyBreak,
        data: {
          'startedAt': startAt.millisecondsSinceEpoch,
          'stopAt': stopAt.millisecondsSinceEpoch,
          'rest_ms': restMs,
          'deviceModel': deviceModel,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> logManualStudy({
    required int subjectId,
    required String subjectTitle,
    required DateTime startAt,
    required DateTime stopAt,
    String language = ApiConstants.defaultLanguage,
    String deviceModel = ApiConstants.defaultDeviceModel,
  }) async {
    final studyMs = stopAt.difference(startAt).inMilliseconds;
    if (studyMs <= 0) {
      throw const ApiException('O horário de término deve ser posterior ao início');
    }

    final response = await _apiClient.post(
      '/logs/v2/study/manual',
      data: {
        'subject_id': subjectId,
        'subject': subjectTitle,
        'startedAt': startAt.millisecondsSinceEpoch,
        'stopAt': stopAt.millisecondsSinceEpoch,
        'study_ms': studyMs,
        'deviceModel': deviceModel,
        'language': language,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['s'] == true) {
      return data;
    }
    if (data is Map<String, dynamic> && data['m'] != null) {
      throw ApiException(data['m'].toString());
    }
    throw const ApiException('Falha ao registrar estudo manual');
  }

  Future<Map<String, dynamic>?> fetchDailyLog(DateTime date) async {
    try {
      final dateStr = StudyDateHelper.getStudyDateString(date);
      final response = await _apiClient.get('/logs/day?date=$dateStr');
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<DateTime> syncTime() async {
    final response = await _apiClient.get(ApiConstants.timeSync);
    final data = response.data as Map<String, dynamic>;
    if (data['timestamp'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    }
    return DateTime.now();
  }
}
