import '../../core/api/api_client.dart';
import '../../core/utils/study_day_helper.dart';
import '../models/dday_model.dart';
import '../models/todo_item_model.dart';

class PlannerRepository {
  final ApiClient _apiClient;

  PlannerRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<DDayModel>> fetchDDays() async {
    try {
      final response = await _apiClient.get('/planner/ddays');
      final data = response.data;
      if (data is Map<String, dynamic> && data['ddays'] is List) {
        final list = data['ddays'] as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => DDayModel.fromJson(item))
            .toList();
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
        '/planner/dday',
        data: {
          'title': title,
          'targetDate': targetDate.toIso8601String(),
          'color': colorInt,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && (data['s'] == true || data['id'] != null)) {
        final raw = data['dday'] ?? data;
        if (raw is Map<String, dynamic>) {
          return DDayModel.fromJson(raw);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteDDay(int ddayId) async {
    try {
      final response = await _apiClient.delete('/planner/dday/$ddayId');
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {
      return false;
    }
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
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': todo.id,
        'title': newTitle,
        'subject_id': todo.subjectId,
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
      final query = deleteAllSeries ? '?id=$todoId&target=all' : '?id=$todoId';
      final response = await _apiClient.delete(
        '/study/study-plan/rest$query',
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['s'] == true;
    } catch (_) {}
    return false;
  }
}
