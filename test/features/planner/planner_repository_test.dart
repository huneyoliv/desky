import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/utils/study_date_helper.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.handler) : super(customDio: Dio());

  final Future<Response<dynamic>> Function(
    String path,
    Map<String, dynamic>? query,
    Object? body,
  ) handler;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) {
    return handler(path, queryParameters, null);
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) {
    return handler(path, null, data);
  }

  @override
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) {
    return handler(path, null, data);
  }

  @override
  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Options? options,
    String? baseUrl,
  }) {
    return handler(path, queryParameters, data);
  }
}

Response<dynamic> _json(Object? data) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      data: data,
      statusCode: 200,
    );

void main() {
  const brazil = Duration(hours: -3);

  group('Planner Models Tests', () {
    test('DDayModel calculates daysRemaining and label correctly', () {
      final studyToday = StudyDateHelper.getStudyDate();
      final targetFuture = studyToday.add(const Duration(days: 10));
      final dday = DDayModel(
        id: 1,
        title: 'Prova',
        targetDate: targetFuture,
        colorInt: 4294948685,
      );

      expect(dday.daysRemaining, equals(10));
      expect(dday.label, equals('D-10'));
    });

    test('TodoItemModel parses study-plan HAR JSON response correctly', () {
      final json = {
        'id': 111625709,
        't': 'Resolver questões',
        'sa': '2026-08-25T00:05:00.000Z',
        's': 1,
        'sd': 119611290,
      };

      final item = TodoItemModel.fromJson(json);
      expect(item.id, equals(111625709));
      expect(item.title, equals('Resolver questões'));
      expect(item.subjectId, equals(119611290));
      expect(item.isCompleted, isTrue);
      expect(item.startAtRaw, equals('2026-08-25T00:05:00.000Z'));
      expect(item.startAt, equals(DateTime.utc(2026, 8, 25, 0, 5)));
      // The study-day alignment is applied by PlannerRepository, which knows
      // the country offset; the raw parse keeps the payload date as fallback.
      expect(item.dateYmd, equals('2026-08-25'));
      expect(item.isRecurring, isFalse);
    });

    test('TodoItemModel parses recurrence_rule and isRecurring correctly', () {
      final json = {
        'id': 111626006,
        't': 'Estudar exatas',
        'sa': '2026-08-10T00:15:00.000Z',
        's': null,
        'sd': 119736077,
        'rr': {
          'id': 111626006,
          'i': 1,
          'f': 1,
          'w': [1, 2, 3, 4, 5],
          'e': '2026-09-09T21:15:00.000'
        }
      };

      final item = TodoItemModel.fromJson(json);
      expect(item.id, equals(111626006));
      expect(item.isRecurring, isTrue);
      expect(item.recurrenceRule, isNotNull);
      expect(item.recurrenceRule!.daysOfWeek, equals([1, 2, 3, 4, 5]));
      expect(item.recurrenceRule!.endDate, equals('2026-09-09T21:15:00.000'));
    });
  });

  group('PlannerRepository study day window', () {
    test('queries the YPT study day with a safety margin', () async {
      Map<String, dynamic>? captured;
      final repo = PlannerRepository(
        apiClient: _FakeApiClient((path, query, body) async {
          captured = query;
          return _json({'s': true, 'r': <dynamic>[]});
        }),
      );

      await repo.fetchTodos('2026-11-01', gmtOffset: brazil);

      expect(captured, isNotNull);
      expect(captured!['start_at'], '2026-10-31T20:00:00.000Z');
      expect(captured!['end_at'], '2026-11-02T20:00:00.000Z');
      expect(captured!['is_unscheduled'], 'true');
    });

    test('keeps only todos that belong to the requested study day', () async {
      final repo = PlannerRepository(
        apiClient: _FakeApiClient((path, query, body) async {
          return _json({
            's': true,
            'r': [
              {'id': 1, 't': 'before', 'sa': '2026-11-01T07:59:00.000Z'},
              {'id': 2, 't': 'boundary', 'sa': '2026-11-01T08:00:00.000Z'},
              {'id': 3, 't': 'late night', 'sa': '2026-11-02T07:59:00.000Z'},
              {'id': 4, 't': 'next day', 'sa': '2026-11-02T08:00:00.000Z'},
            ],
          });
        }),
      );

      final todos = await repo.fetchTodos('2026-11-01', gmtOffset: brazil);

      expect(todos.map((t) => t.id), equals([2, 3]));
      expect(todos.every((t) => t.dateYmd == '2026-11-01'), isTrue);
    });

    test('aligns the payload date with the study day, not the UTC date', () async {
      final repo = PlannerRepository(
        apiClient: _FakeApiClient((path, query, body) async {
          return _json({
            's': true,
            'r': [
              {'id': 7, 't': 'early', 'sa': '2026-11-02T03:00:00.000Z'},
            ],
          });
        }),
      );

      final todos = await repo.fetchTodos('2026-11-01', gmtOffset: brazil);

      expect(todos.single.dateYmd, '2026-11-01');
    });
  });

  group('PlannerRepository writes', () {
    test('createTodo sends the study day start instant', () async {
      Object? payload;
      final repo = PlannerRepository(
        apiClient: _FakeApiClient((path, query, body) async {
          payload = body;
          return _json({
            's': true,
            'r': {'id': 9, 't': 'nova', 'sa': '2026-11-01T08:00:00Z'},
          });
        }),
      );

      final created = await repo.createTodo(
        title: 'nova',
        dateYmd: '2026-11-01',
        gmtOffset: brazil,
      );

      final map = payload as Map<String, dynamic>;
      expect(map['start_at'], '2026-11-01T08:00:00.000Z');
      expect(created, isNotNull);
      expect(created!.dateYmd, '2026-11-01');
    });

    test('toggleTodo preserves the original time of day', () async {
      Object? payload;
      final repo = PlannerRepository(
        apiClient: _FakeApiClient((path, query, body) async {
          payload = body;
          return _json({'s': true});
        }),
      );

      final todo = TodoItemModel.fromJson({
        'id': 9,
        't': 'aula',
        'sa': '2026-11-01T12:15:00.000Z',
      });

      final ok = await repo.toggleTodo(todo, gmtOffset: brazil);

      expect(ok, isTrue);
      expect((payload as Map<String, dynamic>)['start_at'], '2026-11-01T12:15:00.000Z');
    });

    test('editTodo falls back to the study day start when the payload has no date', () async {
      Object? payload;
      final repo = PlannerRepository(
        apiClient: _FakeApiClient((path, query, body) async {
          payload = body;
          return _json({'s': true});
        }),
      );

      const todo = TodoItemModel(
        id: 11,
        title: 'sem data',
        subjectTitle: 'Geral',
        subjectColorInt: 0,
        isCompleted: false,
        dateYmd: '2026-11-01',
      );

      await repo.editTodo(todo, 'renomeada', gmtOffset: brazil);

      expect((payload as Map<String, dynamic>)['start_at'], '2026-11-01T08:00:00.000Z');
    });
  });
}
