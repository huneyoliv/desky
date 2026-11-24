import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/study_day_helper.dart';
import '../../data/models/todo_item_model.dart';
import '../../data/repositories/planner_repository.dart';
import '../planner/planner_screen.dart' show plannerRepositoryProvider;
import '../settings/settings_notifier.dart';
import '../timer/timer_notifier.dart';

final todoNotifierProvider =
    StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  final repository = ref.watch(plannerRepositoryProvider);
  return TodoNotifier(repository: repository, ref: ref);
});

class TodoState {
  const TodoState({
    this.todos = const [],
    this.openTodos = const [],
    this.isLoading = true,
    this.selectedDay,
    this.errorMessage,
    this.isStarting = false,
  });

  final List<TodoItemModel> todos;

  /// Unticked tasks from today and the previous [TodoNotifier.carryOverDays]
  /// days, whatever day is selected. A task stays here until it is ticked.
  final List<TodoItemModel> openTodos;
  final bool isLoading;

  /// Day being shown, 'yyyy-MM-dd'. Null means the current study day.
  final String? selectedDay;
  final String? errorMessage;
  final bool isStarting;

  TodoState copyWith({
    List<TodoItemModel>? todos,
    List<TodoItemModel>? openTodos,
    bool? isLoading,
    String? selectedDay,
    bool clearSelectedDay = false,
    String? errorMessage,
    bool clearError = false,
    bool? isStarting,
  }) {
    return TodoState(
      todos: todos ?? this.todos,
      openTodos: openTodos ?? this.openTodos,
      isLoading: isLoading ?? this.isLoading,
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isStarting: isStarting ?? this.isStarting,
    );
  }
}

/// To-Do list backed by the same API the planner uses.
///
/// The endpoints are `/study/study-plan/get-by-date` (read) and
/// `/study/study-plan/rest` (create, update, delete), already implemented in
/// [PlannerRepository]. This notifier adds standalone-screen behavior without
/// creating a second task store.
class TodoNotifier extends StateNotifier<TodoState> {
  TodoNotifier({
    required PlannerRepository repository,
    required Ref ref,
  })  : _repository = repository,
        _ref = ref,
        super(const TodoState()) {
    refresh();
  }

  final PlannerRepository _repository;
  final Ref _ref;

  Duration get _gmtOffset {
    final country = _ref.read(settingsNotifierProvider).selectedCountry;
    return country.gmtOffsetDuration ?? const Duration(hours: 0);
  }

  int get _resetHour => _ref.read(settingsNotifierProvider).dayResetHour;

  String get todayKey => StudyDayHelper.todayYmd(
        gmtOffset: _gmtOffset,
        resetHour: _resetHour,
      );

  String get activeDay => state.selectedDay ?? todayKey;

  bool get isToday => activeDay == todayKey;

  /// How far back unticked tasks are carried over.
  static const int carryOverDays = 30;

  Future<void> refresh() async {
    final day = activeDay;
    state = state.copyWith(isLoading: true, clearError: true);
    // Independent requests: a slow carry-over fetch never holds the day list.
    unawaited(_refreshOpen());
    final todos = await _repository.fetchTodos(
      day,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
    );
    if (mounted && activeDay == day) {
      state = state.copyWith(todos: todos, isLoading: false);
    }
  }

  int _openGeneration = 0;

  Future<void> _refreshOpen() async {
    final generation = ++_openGeneration;
    final open = await _fetchOpen();
    // Only the latest request wins, so an older answer cannot undo a tick.
    if (!mounted || generation != _openGeneration) return;
    state = state.copyWith(openTodos: _sortOpen(open));
  }

  Future<List<TodoItemModel>> _fetchOpen() {
    final today = todayKey;
    final from = DateTime.tryParse(today)?.subtract(const Duration(days: carryOverDays));
    return _repository.fetchOpenTodos(
      from == null ? today : StudyDayHelper.formatYmd(from),
      today,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
    );
  }

