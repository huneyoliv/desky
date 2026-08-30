import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/utils/study_date_helper.dart';

void main() {
  group('StudyDateHelper Tests', () {
    test('before 05:00 AM returns previous calendar day as study day', () {
      final nightTime = DateTime(2026, 8, 17, 3, 30);
      final studyDate = StudyDateHelper.getStudyDate(nightTime);

      expect(studyDate.year, equals(2026));
      expect(studyDate.month, equals(8));
      expect(studyDate.day, equals(16));
    });

    test('at 05:00 AM returns current calendar day as study day', () {
      final resetTime = DateTime(2026, 8, 17, 5, 0);
      final studyDate = StudyDateHelper.getStudyDate(resetTime);

      expect(studyDate.year, equals(2026));
      expect(studyDate.month, equals(8));
      expect(studyDate.day, equals(17));
    });

    test('after 05:00 AM returns current calendar day as study day', () {
      final dayTime = DateTime(2026, 8, 17, 14, 45);
      final studyDate = StudyDateHelper.getStudyDate(dayTime);

      expect(studyDate.year, equals(2026));
      expect(studyDate.month, equals(8));
      expect(studyDate.day, equals(17));
    });

    test('getStudyDateString returns yyyy-MM-dd formatted string', () {
      final nightTime = DateTime(2026, 1, 1, 2, 0);
      final studyStr = StudyDateHelper.getStudyDateString(nightTime);

      expect(studyStr, equals('2025-12-31'));

      final afternoonTime = DateTime(2026, 8, 17, 15, 0);
      expect(StudyDateHelper.getStudyDateString(afternoonTime), equals('2026-08-17'));
    });

    test('isSameStudyDay matches timestamps within same 05:00 boundary', () {
      final nightSession = DateTime(2026, 8, 17, 2, 30);
      final previousEvening = DateTime(2026, 8, 16, 21, 0);
      final morningAfterReset = DateTime(2026, 8, 17, 6, 0);

      expect(StudyDateHelper.isSameStudyDay(nightSession, previousEvening), isTrue);
      expect(StudyDateHelper.isSameStudyDay(nightSession, morningAfterReset), isFalse);
    });

    test('getNextResetTime calculates upcoming 05:00 AM accurately', () {
      final nightTime = DateTime(2026, 8, 17, 2, 30);
      final nextResetNight = StudyDateHelper.getNextResetTime(nightTime);
      expect(nextResetNight, equals(DateTime(2026, 8, 17, 5, 0)));

      final dayTime = DateTime(2026, 8, 17, 14, 0);
      final nextResetDay = StudyDateHelper.getNextResetTime(dayTime);
      expect(nextResetDay, equals(DateTime(2026, 8, 18, 5, 0)));
    });

    test('custom resetHour calculates study date and next reset time accordingly', () {
      // Custom reset at 07:00 AM
      final time6am = DateTime(2026, 8, 17, 6, 30);
      expect(StudyDateHelper.getStudyDateString(time6am, 7), equals('2026-08-16'));

      final time8am = DateTime(2026, 8, 17, 8, 0);
      expect(StudyDateHelper.getStudyDateString(time8am, 7), equals('2026-08-17'));

      // Next reset time for 07:00 AM
      expect(StudyDateHelper.getNextResetTime(time6am, 7), equals(DateTime(2026, 8, 17, 7, 0)));
      expect(StudyDateHelper.getNextResetTime(time8am, 7), equals(DateTime(2026, 8, 18, 7, 0)));

      // Midnight reset (00:00)
      final time11pm = DateTime(2026, 8, 17, 23, 30);
      expect(StudyDateHelper.getStudyDateString(time11pm, 0), equals('2026-08-17'));
    });
  });
}
