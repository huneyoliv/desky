import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/study_date_helper.dart';
import '../../data/models/todo_model.dart';
import '../../data/repositories/todo_repository.dart';
import '../settings/settings_notifier.dart';

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository(prefs: ref.watch(sharedPreferencesProvider));
});

final todoNotifierProvider =
    StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  final resetHour = ref.watch(
    settingsNotifierProvider.select((settings) => settings.dayResetHour),
  );
  return TodoNotifier(repository: repository, dayResetHour: resetHour);
});

class TodoState {
  const TodoState({
    this.todos = const [],
    this.isLoading = true,
    this.selectedDay,
  });

  final List<TodoModel> todos;
  final bool isLoading;

  /// Day being shown, 'yyyy-MM-dd'. Null means "the current study day".
  final String? selectedDay;

  TodoState copyWith({
    List<TodoModel>? todos,
    bool? isLoading,
    String? selectedDay,
    bool clearSelectedDay = false,
  }) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
    );
  }
}

/// Owns the To-Do list: loading, adding, toggling and removing.
///
/// The day rule follows the rest of the app (`StudyDateHelper`, reset hour from
/// the settings), so a task created at 02:00 with a 05:00 reset lands on the
/// previous study day instead of the civil one.
class TodoNotifier extends StateNotifier<TodoState> {
  TodoNotifier({
    required TodoRepository repository,
    int dayResetHour = StudyDateHelper.defaultResetHour,
  })  : _repository = repository,
        _dayResetHour = dayResetHour,
        super(const TodoState()) {
    _load();
  }

  final TodoRepository _repository;
  int _dayResetHour;

  void setDayResetHour(int hour) {
    if (hour == _dayResetHour) return;
    _dayResetHour = hour;
  }

  /// Today in study-day terms, as 'yyyy-MM-dd'.
  String get todayKey => StudyDateHelper.getStudyDateString(
        DateTime.now(),
        _dayResetHour,
      );

  /// The day currently being displayed.
  String get activeDay => state.selectedDay ?? todayKey;

  Future<void> _load() async {
    final todos = await _repository.load();
    if (!mounted) return;
    state = state.copyWith(todos: todos, isLoading: false);
  }

  /// Tasks of [day], or of the active day when omitted.
  List<TodoModel> forDay([String? day]) {
    final target = day ?? activeDay;
    return state.todos
        .where((todo) => todo.day == target)
        .toList()
      ..sort(_sortForDisplay);
  }

  int _sortForDisplay(TodoModel a, TodoModel b) {
    // Open tasks first, then by start time.
    if (a.done != b.done) return a.done ? 1 : -1;
    final aMinute = a.startMinute;
    final bMinute = b.startMinute;
    if (aMinute == null && bMinute == null) {
      return a.createdAt.compareTo(b.createdAt);
    }
    if (aMinute == null) return 1;
    if (bMinute == null) return -1;
    if (aMinute != bMinute) return aMinute.compareTo(bMinute);
    return a.createdAt.compareTo(b.createdAt);
  }

  void selectDay(String? day) {
    state = day == null
        ? state.copyWith(clearSelectedDay: true)
        : state.copyWith(selectedDay: day);
  }

  /// Identifier for a new task.
  ///
  /// Two tasks created in the same millisecond would otherwise share the
  /// timestamp id, and toggling one would toggle both. The value is bumped until
  /// it is unused.
  int _nextId(DateTime now) {
    var candidate = now.millisecondsSinceEpoch;
    final used = state.todos.map((todo) => todo.id).toSet();
    while (used.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  /// Adds a task to [day] (or the active day) and returns it.
  Future<TodoModel?> add({
    required String title,
    String note = '',
    String? day,
    int? startMinute,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final now = DateTime.now();
    final todo = TodoModel(
      id: _nextId(now),
      title: trimmed,
      note: note.trim(),
      day: day ?? activeDay,
      startMinute: startMinute,
      createdAt: now,
    );

    final updated = [...state.todos, todo];
    state = state.copyWith(todos: updated);
    await _repository.save(updated);
    return todo;
  }

  Future<void> toggleDone(int id) async {
    final now = DateTime.now();
    final updated = state.todos.map((todo) {
      if (todo.id != id) return todo;
      final nextDone = !todo.done;
      return todo.copyWith(
        done: nextDone,
        completedAt: nextDone ? now : null,
        clearCompletedAt: !nextDone,
      );
    }).toList();

    state = state.copyWith(todos: updated);
    await _repository.save(updated);
  }

  Future<void> update({
    required int id,
    String? title,
    String? note,
    int? startMinute,
    bool clearStartMinute = false,
  }) async {
    final updated = state.todos.map((todo) {
      if (todo.id != id) return todo;
      final nextTitle = title?.trim();
      return todo.copyWith(
        title: nextTitle == null || nextTitle.isEmpty ? todo.title : nextTitle,
        note: note,
        startMinute: startMinute,
        clearStartMinute: clearStartMinute,
      );
    }).toList();

    state = state.copyWith(todos: updated);
    await _repository.save(updated);
  }

  Future<void> remove(int id) async {
    final updated = state.todos.where((todo) => todo.id != id).toList();
    state = state.copyWith(todos: updated);
    await _repository.save(updated);
  }

  /// Moves a task to another day, keeping its other fields.
  Future<void> moveToDay(int id, String day) async {
    final updated = state.todos
        .map((todo) => todo.id == id ? todo.copyWith(day: day) : todo)
        .toList();
    state = state.copyWith(todos: updated);
    await _repository.save(updated);
  }

  /// Counters for the header: total and completed on the active day.
  ({int total, int done}) progressForActiveDay() {
    final tasks = forDay();
    return (total: tasks.length, done: tasks.where((t) => t.done).length);
  }
}