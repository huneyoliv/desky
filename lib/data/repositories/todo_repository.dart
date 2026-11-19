import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_model.dart';

/// Local storage for the To-Do list.
///
/// The list is deliberately local. The official API exposes
/// `GET /logs/calendar/todos` but never returned an element, and its creation
/// route (`POST /study/task/make`) answers a Django 500 page to every method and
/// payload tried, so a server-backed list could not be built or verified. The
/// model keeps the field names the official binary revealed so a future sync can
/// map onto it without a rewrite.
class TodoRepository {
  TodoRepository({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String storageKey = 'todo_list_v1';

  Future<SharedPreferences> _requirePrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<List<TodoModel>> load() async {
    try {
      final prefs = await _requirePrefs();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final out = <TodoModel>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final todo = TodoModel.fromJson(Map<String, dynamic>.from(entry));
        // A row without a title or day cannot be shown or grouped.
        if (todo.title.isEmpty || todo.day.isEmpty) continue;
        out.add(todo);
      }
      out.sort(_byDayThenTime);
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TodoModel> todos) async {
    try {
      final prefs = await _requirePrefs();
      final ordered = [...todos]..sort(_byDayThenTime);
      await prefs.setString(
        storageKey,
        jsonEncode(ordered.map((todo) => todo.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Ascending by day, then by start time, with tasks that have no time last.
  static int _byDayThenTime(TodoModel a, TodoModel b) {
    final byDay = a.day.compareTo(b.day);
    if (byDay != 0) return byDay;

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
}