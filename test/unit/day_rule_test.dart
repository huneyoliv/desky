import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/utils/study_day_helper.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(super.repository);

  @override
  Future<void> init() async {}

  @override
  Future<void> loadCategories({int? countryId, String? language}) async {}
}

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: TimerRepository(),
          subjectRepository: SubjectRepository(),
        );

  @override
  Future<void> loadSubjects() async {}

  @override
  Future<void> reconcileWithServer() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('country startHour applies without erasing the manual preference',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = _TestSettingsNotifier(SettingsRepository(prefs: prefs));
    addTearDown(settings.dispose);
    await settings.setDayResetHour(7);

    const sriLanka = CountryModel(
      id: 144,
      name: 'SRI LANKA',
      code: 'LK',
      timezone: 'Asia/Colombo',
      continent: 'Asia',
      gmtOffset: 5.5,
      startTime: '12 AM',
    );
    await settings.selectCountry(sriLanka);

    expect(settings.state.dayResetHour, 0);
    expect(prefs.getInt(SettingsRepository.keyDayResetHour), 7);

    const noStartTime = CountryModel(
      id: 145,
      name: 'NO START',
      code: 'NS',
      timezone: 'UTC',
      continent: 'Test',
      gmtOffset: 5.5,
    );
    await settings.selectCountry(noStartTime);
    expect(settings.state.dayResetHour, 7);
    expect(prefs.getInt(SettingsRepository.keyDayResetHour), 7);
  });

  test('timer accepts a country GMT offset distinct from the device', () async {
    SharedPreferences.setMockInitialValues({});
    final dynamic notifier = _OfflineTimerNotifier();
    addTearDown(notifier.dispose);
    await notifier.ready;
    const offset = Duration(hours: 5, minutes: 30);

    notifier.setLocale(gmtOffset: offset);
    notifier.setDayResetHour(0);

    final expected = StudyDayHelper.studyDateYmd(
      DateTime.now(),
      gmtOffset: offset,
      resetHour: 0,
    );
    expect(notifier.state.lastStudyDate, expected);
  });

  test('country persistence preserves null GMT and startTime', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SettingsRepository(prefs: prefs);
    const country = CountryModel(
      id: 144,
      name: 'SRI LANKA',
      code: 'LK',
      timezone: 'Asia/Colombo',
      continent: 'Asia',
    );

    await repository.saveCountry(SettingsRepository.defaultCountry);
    await repository.saveCountry(country);
    final restored = await repository.getSavedCountry();

    expect(restored.gmtOffset, isNull);
    expect(restored.startTime, isNull);
  });

  test('GMT+5:30 changes the study day at the exact midnight boundary', () {
    const offset = Duration(hours: 5, minutes: 30);
    expect(
      StudyDayHelper.studyDateYmd(
        DateTime.utc(2026, 11, 23, 18, 29),
        gmtOffset: offset,
        resetHour: 0,
      ),
      '2026-11-23',
    );
    expect(
      StudyDayHelper.studyDateYmd(
        DateTime.utc(2026, 11, 23, 18, 30),
        gmtOffset: offset,
        resetHour: 0,
      ),
      '2026-11-24',
    );
  });
}
