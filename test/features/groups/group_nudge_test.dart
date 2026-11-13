import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/chat_message_model.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/groups/group_detail_screen.dart';

class _NudgeRepository extends GroupRepository {
  _NudgeRepository({required this.accepted});

  final bool accepted;
  int shakeCalls = 0;

  static final _members = [
    GroupMemberModel.fromJson({'ud': 10, 'n': 'Colega', 'sm': 0, 'sd': 5}),
  ];

  @override
  Future<List<GroupMemberModel>> fetchMembers(
    int groupId, {
    int countryId = 23,
    int version = 810041,
  }) async => _members;

  @override
  Future<List<GroupMemberModel>> fetchGroupRanks(
    int groupId, {
    String period = 'week',
    int countryId = 23,
    int categoryId = 0,
    DateTime? referenceDate,
  }) async => _members;

  @override
  Future<List<ChatMessageModel>> fetchChatMessages(int groupId) async => [];

  @override
  Future<bool> shakeMember({required int groupId, required int targetUserId}) async {
    shakeCalls++;
    return accepted;
  }
}

const _group = GroupModel(
  id: 101,
  name: 'Grupo de Estudos 101',
  category: 'Exatas',
  dailyGoalHours: 8,
  membersCount: 1,
  maxCapacity: 20,
  isPrivate: false,
  leaderName: 'Líder',
);

const _user = UserModel(
  id: 1,
  name: 'Estudante Focado',
  email: 'foco@desky.com',
  studiconId: 5,
  jwtToken: 'dummy_token',
);

Future<void> _pumpAndNudge(WidgetTester tester, _NudgeRepository repository) async {
  // Tall viewport: the member card lives below the "studying now" section and a
  // lazy list would not build it otherwise.
  tester.view.physicalSize = const Size(1280, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(repository),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
        authStateProvider.overrideWith(
          (ref) => AuthNotifier(AuthRepository())..state = const AuthState(user: _user),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const GroupDetailScreen(group: _group),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // The pt catalog renders the key 'shake' as "Chacoalhar".
  final shakeButton = find.textContaining('Chacoalh');
  await tester.ensureVisible(shakeButton.first);
  await tester.pump();
  await tester.tap(shakeButton.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a refused nudge is reported as a failure', (tester) async {
    final repository = _NudgeRepository(accepted: false);
    await _pumpAndNudge(tester, repository);

    expect(repository.shakeCalls, equals(1));
    expect(find.textContaining('Não foi possível enviar a cutucada'), findsOneWidget);
    expect(find.textContaining('Chacoalhada enviada'), findsNothing);
  });

  testWidgets('an accepted nudge is reported as sent', (tester) async {
    final repository = _NudgeRepository(accepted: true);
    await _pumpAndNudge(tester, repository);

    expect(repository.shakeCalls, equals(1));
    expect(find.textContaining('Chacoalhada enviada'), findsOneWidget);
    expect(find.textContaining('Não foi possível enviar a cutucada'), findsNothing);
  });
}
