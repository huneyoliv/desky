import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/study_day_helper.dart';
import '../../data/models/todo_item_model.dart';
import '../../data/repositories/planner_repository.dart';
import '../planner/planner_screen.dart' show plannerRepositoryProvider;
import '../settings/settings_notifier.dart';

final todoNotifierProvider =
    StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  final repository = ref.watch(plannerRepositoryProvider);
  return TodoNotifier(repository: repository, ref: ref);
});

class TodoState {
  const TodoState({
    this.todos = const [],
    this.isLoading = true,
    this.selectedDay,
    this.errorMessage,
  });

  final List<TodoItemModel> todos;
  final bool isLoading;

  /// Day being shown, 'yyyy-MM-dd'. Null means the current study day.
  final String? selectedDay;
  final String? errorMessage;

  TodoState copyWith({
    List<TodoItemModel>? todos,
    bool? isLoading,
    String? selectedDay,
    bool clearSelectedDay = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// To-Do list backed by the same API the planner uses.
///
/// The endpoints are `/study/study-plan/get-by-date` (read) and
/// `/study/study-plan/rest` (create, update, delete), already implemented in
/// [PlannerRepository]. This notifier only adds the day navigation the standalone
/// screen needs; it does not reimplement the contract.
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

  /// The account's study-day offset, same source the planner uses.
  Duration get _gmtOffset {
    final country = _ref.read(settingsNotifierProvider).selectedCountry;
    return country.gmtOffsetDuration ?? const Duration(hours: 0);
  }

  int get _resetHour =>
      _ref.read(settingsNotifierProvider).dayResetHour;

  String get todayKey => StudyDayHelper.todayYmd(
        gmtOffset: _gmtOffset,
        resetHour: _resetHour,
      );

  String get activeDay => state.selectedDay ?? todayKey;

  bool get isToday => activeDay == todayKey;

  Future<void> refresh() async {
    final day = activeDay;
    state = state.copyWith(isLoading: true, clearError: true);
    final todos = await _repository.fetchTodos(
      day,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
    );
    if (!mounted || activeDay != day) return;
    state = state.copyWith(todos: todos, isLoading: false);
  }

  void selectDay(String? day) {
    state = day == null
        ? state.copyWith(clearSelectedDay: true)
        : state.copyWith(selectedDay: day);
    refresh();
  }

  void shiftDay(int delta) {
    final parsed = DateTime.tryParse(activeDay) ?? DateTime.now();
    final moved =
        DateTime(parsed.year, parsed.month, parsed.day).add(Duration(days: delta));
    final ymd = '${moved.year.toString().padLeft(4, '0')}-'
        '${moved.month.toString().padLeft(2, '0')}-'
        '${moved.day.toString().padLeft(2, '0')}';
    selectDay(ymd);
  }

  /// Creates a task on the active day. Returns false when the API rejects it.
  Future<bool> add(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    final created = await _repository.createTodo(
      title: trimmed,
      dateYmd: activeDay,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
    );
    if (created == null) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: 'create_failed',
        );
      }
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
    // Refresh regardless: when the write fails the list must not keep the
    // optimistic value.
    await refresh();
    return ok;
  }

  Future<bool> rename(TodoItemModel todo, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return false;
    final ok = await _repository.editTodo(
      todo,
      trimmed,
      gmtOffset: _gmtOffset,
      resetHour: _resetHour,
      applyToAll: todo.isRecurring,
    );
    await refresh();
    return ok;
  }

  Future<bool> remove(TodoItemModel todo) async {
    final ok = await _repository.deleteTodo(
      todo.id,
      deleteAllSeries: todo.isRecurring,
    );
    await refresh();
    return ok;
  }

  /// Completed and total counters for the visible day.
  ({int total, int done}) get progress {
    final total = state.todos.length;
    final done = state.todos.where((t) => t.isCompleted).length;
    return (total: total, done: done);
  }
}