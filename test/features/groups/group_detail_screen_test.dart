import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/models/chat_message_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/groups/group_detail_screen.dart';

class FakeGroupDetailRepository extends GroupRepository {
  final List<GroupMemberModel> mockMembers;
  final List<ChatMessageModel> mockMessages;

  FakeGroupDetailRepository({
    this.mockMembers = const [],
    this.mockMessages = const [],
  });

  @override
  Future<List<GroupMemberModel>> fetchMembers(
    int groupId, {
    int countryId = 23,
    int version = 810041,
  }) async => mockMembers;

  @override
  Future<List<GroupMemberModel>> fetchGroupRanks(
    int groupId, {
    String period = 'week',
    int countryId = 23,
    int categoryId = 0,
  }) async => mockMembers;

  @override
  Future<List<ChatMessageModel>> fetchChatMessages(int groupId) async => mockMessages;
}

void main() {
  testWidgets('GroupDetailScreen renders member list and chat tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    final members = [
      const GroupMemberModel(
        userId: 1,
        name: 'Líder do Grupo',
        studiconId: 5,
        isStudying: true,
        studyMs: 14400000,
        hasCustomAvatar: false,
      ),
      const GroupMemberModel(
        userId: 2,
        name: 'Membro Regular',
        studiconId: 10,
        isStudying: false,
        studyMs: 7200000,
        hasCustomAvatar: false,
      ),
    ];

    final messages = [
      ChatMessageModel(
        id: 1,
        senderId: 1,
        senderName: 'Líder do Grupo',
        studiconId: 5,
        message: 'Bem-vindos a todos!',
        sentAt: DateTime.now(),
      ),
    ];

    final fakeRepo = FakeGroupDetailRepository(
      mockMembers: members,
      mockMessages: messages,
    );

    final mockUser = const UserModel(
      id: 1,
      name: 'Líder do Grupo',
      email: 'lider@example.com',
      studiconId: 5,
      jwtToken: 'dummy_token',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(fakeRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
          authStateProvider.overrideWith(
            (ref) => AuthNotifier(AuthRepository())..state = AuthState(user: mockUser),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: GroupDetailScreen(group: group),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Grupo de Estudos 101'), findsOneWidget);
    expect(find.text('Líder do Grupo'), findsWidgets);
    expect(find.textContaining('1 estudando agora'), findsOneWidget);
    expect(find.text('Estudando Agora (1)'), findsOneWidget);
  });

  testWidgets('GroupMemberModel parses ranking time in seconds and milliseconds correctly', (tester) async {
    final memberWithSeconds = GroupMemberModel.fromJson({
      'ud': 10,
      'n': 'Estudante Segundos',
      'st': 7200, // 2 hours in seconds
      'sd': 5,
    });
    expect(memberWithSeconds.studyMs, 7200000);

    final memberWithMs = GroupMemberModel.fromJson({
      'ud': 11,
      'n': 'Estudante Ms',
      'sm': 18000000, // 5 hours in ms
      'sd': 6,
    });
    expect(memberWithMs.studyMs, 18000000);
  });
}
