/// Study-day semantics shared with the YPT backend.
///
/// YPT starts a new study day at a country-specific hour (5 AM for every
/// country in the published registry) measured against the country's fixed
/// GMT offset. The planner therefore queries `[start, start + 24h)` in UTC,
/// e.g. 2026-11-01 for Brazil (GMT-3, 5 AM) is
/// `[2026-11-01T08:00Z, 2026-11-02T08:00Z)`.
///
/// Daylight-saving transitions are intentionally not applied: the offsets come
/// from the same country registry the backend uses, so both sides agree.
class StudyDayHelper {
  StudyDayHelper._();

  static const int defaultResetHour = 5;
  static const Duration dayLength = Duration(hours: 24);

  static final RegExp _explicitZone = RegExp(
    r'(\d{2}:\d{2}(:\d{2}(\.\d+)?)?)(Z|z|[+-]\d{2}:?\d{2})$',
  );

  static bool hasExplicitZone(String raw) => _explicitZone.hasMatch(raw.trim());

  /// UTC instant where the study day of [dateYmd] starts.
  static DateTime startUtc(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = defaultResetHour,
  }) {
    final date = DateTime.parse(dateYmd);
    return DateTime.utc(date.year, date.month, date.day, _clampHour(resetHour))
        .subtract(gmtOffset);
  }

  /// Exclusive end of the study day of [dateYmd].
  static DateTime endUtc(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = defaultResetHour,
  }) {
    return startUtc(dateYmd, gmtOffset: gmtOffset, resetHour: resetHour)
        .add(dayLength);
  }

  static String startAtIso(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = defaultResetHour,
  }) {
    return toApiIso(startUtc(dateYmd, gmtOffset: gmtOffset, resetHour: resetHour));
  }

  /// Study-day `yyyy-MM-dd` that contains [instant].
  static String studyDateYmd(
    DateTime instant, {
    required Duration gmtOffset,
    int resetHour = defaultResetHour,
  }) {
    final local = instant.toUtc().add(gmtOffset);
    final effective = local.hour < _clampHour(resetHour)
        ? local.subtract(const Duration(days: 1))
        : local;
    return formatYmd(effective);
  }

  static String todayYmd({
    required Duration gmtOffset,
    int resetHour = defaultResetHour,
  }) {
    return studyDateYmd(DateTime.now(), gmtOffset: gmtOffset, resetHour: resetHour);
  }

  static String formatYmd(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static String toApiIso(DateTime instant) => instant.toUtc().toIso8601String();

  /// Parses timestamps returned by YPT.
  ///
  /// Values without an explicit zone (e.g. recurrence end dates) are treated as
  /// wall-clock time in the country timezone and converted to UTC.
  static DateTime? parseInstant(
    String? raw, {
    required Duration gmtOffset,
  }) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (hasExplicitZone(value)) return parsed.toUtc();

    final wallTime = DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
    return wallTime.subtract(gmtOffset);
  }

  static int _clampHour(int hour) => (hour >= 0 && hour <= 23) ? hour : defaultResetHour;
}
