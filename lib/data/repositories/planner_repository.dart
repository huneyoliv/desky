import '../../core/api/api_client.dart';
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

  Future<List<TodoItemModel>> fetchTodos(String dateYmd) async {
    try {
      final response = await _apiClient.get(
        '/study/study-plan/get-by-date?start_at=${dateYmd}T00:00:00.000Z&end_at=${dateYmd}T23:59:59.000Z&is_unscheduled=true',
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final rawList = data['r'] ?? data['todos'];
        if (rawList is List) {
          return rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => TodoItemModel.fromJson(item))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<TodoItemModel?> createTodo({
    required String title,
    required String dateYmd,
    int? subjectId,
    RecurrenceRuleModel? recurrenceRule,
  }) async {
    try {
      final payload = <String, dynamic>{
        'title': title,
        'subject_id': subjectId,
        'start_at': '${dateYmd}T00:00:00.000Z',
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
          return TodoItemModel.fromJson(raw);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> toggleTodo(TodoItemModel todo) async {
    try {
      final newScore = todo.isCompleted ? null : 1;
      final response = await _apiClient.put(
        '/study/study-plan/rest',
        data: {
          'id': todo.id,
          'title': todo.title,
          'subject_id': todo.subjectId,
          'start_at': '${todo.dateYmd}T00:00:00.000Z',
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
    RecurrenceRuleModel? recurrenceRule,
    bool applyToAll = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': todo.id,
        'title': newTitle,
        'subject_id': todo.subjectId,
        'start_at': '${todo.dateYmd}T00:00:00.000Z',
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
