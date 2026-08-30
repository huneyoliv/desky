class StudyDateHelper {
  StudyDateHelper._();

  static const int defaultResetHour = 5;

  static DateTime getStudyDate([DateTime? targetTime, int resetHour = defaultResetHour]) {
    final now = targetTime ?? DateTime.now();
    if (now.hour < resetHour) {
      final prevDay = now.subtract(const Duration(days: 1));
      return DateTime(prevDay.year, prevDay.month, prevDay.day);
    }
    return DateTime(now.year, now.month, now.day);
  }

  static String getStudyDateString([DateTime? targetTime, int resetHour = defaultResetHour]) {
    final date = getStudyDate(targetTime, resetHour);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static bool isSameStudyDay(DateTime a, DateTime b, {int resetHour = defaultResetHour}) {
    final studyDateA = getStudyDate(a, resetHour);
    final studyDateB = getStudyDate(b, resetHour);
    return studyDateA.year == studyDateB.year &&
        studyDateA.month == studyDateB.month &&
        studyDateA.day == studyDateB.day;
  }

  static DateTime getNextResetTime([DateTime? targetTime, int resetHour = defaultResetHour]) {
    final now = targetTime ?? DateTime.now();
    if (now.hour < resetHour) {
      return DateTime(now.year, now.month, now.day, resetHour);
    }
    final nextDay = now.add(const Duration(days: 1));
    return DateTime(nextDay.year, nextDay.month, nextDay.day, resetHour);
  }
}
