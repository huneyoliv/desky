import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/subject_model.dart';

class SubjectFetchResult {
  final List<SubjectModel> subjects;
  final int todayTotalMs;
  final int todayRestMs;

  const SubjectFetchResult({
    required this.subjects,
    required this.todayTotalMs,
    this.todayRestMs = 0,
  });
}

class SubjectRepository {
  final ApiClient _apiClient;

  SubjectRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<SubjectModel> createSubject({
    required String title,
    required int colorInt,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.subjectCreate,
      data: {
        'title': title,
        'color': colorInt,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['s'] != true) {
      throw Exception(data['m'] ?? 'Falha ao criar matéria');
    }

    final sb = data['sb'] as Map<String, dynamic>? ?? data['subject'] as Map<String, dynamic>?;
    if (sb != null) {
      return SubjectModel.fromJson(sb);
    }
    return SubjectModel.fromJson(data);
  }

  Future<SubjectFetchResult> fetchSubjectsData({
    String language = ApiConstants.defaultLanguage,
    String timezone = ApiConstants.defaultTimezone,
    int version = ApiConstants.defaultVersion,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.splashLogin,
        data: {
          'version': version,
          'pushToken': '',
          'timezone': timezone,
          'deviceType': ApiConstants.defaultDeviceType,
          'osVersion': 10,
          'deviceModel': ApiConstants.defaultDeviceModel,
          'pv': 24,
          'language': language,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return _parseSplashData(data);
    } catch (_) {}

    try {
      final response = await _apiClient.post(ApiConstants.reloadInfo);
      final data = response.data as Map<String, dynamic>;
      return _parseSplashData(data);
    } catch (_) {}

    return const SubjectFetchResult(subjects: [], todayTotalMs: 0, todayRestMs: 0);
  }

  Future<List<SubjectModel>> fetchSubjects() async {
    final result = await fetchSubjectsData();
    return result.subjects;
  }

  SubjectFetchResult _parseSplashData(Map<String, dynamic> data) {
    final rawList = data['ss'] ?? data['p']?['ss'];
    final dl = data['dl'] as Map<String, dynamic>?;

    int todayTotalMs = 0;
    int todayRestMs = 0;
    if (dl != null) {
      final sm = dl['sm'] ?? dl['tp'];
      if (sm is int) todayTotalMs = sm;
      final rm = dl['rm'] ?? dl['rt'] ?? dl['rest'] ?? dl['restMs'] ?? dl['rest_ms'];
      if (rm is int) {
        todayRestMs = (rm > 0 && rm < 500000000) ? rm * 1000 : rm;
      }
    }

    final Map<String, int> subjectTimesByName = {};
    final Map<int, int> subjectTimesById = {};

    if (dl != null) {
      if (dl['ls'] is List) {
        for (final item in dl['ls']) {
          if (item is Map<String, dynamic>) {
            final name = item['sb'] as String? ?? '';
            final id = item['id'] as int? ?? item['subjectId'] as int?;
            final ms = item['sm'] as int? ?? 0;
            if (name.isNotEmpty) {
              subjectTimesByName[name] = (subjectTimesByName[name] ?? 0) + ms;
            }
            if (id != null) {
              subjectTimesById[id] = (subjectTimesById[id] ?? 0) + ms;
            }
          }
        }
      }

      if (dl['ss'] is List) {
        for (final item in dl['ss']) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as int?;
            final name = item['tt'] as String? ?? '';
            final ms = item['sm'] as int? ?? 0;
            if (id != null) {
              subjectTimesById[id] = (subjectTimesById[id] ?? 0) + ms;
            }
            if (name.isNotEmpty) {
              subjectTimesByName[name] = (subjectTimesByName[name] ?? 0) + ms;
            }
          }
        }
      }
    }

    List<SubjectModel> subjects = [];
    if (rawList != null && rawList is List) {
      subjects = rawList
          .map((item) {
            final model = SubjectModel.fromJson(item as Map<String, dynamic>);
            // Daily study time should only reflect today's study logs (0 if not studied today),
            // never falling back to the weekly/all-time accumulated total in model.studyMs.
            final ms = subjectTimesById[model.id] ?? subjectTimesByName[model.title] ?? 0;
            return model.copyWith(studyMs: ms);
          })
          .where((s) => !s.isDeleted)
          .toList();
    }

    if (todayTotalMs == 0 && subjects.isNotEmpty) {
      todayTotalMs = subjects.fold<int>(0, (sum, s) => sum + s.studyMs);
    }

    return SubjectFetchResult(
      subjects: subjects,
      todayTotalMs: todayTotalMs,
      todayRestMs: todayRestMs,
    );
  }

  Future<bool> deleteSubject(int subjectId) async {
    try {
      final response = await _apiClient.post(
        '/user/subject/hard-delete',
        data: {'id': subjectId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> updateSubject(SubjectModel subject) async {
    try {
      final response = await _apiClient.post(
        '/user/subject/edit',
        data: {
          'id': subject.id,
          'title': subject.title,
          'color': subject.colorInt,
          'is_archived': subject.isArchived,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> archiveSubject(int subjectId, bool isArchived) async {
    try {
      final response = await _apiClient.post(
        '/user/subject/archive/change',
        data: {
          'id': subjectId,
          'is_archived': isArchived,
          'new': true,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> reorderSubjects(List<int> subjectIds) async {
    try {
      final orders = [
        for (int i = 0; i < subjectIds.length; i++)
          {'id': subjectIds[i], 'order': i + 1}
      ];
      final response = await _apiClient.post(
        '/user/subject/orders',
        data: {'orders': orders},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }
}

