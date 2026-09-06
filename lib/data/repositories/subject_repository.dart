import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String keyCachedSubjects = 'cached_subjects_data';

  SubjectRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<void> cacheSubjects(List<SubjectModel> subjects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = subjects.map((s) => s.toJson()).toList();
      await prefs.setString(keyCachedSubjects, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<SubjectModel>> getCachedSubjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyCachedSubjects);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => SubjectModel.fromJson(Map<String, dynamic>.from(m)))
              .where((s) => !s.isDeleted)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveSubjectsFromRawData(dynamic data) async {
    if (data is! Map) return;
    final rawList = data['ss'] ?? (data['p'] is Map ? data['p']['ss'] : null);
    if (rawList is List && rawList.isNotEmpty) {
      try {
        final subjects = rawList
            .whereType<Map>()
            .map((m) => SubjectModel.fromJson(Map<String, dynamic>.from(m)))
            .where((s) => !s.isDeleted)
            .toList();
        if (subjects.isNotEmpty) {
          final repo = SubjectRepository();
          await repo.cacheSubjects(subjects);
        }
      } catch (_) {}
    }
  }

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

    final raw = response.data;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (data['s'] != true) {
      throw Exception(data['m'] ?? 'Falha ao criar matéria');
    }

    final sb = data['sb'] as Map<String, dynamic>? ?? data['subject'] as Map<String, dynamic>?;
    final created = sb != null ? SubjectModel.fromJson(sb) : SubjectModel.fromJson(data);

    try {
      final cached = await getCachedSubjects();
      final updated = [...cached.where((s) => s.id != created.id), created];
      await cacheSubjects(updated);
    } catch (_) {}

    return created;
  }

  Future<SubjectFetchResult> fetchSubjectsData({
    String language = ApiConstants.defaultLanguage,
    String timezone = ApiConstants.defaultTimezone,
    int version = ApiConstants.defaultVersion,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.reloadInfo,
        data: {
          'pv': 0,
          'version': version,
          'language': language,
          'timezone': timezone,
          'deviceModel': ApiConstants.defaultDeviceModel,
          'cd': {
            'su': null,
            'sbu': null,
            'cu': null,
            'eu': null,
            'du': null,
            'tu': null,
          },
        },
      );
      final raw = response.data;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        final result = _parseSplashData(data);
        if (result.subjects.isNotEmpty) {
          await cacheSubjects(result.subjects);
          return result;
        }
      }
    } catch (_) {}

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
      final raw = response.data;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        final result = _parseSplashData(data);
        if (result.subjects.isNotEmpty) {
          await cacheSubjects(result.subjects);
          return result;
        } else {
          final cached = await getCachedSubjects();
          if (cached.isNotEmpty) {
            final merged = _applyTimesToSubjects(cached, data['dl'] as Map<String, dynamic>?);
            return SubjectFetchResult(
              subjects: merged,
              todayTotalMs: result.todayTotalMs,
              todayRestMs: result.todayRestMs,
            );
          }
        }
      }
    } catch (_) {}

    final cached = await getCachedSubjects();
    if (cached.isNotEmpty) {
      return SubjectFetchResult(subjects: cached, todayTotalMs: 0, todayRestMs: 0);
    }

    return const SubjectFetchResult(subjects: [], todayTotalMs: 0, todayRestMs: 0);
  }

  Future<List<SubjectModel>> fetchSubjects() async {
    final result = await fetchSubjectsData();
    return result.subjects;
  }

  List<SubjectModel> _applyTimesToSubjects(List<SubjectModel> subjects, Map<String, dynamic>? dl) {
    if (dl == null) return subjects;
    final Map<int, int> timesById = {};
    final Map<String, int> timesByName = {};

    if (dl['ls'] is List) {
      for (final item in dl['ls']) {
        if (item is Map) {
          final name = item['sb'] as String? ?? '';
          final id = item['id'] as int? ?? item['subjectId'] as int?;
          final ms = item['sm'] as int? ?? 0;
          if (name.isNotEmpty) timesByName[name] = (timesByName[name] ?? 0) + ms;
          if (id != null) timesById[id] = (timesById[id] ?? 0) + ms;
        }
      }
    }

    if (dl['ss'] is List) {
      for (final item in dl['ss']) {
        if (item is Map) {
          final id = item['id'] as int?;
          final name = item['tt'] as String? ?? '';
          final ms = item['sm'] as int? ?? 0;
          if (id != null) timesById[id] = (timesById[id] ?? 0) + ms;
          if (name.isNotEmpty) timesByName[name] = (timesByName[name] ?? 0) + ms;
        }
      }
    }

    return subjects.map((s) {
      final ms = timesById[s.id] ?? timesByName[s.title] ?? 0;
      return s.copyWith(studyMs: ms);
    }).toList();
  }

  SubjectFetchResult _parseSplashData(Map<String, dynamic> data) {
    final rawList = data['ss'] ?? (data['p'] is Map ? data['p']['ss'] : null);
    final dl = data['dl'] is Map ? Map<String, dynamic>.from(data['dl'] as Map) : null;

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
          if (item is Map) {
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
          if (item is Map) {
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
          .whereType<Map>()
          .map((item) {
            final model = SubjectModel.fromJson(Map<String, dynamic>.from(item));
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