  /// Newest day first, keeping the server's order within a day.
  static List<TodoItemModel> _sortOpen(List<TodoItemModel> open) {
    final indexed = open.asMap().entries.toList()
      ..sort((a, b) {
        final c = b.value.dateYmd.compareTo(a.value.dateYmd);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  void selectDay(String? day) {
    state = day == null
        ? state.copyWith(clearSelectedDay: true)
        : state.copyWith(selectedDay: day);
    refresh();
  }

  void shiftDay(int delta) {
    final parsed = DateTime.tryParse(activeDay) ?? DateTime.now();
    final moved = DateTime(parsed.year, parsed.month, parsed.day)
        .add(Duration(days: delta));
    final ymd = '${moved.year.toString().padLeft(4, '0')}-'
        '${moved.month.toString().padLeft(2, '0')}-'
        '${moved.day.toString().padLeft(2, '0')}';
    selectDay(ymd);
  }

  /// Creates a task on [dateYmd] (default: the selected day). Returns false
  /// when the API rejects it.
  Future<bool> add(String title, {int? subjectId, String? dateYmd}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    final created = await _repository.createTodo(
      title: trimmed,
      dateYmd: dateYmd ?? activeDay,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
      subjectId: subjectId,
    );
    if (created == null) {
      if (mounted) state = state.copyWith(errorMessage: 'create_failed');
      return false;
    }
    await refresh();
    return true;
  }

  Future<bool> toggle(TodoItemModel todo) async {
    final ok = await _repository.toggleTodo(
      todo,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
    );
    await refresh();
    if (mounted && !ok) state = state.copyWith(errorMessage: 'update_failed');
    return ok;
  }

  Future<bool> rename(
    TodoItemModel todo,
    String newTitle, {
    int? subjectId,
    bool updateSubject = false,
  }) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return false;
    final ok = await _repository.editTodo(
      todo,
      trimmed,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
      applyToAll: todo.isRecurring,
      subjectId: subjectId,
      updateSubject: updateSubject,
    );
    await refresh();
    if (mounted && !ok) state = state.copyWith(errorMessage: 'update_failed');
    return ok;
  }

  Future<bool> remove(
    TodoItemModel todo, {
    bool deleteAllSeries = false,
  }) async {
    final ok = await _repository.deleteTodo(
      todo.id,
      deleteAllSeries: deleteAllSeries,
    );
    await refresh();
    if (mounted && !ok) state = state.copyWith(errorMessage: 'delete_failed');
    return ok;
  }

  /// Starts the real timer with the task's subject. The API accepts taskId on
  /// /study/start, but no task-association field was observable; this method
  /// therefore reports only whether the local timer actually started.
  Future<bool> startStudy(TodoItemModel todo) async {
    if (state.isStarting) return false;
    if (todo.isCompleted || todo.subjectId == null) {
      if (mounted) state = state.copyWith(errorMessage: 'start_failed');
      return false;
    }

    final timerState = _ref.read(timerNotifierProvider);
    if (timerState.isRunning || timerState.isPaused) {
      if (mounted) state = state.copyWith(errorMessage: 'start_failed');
      return false;
    }
    final matches = timerState.subjects.where((s) => s.id == todo.subjectId);
    if (matches.isEmpty) {
      if (mounted) state = state.copyWith(errorMessage: 'start_failed');
      return false;
    }

    state = state.copyWith(isStarting: true, clearError: true);
    try {
      final timer = _ref.read(timerNotifierProvider.notifier);
      timer.selectSubject(matches.first);
      await timer.startStudy(taskId: todo.id);
      final started = _ref.read(timerNotifierProvider).isRunning;
      if (mounted && !started) {
        state = state.copyWith(errorMessage: 'start_failed');
      }
      return started;
    } catch (_) {
      if (mounted) state = state.copyWith(errorMessage: 'start_failed');
      return false;
    } finally {
      if (mounted) state = state.copyWith(isStarting: false);
    }
  }

  ({int total, int done}) get progress {
    final total = state.todos.length;
    final done = state.todos.where((t) => t.isCompleted).length;
    return (total: total, done: done);
  }
}
