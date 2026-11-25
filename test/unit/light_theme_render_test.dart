import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/theme/app_theme.dart';
import 'package:desky/core/theme/theme_palette.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/rank_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/groups/groups_screen.dart';
import 'package:desky/features/planner/planner_screen.dart';
import 'package:desky/features/ranks/ranks_screen.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/widgets/theme_selection_dialog.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/data/models/rank_entry_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/models/chat_message_model.dart';
import 'package:desky/data/repositories/group_admin_repository.dart';
import 'package:desky/features/groups/group_detail_screen.dart';
import 'package:desky/features/groups/group_leader_panel.dart';
import 'package:desky/features/profile/profile_screen.dart';
import 'light_theme_contrast_helper.dart';

class _FakeTimerRepository extends TimerRepository {
  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
    int? taskId,
  }) async =>
      true;

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async =>
      null;

  @override
  Future<bool> recordRest({
    required DateTime startAt,
    required DateTime stopAt,
    required int restMs,
    String deviceModel = 'Desktop',
  }) async =>
      true;
}

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: _FakeTimerRepository(),
          subjectRepository: SubjectRepository(),
        );

  @override
  Future<void> loadSubjects() async {}
  @override
  Future<void> reconcileWithServer() async {}

  bool _disposed = false;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class _FakePlannerRepository extends PlannerRepository {
  @override
  Future<List<DDayModel>> fetchDDays() async => [];
  @override
  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = 5,
  }) async =>
      [];
}

class _FakeGroupRepository extends GroupRepository {
  _FakeGroupRepository({
    this.members = const [],
    this.messages = const [],
  });

  final List<GroupMemberModel> members;
  final List<ChatMessageModel> messages;

  @override
  Future<List<GroupMemberModel>> fetchMembers(
    int groupId, {
    int countryId = 23,
    int version = 810041,
  }) async =>
      members;

  @override
  Future<List<GroupMemberModel>> fetchGroupRanks(
    int groupId, {
    String period = 'week',
    int countryId = 23,
    int categoryId = 0,
    DateTime? referenceDate,
  }) async =>
      members;

  @override
  Future<List<ChatMessageModel>> fetchChatMessages(int groupId) async =>
      messages;

  @override
  Future<List<GroupModel>> fetchExploreGroups({
    int categoryId = 0,
    String orderType = 'promotedAt',
    int page = 1,
    int countryId = 23,
    String? query,
  }) async =>
      [];
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
      [];

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
      {'ls': [], 'ss': []};
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(UserModel user) : super(AuthRepository()) {
    state = AuthState(user: user);
  }

  @override
  Future<void> checkAuthStatus() async {}
  @override
  Future<void> refreshUserGroups() async {}
}

class _FakeAdminRepository extends GroupAdminRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBannedList(int groupId) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchJoinRequests(int groupId) async => [];
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  DeskyThemePalette palette, {
  List<Override> extraOverrides = const [],
  String? caseId,
}) async {
  SharedPreferences.setMockInitialValues({
    SettingsRepository.keyThemePreset: palette.id,
    SettingsRepository.keyLightThemePreset: palette.id,
  });
  final prefs = await SharedPreferences.getInstance();
  final user = UserModel(id: 1, name: 'Test', email: '', jwtToken: '');
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(caseId ?? '${palette.id}/${child.runtimeType}'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timerNotifierProvider.overrideWith((ref) => _OfflineTimerNotifier()),
        plannerRepositoryProvider.overrideWithValue(_FakePlannerRepository()),
        groupRepoProvider.overrideWithValue(_FakeGroupRepository()),
        rankRepositoryProvider.overrideWithValue(_FakeRankRepository()),
        authStateProvider.overrideWith((ref) => _FakeAuthNotifier(user)),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(palette),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('main screens render with both light palettes without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final palette in [
      DeskyThemePalette.daylightLilac,
      DeskyThemePalette.porcelainSky,
    ]) {
      final screens = <String, Widget>{
        'timer': const TimerScreen(),
        'planner': const PlannerScreen(),
        'groups': const GroupsScreen(),
        'ranks/timeline': const RanksScreen(),
        'settings': const ThemeSelectionDialog(),
      };
      for (final entry in screens.entries) {
        await _pump(tester, entry.value, palette);
        expect(
          tester.takeException(),
          isNull,
          reason: '${palette.id}/${entry.key} threw or overflowed at 640x800',
        );
      }
    }
  });

  testWidgets('legacy screens keep rendered text at WCAG AA on light palettes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const group = GroupModel(
      id: 101,
      name: 'Grupo de Estudos 101',
      category: 'Exatas',
      dailyGoalHours: 8,
      membersCount: 2,
      maxCapacity: 20,
      isPrivate: false,
      leaderName: 'Líder',
      leaderUserId: 1,
    );
    final messages = [
      ChatMessageModel(
        id: 1,
        senderId: 1,
        senderName: 'Líder',
        studiconId: 5,
        message: 'Mensagem própria',
        sentAt: DateTime(2026, 11, 23, 12),
      ),
      ChatMessageModel(
        id: 2,
        senderId: 2,
        senderName: 'Membro',
        studiconId: 10,
        message: 'Mensagem recebida',
        sentAt: DateTime(2026, 11, 23, 12, 1),
      ),
    ];

    for (final palette in [
      DeskyThemePalette.daylightLilac,
      DeskyThemePalette.porcelainSky,
    ]) {
      await _pump(tester, const ProfileScreen(), palette);
      expectRenderedTextContrast(tester, palette, 'profile');

      await _pump(
        tester,
        const GroupDetailScreen(group: group),
        palette,
        extraOverrides: [
          groupRepositoryProvider.overrideWithValue(
            _FakeGroupRepository(members: const [], messages: messages),
          ),
        ],
      );
      await tester.tap(find.byType(Tab).at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mensagem própria'), findsOneWidget);
      expect(find.text('Mensagem recebida'), findsOneWidget);
      expectRenderedTextContrast(tester, palette, 'group chat');

      await _pump(
        tester,
        const GroupLeaderPanel(group: group, members: []),
        palette,
        extraOverrides: [
          groupAdminRepoProvider.overrideWithValue(_FakeAdminRepository()),
        ],
      );
      expectRenderedTextContrast(tester, palette, 'group leader panel');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
