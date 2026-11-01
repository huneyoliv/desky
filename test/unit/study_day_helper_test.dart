import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/utils/study_day_helper.dart';

void main() {
  const brazil = Duration(hours: -3);
  const korea = Duration(hours: 9);
  const india = Duration(hours: 5, minutes: 30);

  group('StudyDayHelper window', () {
    test('Brazil closes the study day at 5 AM local time', () {
      final start = StudyDayHelper.startUtc('2026-11-01', gmtOffset: brazil);
      final end = StudyDayHelper.endUtc('2026-11-01', gmtOffset: brazil);

      expect(start, DateTime.utc(2026, 11, 1, 8));
      expect(end, DateTime.utc(2026, 11, 2, 8));
      expect(StudyDayHelper.startAtIso('2026-11-01', gmtOffset: brazil),
          '2026-11-01T08:00:00.000Z');
    });

    test('Korea starts the study day on the previous UTC day', () {
      expect(
        StudyDayHelper.startUtc('2026-11-01', gmtOffset: korea),
        DateTime.utc(2026, 10, 31, 20),
      );
    });

    test('Half-hour offsets are preserved', () {
      expect(
        StudyDayHelper.startUtc('2026-11-01', gmtOffset: india),
        DateTime.utc(2026, 10, 31, 23, 30),
      );
    });

    test('UTC keeps the reset hour unchanged', () {
      expect(
        StudyDayHelper.startUtc('2026-11-01', gmtOffset: Duration.zero),
        DateTime.utc(2026, 11, 1, 5),
      );
    });

    test('Custom reset hour shifts the window', () {
      expect(
        StudyDayHelper.startUtc('2026-11-01', gmtOffset: brazil, resetHour: 0),
        DateTime.utc(2026, 11, 1, 3),
      );
    });
  });

  group('StudyDayHelper studyDateYmd', () {
    test('instants before the reset hour belong to the previous day', () {
      expect(
        StudyDayHelper.studyDateYmd(
          DateTime.parse('2026-11-01T07:59:59.999Z'),
          gmtOffset: brazil,
        ),
        '2026-10-31',
      );
    });

    test('the reset instant starts the new study day', () {
      expect(
        StudyDayHelper.studyDateYmd(
          DateTime.parse('2026-11-01T08:00:00.000Z'),
          gmtOffset: brazil,
        ),
        '2026-11-01',
      );
      expect(
        StudyDayHelper.studyDateYmd(
          DateTime.parse('2026-11-02T07:59:59.999Z'),
          gmtOffset: brazil,
        ),
        '2026-11-01',
      );
    });

    test('reset hour zero follows the local calendar day', () {
      expect(
        StudyDayHelper.studyDateYmd(
          DateTime.parse('2026-11-01T02:59:00.000Z'),
          gmtOffset: brazil,
          resetHour: 0,
        ),
        '2026-10-31',
      );
      expect(
        StudyDayHelper.studyDateYmd(
          DateTime.parse('2026-11-01T03:00:00.000Z'),
          gmtOffset: brazil,
          resetHour: 0,
        ),
        '2026-11-01',
      );
    });
  });

  group('StudyDayHelper parseInstant', () {
    test('keeps explicit UTC timestamps', () {
      expect(
        StudyDayHelper.parseInstant('2026-08-10T00:15:00Z', gmtOffset: brazil),
        DateTime.utc(2026, 8, 10, 0, 15),
      );
    });

    test('honours explicit offsets', () {
      expect(
        StudyDayHelper.parseInstant('2026-08-09 21:02:06.000440-03:00', gmtOffset: brazil),
        DateTime.utc(2026, 8, 10, 0, 2, 6, 0, 440),
      );
    });

    test('treats zoneless timestamps as country wall-clock time', () {
      expect(
        StudyDayHelper.parseInstant('2026-09-09T21:15:00.000', gmtOffset: brazil),
        DateTime.utc(2026, 9, 10, 0, 15),
      );
    });

    test('returns null for empty or malformed values', () {
      expect(StudyDayHelper.parseInstant(null, gmtOffset: brazil), isNull);
      expect(StudyDayHelper.parseInstant('   ', gmtOffset: brazil), isNull);
      expect(StudyDayHelper.parseInstant('not-a-date', gmtOffset: brazil), isNull);
    });

    test('detects explicit zones', () {
      expect(StudyDayHelper.hasExplicitZone('2026-08-10T00:15:00Z'), isTrue);
      expect(StudyDayHelper.hasExplicitZone('2026-08-10T00:15:00-03:00'), isTrue);
      expect(StudyDayHelper.hasExplicitZone('2026-08-10T00:15:00'), isFalse);
    });
  });

  test('formatYmd zero pads month and day', () {
    expect(StudyDayHelper.formatYmd(DateTime(2026, 1, 2)), '2026-01-02');
  });
}
