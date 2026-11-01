import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of an in-progress study session.
///
/// YPT keeps the session open on the server until an explicit stop, so losing
/// the in-memory state (crash, update, forced exit) used to leave the desktop
/// showing "idle" while the phone kept counting. Persisting the snapshot lets
/// the app rebuild the session on the next launch.
class TimerSessionSnapshot {
  final int subjectId;
  final String subjectTitle;
  final DateTime startAt;

  const TimerSessionSnapshot({
    required this.subjectId,
    required this.subjectTitle,
    required this.startAt,
  });

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'subject_title': subjectTitle,
        'start_at': startAt.toUtc().millisecondsSinceEpoch,
      };

  factory TimerSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final startMs = json['start_at'];
    final startAt = startMs is int
        ? DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true)
        : DateTime.now().toUtc();
    return TimerSessionSnapshot(
      subjectId: json['subject_id'] as int? ?? -1,
      subjectTitle: json['subject_title'] as String? ?? '',
      startAt: startAt,
    );
  }
}

class TimerSessionStore {
  static const String storageKey = 'desky_active_timer_session';

  final SharedPreferences? _prefs;

  TimerSessionStore({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<void> save(TimerSessionSnapshot snapshot) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
    } catch (_) {}
  }

  Future<TimerSessionSnapshot?> load() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final snapshot = TimerSessionSnapshot.fromJson(decoded);
      final age = DateTime.now().toUtc().difference(snapshot.startAt);
      // A crash days ago must not resurrect a stale session and inflate the
      // reported study time, so snapshots older than a study day are dropped.
      if (age < const Duration(minutes: -1) || age > const Duration(hours: 24)) {
        await clear();
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(storageKey);
    } catch (_) {}
  }
}
