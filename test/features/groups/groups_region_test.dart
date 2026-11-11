import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/groups/groups_screen.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/settings_state.dart';

class _FakeGroupRepository extends GroupRepository {
  /// No groups: these tests cover the empty-region path.
  final List<GroupModel> groups = const [];
  final List<int> requestedCountryIds = [];

  @override
  Future<List<GroupModel>> fetchExploreGroups({
    int categoryId = 0,
    String orderType = 'promotedAt',
    int page = 1,
    int countryId = 23,
    String? query,
  }) async {
    requestedCountryIds.add(countryId);
    return groups;
  }
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
  name: 'Test User',
  email: 'test@example.com',
  studiconId: 1,
  jwtToken: 'dummy_token',
);

Future<void> _pumpGroups(WidgetTester tester, _FakeGroupRepository repository) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepoProvider.overrideWithValue(repository),
        settingsNotifierProvider.overrideWith((ref) => _FakeSettingsNotifier(_country)),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
        authStateProvider.overrideWith(
          (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: _user),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const GroupsScreen(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('Explorar Grupos'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('explore requests groups from the country the user picked', (tester) async {
    final repository = _FakeGroupRepository();
    await _pumpGroups(tester, repository);

    expect(repository.requestedCountryIds, isNotEmpty);
    expect(repository.requestedCountryIds.last, equals(_country.id));
  });

  testWidgets('an empty region offers an explicit way to view another one', (tester) async {
    final repository = _FakeGroupRepository();
    await _pumpGroups(tester, repository);

    // No silent fallback: the user is told which region was searched and gets
    // an explicit action instead of the app quietly widening the search.
    expect(find.textContaining(_country.formattedName), findsWidgets);
    expect(find.text('Ver grupos de outra região'), findsOneWidget);
  });
}
