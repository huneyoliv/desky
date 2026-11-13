import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
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

class _StubApiClient extends ApiClient {
  _StubApiClient(this.response) : super(customDio: Dio());

  final Map<String, dynamic> response;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: response,
      statusCode: 200,
    );
  }
}

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
  studiconId: 1,
  jwtToken: 'dummy_token',
);

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier() : super(SettingsRepository()) {
    state = const SettingsState(selectedLanguage: 'pt', selectedCountry: _country);
  }

  @override
  Future<void> init() async {}
}

class _FakeRankRepository extends RankRepository {
  _FakeRankRepository({this.subjectDaily = const {}});

  final Map<String, Map<String, int>> subjectDaily;
  final List<String> requestedStartDates = [];

  @override
  Future<List<RankEntryModel>> fetchGlobalRanks({
    String period = 'day',
    int categoryId = 0,
    int countryId = 23,
    int page = 1,
    DateTime? referenceDate,
  }) async => const [];

  @override
  Future<int?> fetchMyCategoryRank({int categoryId = 0, int countryId = 23}) async => null;

  @override
  Future<Map<String, dynamic>> fetchUserStats({
    required int userId,
    required String startDate,
    required String endDate,
  }) async => {'s': true, 'ls': []};

  @override
  Future<Map<String, Map<String, int>>> fetchSubjectDailyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    requestedStartDates.add(startDate);
    return subjectDaily;
  }
}

Future<void> _pumpStatsTab(WidgetTester tester, _FakeRankRepository repository) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rankRepositoryProvider.overrideWithValue(repository),
        settingsNotifierProvider.overrideWith((ref) => _FakeSettingsNotifier()),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
        authStateProvider.overrideWith(
          (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: _user),
        ),
      ],
      child: const MaterialApp(home: RanksScreen()),
    ),
  );

  // Bounded pumps: this screen keeps animating.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.byType(Tab).at(1));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

DateTime _lastMonthFirstDay() {
  final now = DateTime.now();
  return DateTime(now.year, now.month - 1, 1);
}

void main() {
  test('fetchSubjectDailyMs splits a day by subject and flags unknown time', () async {
    final repository = RankRepository(
      apiClient: _StubApiClient({
        's': true,
        'ls': [
          {
            'dt': '2026-11-07',
            'sm': 5400000,
            'ls': [
              {'sb': 'Matemática', 'sm': 3600000},
              {'sb': 'História', 'sm': 1800000},
              {'sb': 'Matemática', 'sm': 600000},
            ],
          },
          {
            // No session detail: the day total must not be lost.
            'dt': '2026-11-08',
            'sm': 1200000,
            'ls': [],
          },
        ],
      }),
    );

    final byDay = await repository.fetchSubjectDailyMs(
      userId: 1,
      startDate: '2026-11-07',
      endDate: '2026-11-08',
    );

    expect(byDay['2026-11-07'], equals({'Matemática': 4200000, 'História': 1800000}));
    expect(byDay['2026-11-08'], equals({RankRepository.unknownSubjectKey: 1200000}));
  });

  testWidgets('the series offers period navigation and reloads on change', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final repository = _FakeRankRepository(subjectDaily: {
      '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}':
          {'Matemática': 3600000},
    });

    await _pumpStatsTab(tester, repository);

    // The chart rendered and the initial period was the current week.
    expect(find.byType(BarChart), findsOneWidget);
    expect(repository.requestedStartDates, isNotEmpty);
    expect(
      repository.requestedStartDates.first,
      equals('${monday.year}-${monday.month.toString().padLeft(2, '0')}'
          '-${monday.day.toString().padLeft(2, '0')}'),
    );

    // Every period option is offered, so past periods are reachable.
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('Semana passada'), findsOneWidget);
    expect(find.text('Este mês'), findsOneWidget);
    expect(find.text('Mês passado'), findsOneWidget);

    final before = repository.requestedStartDates.length;
    await tester.tap(find.text('Mês passado'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.requestedStartDates.length, equals(before + 1));
    final last = _lastMonthFirstDay();
    expect(
      repository.requestedStartDates.last,
      equals('${last.year}-${last.month.toString().padLeft(2, '0')}-01'),
      reason: 'navegar para o mês passado deve pedir o intervalo do mês passado',
    );
  });

  testWidgets('the series shows an empty state when nothing was studied', (tester) async {
    final repository = _FakeRankRepository(subjectDaily: const {});
    await _pumpStatsTab(tester, repository);

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Nenhum registro de estudo'), findsOneWidget);
  });
}
