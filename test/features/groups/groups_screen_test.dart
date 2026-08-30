import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/groups/groups_screen.dart';

class FakeGroupRepository extends GroupRepository {
  final List<GroupModel> mockExploreGroups;

  FakeGroupRepository({this.mockExploreGroups = const []});

  @override
  Future<List<GroupModel>> fetchExploreGroups({
    int categoryId = 0,
    String orderType = 'promotedAt',
    int page = 1,
    int countryId = 23,
    String? query,
  }) async => mockExploreGroups;
}

void main() {
  testWidgets('GroupsScreen renders user groups and explore list', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final exploreGroups = [
      const GroupModel(
        id: 101,
        name: 'Concurseiros Focados',
        category: 'Concursos',
        dailyGoalHours: 6,
        membersCount: 15,
        maxCapacity: 30,
        isPrivate: false,
        leaderName: 'Líder Bruno',
      ),
    ];

    final fakeRepo = FakeGroupRepository(mockExploreGroups: exploreGroups);

    final mockUser = const UserModel(
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      studiconId: 1,
      jwtToken: 'dummy_token',
      userGroups: [
        GroupModel(
          id: 999,
          name: 'Meu Grupo Atual',
          category: 'Geral',
          dailyGoalHours: 5,
          membersCount: 10,
          maxCapacity: 20,
          isPrivate: false,
          leaderName: 'Eu',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepoProvider.overrideWithValue(fakeRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          authStateProvider.overrideWith(
            (ref) => AuthNotifier(AuthRepository())..state = AuthState(user: mockUser),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const GroupsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Meu Grupo Atual'), findsOneWidget);

    // Tap on Explore tab
    await tester.tap(find.text('Explorar Grupos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Concurseiros Focados'), findsOneWidget);
  });
}
