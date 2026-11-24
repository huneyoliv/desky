import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/study_day_helper.dart';
import '../models/dday_model.dart';
import '../models/todo_item_model.dart';

class PlannerRepository {
  final ApiClient _apiClient;

  PlannerRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // Live-verified D-Day routes (see docs/api_matrix.md). The former
  // `/planner/dday` and `/planner/ddays` paths answer 404 in production.
  static const String _ddayGet = ApiConstants.ddayGet;
  static const String _ddayCreate = ApiConstants.ddayCreate;
  static const String _ddayDelete = ApiConstants.ddayDelete;

  /// Lists the account's D-Days.
  ///
  /// `GET /user/d-day/get` answers `{"s": true}` and exposes no list key, so
  /// the payload key is discovered defensively; an empty list is returned when
  /// the account has none.
  Future<List<DDayModel>> fetchDDays() async {
    try {
      final response = await _apiClient.get(_ddayGet);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['ddays'] ??
            data['dl'] ??
            data['r'] ??
            data['ls'] ??
            data['d'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => DDayModel.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<DDayModel?> createDDay({
    required String title,
    required DateTime targetDate,
    required int colorInt,
  }) async {
    try {
      final response = await _apiClient.post(
        _ddayCreate,
        data: {
          'title': title,
          'date': _formatDate(targetDate),
          'color': colorInt,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final raw = data['d'] ?? data['dday'];
        if (raw is Map<String, dynamic>) {
          return DDayModel.fromJson(raw);
        }
        // The create response may omit the record; fall back to the input.
        return DDayModel(
          id: 0,
          title: title,
          targetDate: targetDate,
          colorInt: colorInt,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Deletes a D-Day by id (`{"id": <id>}` -> `{"s": true}`).
  Future<bool> deleteDDay(int ddayId) async {
    try {
      final response = await _apiClient.post(
        _ddayDelete,
        data: {'id': ddayId},
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {
      return false;
    }
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async {
    try {
      final dayStart =
          StudyDayHelper.startUtc(dateYmd, gmtOffset: gmtOffset, resetHour: resetHour);
      final dayEnd =
          StudyDayHelper.endUtc(dateYmd, gmtOffset: gmtOffset, resetHour: resetHour);

      // YPT resolves the day boundary with the timezone stored on the account,
      // which may differ from the country registry. Querying a half-day margin
      // keeps the window inclusive; the local filter below discards neighbours.
      final response = await _apiClient.get(
        '/study/study-plan/get-by-date',
        queryParameters: {
          'start_at': StudyDayHelper.toApiIso(dayStart.subtract(const Duration(hours: 12))),
          'end_at': StudyDayHelper.toApiIso(dayEnd.add(const Duration(hours: 12))),
          'is_unscheduled': 'true',
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final rawList = data['r'] ?? data['todos'];
        if (rawList is List) {
          final items = rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => TodoItemModel.fromJson(item))
              .map((item) => _alignToStudyDay(item, gmtOffset, resetHour))
              .where((item) => item.dateYmd == dateYmd)
              .toList();
          return items;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Unticked tasks from [fromYmd] to [toYmd] (study days, inclusive), in one
  /// range request. Past occurrences of recurring tasks are left out: every
  /// missed repeat would otherwise pile up as a separate open task.
  Future<List<TodoItemModel>> fetchOpenTodos(
    String fromYmd,
    String toYmd, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async {
    try {
      final start = StudyDayHelper.startUtc(fromYmd, gmtOffset: gmtOffset, resetHour: resetHour);
      final end = StudyDayHelper.endUtc(toYmd, gmtOffset: gmtOffset, resetHour: resetHour);
      final response = await _apiClient.get(
        '/study/study-plan/get-by-date',
        queryParameters: {
          'start_at': StudyDayHelper.toApiIso(start.subtract(const Duration(hours: 12))),
          'end_at': StudyDayHelper.toApiIso(end.add(const Duration(hours: 12))),
          'is_unscheduled': 'true',
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final rawList = data['r'] ?? data['todos'];
        if (rawList is List) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => TodoItemModel.fromJson(item))
              .map((item) => _alignToStudyDay(item, gmtOffset, resetHour))
              .where((item) =>
                  !item.isCompleted &&
                  item.dateYmd.compareTo(fromYmd) >= 0 &&
                  item.dateYmd.compareTo(toYmd) <= 0 &&
                  (item.dateYmd == toYmd || !item.isRecurring))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  TodoItemModel _alignToStudyDay(
    TodoItemModel item,
    Duration gmtOffset,
    int resetHour,
  ) {
    final instant =
        item.startAt ?? StudyDayHelper.parseInstant(item.startAtRaw, gmtOffset: gmtOffset);
    if (instant == null) return item;
    return item.copyWith(
      startAt: instant,
      dateYmd:
          StudyDayHelper.studyDateYmd(instant, gmtOffset: gmtOffset, resetHour: resetHour),
    );
  }

  Future<TodoItemModel?> createTodo({
    required String title,
    required String dateYmd,
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
    int? subjectId,
    RecurrenceRuleModel? recurrenceRule,
  }) async {
    try {
      final payload = <String, dynamic>{
        'title': title,
        'subject_id': subjectId,
        'start_at': StudyDayHelper.startAtIso(dateYmd, gmtOffset: gmtOffset, resetHour: resetHour),
        'all_day': false,
        'order': 0,
        'score': null,
        'duration': null,
      };
      if (recurrenceRule != null) {
        payload['recurrence_rule'] = recurrenceRule.toJson();
      }

      final response = await _apiClient.post(
        '/study/study-plan/rest',
        data: payload,
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['s'] == true) {
        final raw = data['r'] ?? data;
        if (raw is Map<String, dynamic>) {
          return _alignToStudyDay(
            TodoItemModel.fromJson(raw).copyWith(dateYmd: dateYmd),
            gmtOffset,
            resetHour,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> toggleTodo(
    TodoItemModel todo, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async {
    try {
      final newScore = todo.isCompleted ? null : 1;
      final response = await _apiClient.put(
        '/study/study-plan/rest',
        data: {
          'id': todo.id,
          'title': todo.title,
          'subject_id': todo.subjectId,
          'start_at': todo.startAtApiIso(gmtOffset: gmtOffset, resetHour: resetHour),
          'all_day': false,
          'order': 0,
          'score': newScore,
          'duration': null,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> editTodo(
    TodoItemModel todo,
    String newTitle, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
    RecurrenceRuleModel? recurrenceRule,
    bool applyToAll = false,
    int? subjectId,
    bool updateSubject = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': todo.id,
        'title': newTitle,
        'subject_id': updateSubject ? subjectId : todo.subjectId,
        'start_at': todo.startAtApiIso(gmtOffset: gmtOffset, resetHour: resetHour),
        'all_day': false,
        'order': 0,
        'score': todo.isCompleted ? 1 : null,
        'duration': null,
      };

      if (applyToAll && (recurrenceRule != null || todo.recurrenceRule != null)) {
        final rr = recurrenceRule ?? todo.recurrenceRule;
        if (rr != null) {
          payload['recurrence_rule'] = rr.toJson();
        }
      }

      final response = await _apiClient.put(
        '/study/study-plan/rest',
        data: payload,
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }

  Future<bool> deleteTodo(int todoId, {bool deleteAllSeries = false}) async {
    try {
      final response = await _apiClient.delete(
        '/study/study-plan/rest',
        data: {
          'id': todoId,
          if (deleteAllSeries) 'target': 'all',
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }
}
