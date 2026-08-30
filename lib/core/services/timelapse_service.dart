import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/timelapse_session_model.dart';

class TimelapseService {
  static const String _storageKey = 'desky_timelapse_sessions_v1';

  Future<Directory> _getTimelapseDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final timelapseDir = Directory('${appDir.path}/desky_timelapses');
    if (!timelapseDir.existsSync()) {
      timelapseDir.createSync(recursive: true);
    }
    return timelapseDir;
  }

  Future<List<TimelapseSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ?? [];
    return rawList.map((e) => TimelapseSession.decode(e)).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> saveSession(TimelapseSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.insert(0, session);
    }
    final rawList = sessions.map((s) => s.encode()).toList();
    await prefs.setStringList(_storageKey, rawList);
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    final rawList = sessions.map((s) => s.encode()).toList();
    await prefs.setStringList(_storageKey, rawList);

    try {
      final baseDir = await _getTimelapseDirectory();
      final sessionDir = Directory('${baseDir.path}/$sessionId');
      if (sessionDir.existsSync()) {
        sessionDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  Future<String> saveFrame({
    required String sessionId,
    required int frameIndex,
    required Uint8List bytes,
  }) async {
    final baseDir = await _getTimelapseDirectory();
    final sessionDir = Directory('${baseDir.path}/$sessionId');
    if (!sessionDir.existsSync()) {
      sessionDir.createSync(recursive: true);
    }
    final filePath = '${sessionDir.path}/frame_${frameIndex.toString().padLeft(5, '0')}.jpg';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }
}
