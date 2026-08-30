import 'package:flutter_test/flutter_test.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/models/category_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';

class MockSettingsRepository extends SettingsRepository {
  CountryModel savedCountry = const CountryModel(
    id: 23,
    name: 'Brasil',
    code: 'BR',
    timezone: 'America/Sao_Paulo',
    continent: 'South America',
  );
  String savedLanguage = 'pt';
  int savedDayResetHour = 5;
  bool savedShowRestTime = true;
  bool savedWakeNotifications = true;
  bool savedSoundEffects = true;
  List<String> savedBlockedUsers = [];

  @override
  Future<CountryModel> getSavedCountry() async => savedCountry;

  @override
  Future<String> getSavedLanguage() async => savedLanguage;

  @override
  Future<int> getDayResetHour() async => savedDayResetHour;

  @override
  Future<bool> getShowRestTime() async => savedShowRestTime;

  @override
  Future<bool> getWakeNotifications() async => savedWakeNotifications;

  @override
  Future<bool> getSoundEffects() async => savedSoundEffects;

  @override
  Future<List<String>> getBlockedUsers() async => savedBlockedUsers;

  @override
  Future<void> saveCountry(CountryModel country) async => savedCountry = country;

  @override
  Future<void> saveLanguage(String languageCode) async => savedLanguage = languageCode;

  @override
  Future<void> saveDayResetHour(int hour) async => savedDayResetHour = hour;

  @override
  Future<void> saveShowRestTime(bool value) async => savedShowRestTime = value;

  @override
  Future<void> saveWakeNotifications(bool value) async => savedWakeNotifications = value;

  @override
  Future<void> saveSoundEffects(bool value) async => savedSoundEffects = value;

  @override
  Future<void> saveBlockedUsers(List<String> users) async => savedBlockedUsers = users;

  @override
  Future<List<CountryModel>> fetchCountries() async => [
    const CountryModel(
      id: 23,
      name: 'Brasil',
      code: 'BR',
      timezone: 'America/Sao_Paulo',
      continent: 'South America',
    ),
    const CountryModel(
      id: 231,
      name: 'United States',
      code: 'US',
      timezone: 'America/New_York',
      continent: 'North America',
    ),
  ];

  @override
  Future<List<CategoryModel>> fetchCategoriesByCountry({int countryId = 23, String language = 'pt'}) async => [
    const CategoryModel(id: 1, title: 'Vestibular', shortTitle: 'Vest', order: 1, section: 'geral'),
  ];
}

void main() {
  group('SettingsNotifier Tests', () {
    late MockSettingsRepository mockRepo;
    late SettingsNotifier notifier;

    setUp(() {
      mockRepo = MockSettingsRepository();
      notifier = SettingsNotifier(mockRepo);
    });

    test('selectCountry saves country and updates state', () async {
      const newCountry = CountryModel(
        id: 231,
        name: 'United States',
        code: 'US',
        timezone: 'America/New_York',
        continent: 'North America',
      );
      await notifier.selectCountry(newCountry);

      expect(notifier.state.selectedCountry.id, equals(231));
      expect(mockRepo.savedCountry.id, equals(231));
    });

    test('selectLanguage saves language and updates state', () async {
      await notifier.selectLanguage('en');

      expect(notifier.state.selectedLanguage, equals('en'));
      expect(mockRepo.savedLanguage, equals('en'));
    });

    test('setDayResetHour, toggle preferences and block users', () async {
      await notifier.setDayResetHour(4);
      expect(notifier.state.dayResetHour, 4);

      await notifier.toggleShowRestTime(false);
      expect(notifier.state.showRestTime, isFalse);

      await notifier.blockUser('bad_actor');
      expect(notifier.state.blockedUsers, contains('bad_actor'));

      await notifier.unblockUser('bad_actor');
      expect(notifier.state.blockedUsers, isNot(contains('bad_actor')));
    });
  });
}
