import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/models/rank_entry_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/rank_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/ranks/ranks_screen.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/settings_state.dart';

class _FakeRankRepository extends RankRepository {
  _FakeRankRepository({this.stats = const {'s': true, 'ls': []}});

  final Map<String, dynamic> stats;
  int? lastCountryId;

  @override
  Future<List<RankEntryModel>> fetchGlobalRanks({
    String period = 'day',
    int categoryId = 0,
    int countryId = 23,
    int page = 1,
    DateTime? referenceDate,
  }) async {
    lastCountryId = countryId;
    return const [];
  }

  @override
  Future<int?> fetchMyCategoryRank({int categoryId = 0, int countryId = 23}) async => null;

  @override
  Future<Map<String, dynamic>> fetchUserStats({
    required int userId,
    required String startDate,
    required String endDate,
  }) async => stats;
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(CountryModel country) : super(SettingsRepository()) {
    state = SettingsState(selectedLanguage: 'pt', selectedCountry: country);
  }

  @override
  Future<void> init() async {}
}

const _country = CountryModel(
  id: 82,
  name: 'SOUTH KOREA',
  code: 'KR',
  timezone: 'Asia/Seoul',
  continent: 'Asia',
);

const _user = UserModel(
  id: 1,
  name: 'Estudante Focado',
  email: 'foco@desky.com',
  statusMessage: 'Rumo à aprovação!',
  categoryName: 'Medicina',
  studiconId: 1,
  jwtToken: 'dummy_token',
  flamesBalance: 150,
);

Future<void> _pumpScreen(WidgetTester tester, _FakeRankRepository repository) async {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
        rankRepositoryProvider.overrideWithValue(repository),
        settingsNotifierProvider.overrideWith((ref) => _FakeSettingsNotifier(_country)),
        authStateProvider.overrideWith(
          (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: _user),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: RanksScreen())),
    ),
  );
  // Bounded pumps: this screen keeps animating, so pumpAndSettle can time out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('ranking requests the country the user picked', (tester) async {
    final repository = _FakeRankRepository();
    await _pumpScreen(tester, repository);

    expect(repository.lastCountryId, equals(_country.id));
  });

  testWidgets('the subject pie splits the month by session subject', (tester) async {
    final repository = _FakeRankRepository(stats: {
      's': true,
      'ls': [
        {
          'dt': '2026-08-10',
          'sm': 7200000,
          'ls': [
            {'sb': 'Matemática', 'sm': 3600000},
            {'sb': 'História', 'sm': 3600000},
          ],
        },
        {
          'dt': '2026-08-11',
          'sm': 3600000,
          'ls': [
            {'sb': 'Matemática', 'sm': 3600000},
          ],
        },
      ],
    });
    await _pumpScreen(tester, repository);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(
      chart.data.sections.length,
      equals(2),
      reason: 'duas materias nos logs devem virar duas fatias, nao uma "Geral"',
    );
  });
}
