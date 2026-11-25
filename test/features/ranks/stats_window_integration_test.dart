import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

String _key(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

Map<String, int> _filter(
  Map<String, int> history,
  String startDate,
  String endDate,
) =>
    Map.fromEntries(
      history.entries.where(
        (entry) =>
            entry.key.compareTo(startDate) >= 0 &&
            entry.key.compareTo(endDate) <= 0,
      ),
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
  _FakeRankRepository({
    this.daily = const {},
    this.subjectDaily = const {},
    this.stats = const {'s': true, 'ls': []},
  });

  final Map<String, int> daily;
  final Map<String, Map<String, int>> subjectDaily;
  final Map<String, dynamic> stats;
  final List<(String, String)> dailyRanges = [];
  final List<(String, String)> subjectRanges = [];
  String? holdStart;
  String? holdEnd;
  Completer<Map<String, int>>? completer;

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
      stats;

  @override
  Future<Map<String, int>> fetchDailyStudyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    dailyRanges.add((startDate, endDate));
    if (holdStart == startDate && holdEnd == endDate && completer != null) {
      return completer!.future;
    }
    return _filter(daily, startDate, endDate);
  }

  @override
  Future<Map<String, Map<String, int>>> fetchSubjectDailyMs({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    subjectRanges.add((startDate, endDate));
    final keys = _filter(
      {for (final key in subjectDaily.keys) key: 1},
      startDate,
      endDate,
    ).keys;
    return {for (final key in keys) key: subjectDaily[key]!};
  }

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

Future<void> _pumpStatsTab(
  WidgetTester tester,
  _FakeRankRepository repository,
) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rankRepositoryProvider.overrideWithValue(repository),
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
  await tester.tap(find.byType(Tab).at(1));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('derived cards load previous periods and reload with the chip',
      (tester) async {
    const minute = 60000;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final previousWeekDay = monday.subtract(const Duration(days: 2));
    final previousMonthDay = DateTime(now.year, now.month - 1, 15);
    final twoMonthsAgoDay = DateTime(now.year, now.month - 2, 15);
    final repo = _FakeRankRepository(subjectDaily: const {}, daily: {
      _key(today): 60 * minute,
      _key(previousWeekDay): 90 * minute,
      _key(previousMonthDay): 120 * minute,
      _key(twoMonthsAgoDay): 240 * minute,
    });

    await _pumpStatsTab(tester, repo);

    expect(find.text(_key(previousWeekDay)), findsOneWidget);
    expect(find.textContaining('2h'), findsWidgets);

    final derivedBefore = repo.dailyRanges.length;
    await tester.tap(find.text('Mês passado'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.dailyRanges.length, greaterThan(derivedBefore));
    expect(find.text(_key(twoMonthsAgoDay)), findsOneWidget);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    expect(repo.subjectRanges.last.$1, _key(lastMonth));
  });

  testWidgets('quarter loads all three months instead of inventing zeroes',
      (tester) async {
    final now = DateTime.now();
    final repo = _FakeRankRepository(daily: {
      _key(DateTime(now.year, now.month - 4, 5)): 60 * 60000,
      _key(DateTime(now.year, now.month - 3, 5)): 120 * 60000,
      _key(DateTime(now.year, now.month - 2, 5)): 180 * 60000,
    });
    await _pumpStatsTab(tester, repo);

    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final month = DateTime(now.year, now.month - 3, 1);
    final quarterMonth = ((month.month - 1) ~/ 3) * 3 + 1;
    final first = DateTime(month.year, quarterMonth, 1);
    final last = DateTime(month.year, quarterMonth + 3, 0);
    expect(repo.dailyRanges.last, (_key(first), _key(last)));
  });

  testWidgets(
      'calendar shows loading instead of zero while the future is pending',
      (tester) async {
    final now = DateTime.now();
    final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final repo = _FakeRankRepository()
      ..holdStart = _key(DateTime(now.year, quarterMonth, 1))
      ..holdEnd = _key(DateTime(now.year, quarterMonth + 3, 0))
      ..completer = Completer<Map<String, int>>();

    await _pumpStatsTab(tester, repo);
    expect(
      find.byKey(const ValueKey('stats-quarter-loading')),
      findsOneWidget,
    );

    await tester.tap(find.byType(Tab).at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('stats-month-loading')),
      findsOneWidget,
    );
    expect(find.text('Nenhum dia com estudo neste trimestre.'), findsNothing);

    repo.completer!.complete(const {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('stats-quarter-loading')), findsNothing);
    expect(find.byKey(const ValueKey('stats-month-loading')), findsNothing);
  });

  testWidgets('pie excludes zero-duration subjects', (tester) async {
    final repo = _FakeRankRepository(stats: {
      's': true,
      'ls': [
        {
          'dt': '2026-11-10',
          'sm': 7200000,
          'ls': [
            {'sb': 'Matemática', 'sm': 3600000},
            {'sb': 'História', 'sm': 3600000},
            {'sb': 'Vazia', 'sm': 0},
          ],
        },
      ],
    });
    await _pumpStatsTab(tester, repo);

    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections, hasLength(2));
    expect(chart.data.sections.every((section) => section.value > 0), isTrue);
  });

  testWidgets('pie with only zeroes shows the empty state', (tester) async {
    final repo = _FakeRankRepository(stats: {
      's': true,
      'ls': [
        {
          'dt': '2026-11-10',
          'sm': 0,
          'ls': [
            {'sb': 'Vazia', 'sm': 0},
          ],
        },
      ],
    });
    await _pumpStatsTab(tester, repo);

    expect(find.byType(PieChart), findsNothing);
  });
}
