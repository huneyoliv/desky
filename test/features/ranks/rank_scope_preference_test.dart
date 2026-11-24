import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/models/rank_entry_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/rank_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/ranks/ranks_screen.dart';
import 'package:desky/features/ranks/session_derivations.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/settings_state.dart';

const _country = CountryModel(
  id: 23,
  name: 'BRAZIL',
  code: 'BR',
  timezone: 'America/Sao_Paulo',
  continent: 'South America',
);

const _user = UserModel(
  id: 1,
  name: 'Estudante Focado',
  email: 'foco@desky.com',
  studiconId: -1,
  jwtToken: 'dummy_token',
);

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier() : super(SettingsRepository()) {
    state = const SettingsState(
      selectedLanguage: 'pt',
      selectedCountry: _country,
    );
  }

  @override
  Future<void> init() async {}
}

class _FakeRankRepository extends RankRepository {
  @override
  Future<List<RankEntryModel>> fetchGlobalRanks({
    String period = 'day',
    int categoryId = 0,
    int countryId = 23,
    int page = 1,
    DateTime? referenceDate,
  }) async =>
      const [];

  @override
  Future<int?> fetchMyCategoryRank({
    int categoryId = 0,
    int countryId = 23,
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>> fetchUserStats({
    required int userId,
    required String startDate,
    required String endDate,
  }) async =>
      {'s': true, 'ls': []};

  @override
  Future<Map<String, int>> fetchDailyStudyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async =>
      const {};

  @override
  Future<Map<String, Map<String, int>>> fetchSubjectDailyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async =>
      const {};

  @override
  Future<List<StudySession>> fetchStudySessions({
    required int userId,
    required String startDate,
    required String endDate,
  }) async =>
      const [];

  @override
  Future<Map<String, List<int>>> fetchHourlyStudyMinutes({
    required int userId,
    required String startDate,
    required String endDate,
  }) async =>
      const {};
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs,
  String caseId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(caseId),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        rankRepositoryProvider.overrideWithValue(_FakeRankRepository()),
        settingsNotifierProvider.overrideWith(
          (ref) => _FakeSettingsNotifier(),
        ),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
        authStateProvider.overrideWith(
          (ref) => AuthNotifier(AuthRepository())
            ..state = const AuthState(user: _user),
        ),
      ],
      child: const MaterialApp(home: RanksScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
      'rank scope persists and is restored when the screen is recreated',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _pump(tester, prefs, 'initial');

    await tester.tap(find.text('Região'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(prefs.getString('rank_scope'), 'region');

    await _pump(tester, prefs, 'recreated');
    final label = tester.widget<Text>(find.text('Região'));
    expect(label.style?.fontWeight, FontWeight.w700);
  });
}
