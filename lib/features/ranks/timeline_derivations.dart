import 'session_derivations.dart';

class TimelineGap {
  const TimelineGap({
    required this.afterSessionIndex,
    required this.startMinute,
    required this.endMinute,
  });

  final int afterSessionIndex;
  final int startMinute;
  final int endMinute;

  int get durationMinutes => endMinute - startMinute;
}

class TimelineDaySummary {
  const TimelineDaySummary({
    required this.sessions,
    required this.gaps,
    required this.totalStudyMs,
  });

  final List<StudySession> sessions;
  final List<TimelineGap> gaps;
  final int totalStudyMs;

  int get totalGapMinutes =>
      gaps.fold(0, (total, gap) => total + gap.durationMinutes);
}

/// Derives a chronological day without asserting that gaps are recorded rest.
TimelineDaySummary summarizeTimelineDay(
  List<StudySession> input,
  String day,
) {
  final sessions = input.where((session) => session.day == day).toList()
    ..sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.endMinute.compareTo(b.endMinute);
    });
  final gaps = <TimelineGap>[];
  var totalStudyMs = 0;
  var previousEnd = -1;

  for (var index = 0; index < sessions.length; index++) {
    final session = sessions[index];
    totalStudyMs += session.durationMs;
    if (previousEnd >= 0 && session.startMinute > previousEnd) {
      gaps.add(TimelineGap(
        afterSessionIndex: index - 1,
        startMinute: previousEnd,
        endMinute: session.startMinute,
      ));
    }
    if (session.endMinute > previousEnd) previousEnd = session.endMinute;
  }

  return TimelineDaySummary(
    sessions: sessions,
    gaps: gaps,
    totalStudyMs: totalStudyMs,
  );
}

String formatTimelineDuration(int milliseconds) {
  final minutes = (milliseconds / 60000).round();
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}min';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}min';
}
