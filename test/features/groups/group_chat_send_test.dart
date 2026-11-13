import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/chat_message_model.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:desky/features/groups/group_detail_screen.dart';

class _CapturingApiClient extends ApiClient {
  _CapturingApiClient() : super(customDio: Dio());

  Map<String, dynamic> response = {'s': true};
  String? lastPath;
  dynamic lastData;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    lastPath = path;
    lastData = data;
    return Response(
      requestOptions: RequestOptions(path: path),
      data: response,
      statusCode: 200,
    );
  }
}

class _OfflineChatRepository extends GroupRepository {
  @override
  Future<List<GroupMemberModel>> fetchMembers(
    int groupId, {
    int countryId = 23,
    int version = 810041,
  }) async => [];

  @override
  Future<List<GroupMemberModel>> fetchGroupRanks(
    int groupId, {
    String period = 'week',
    int countryId = 23,
    int categoryId = 0,
    DateTime? referenceDate,
  }) async => [];

  @override
  Future<List<ChatMessageModel>> fetchChatMessages(int groupId) async => [];

  @override
  Future<ChatMessageModel> sendMessage({
    required int groupId,
    String message = '',
    String? stickerUrl,
    String? imageUrl,
    String? thumbUrl,
  }) async {
    throw Exception('offline');
  }
}

const _group = GroupModel(
  id: 101,
  name: 'Grupo de Estudos 101',
  category: 'Exatas',
  dailyGoalHours: 8,
  membersCount: 2,
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

Future<void> _pumpChat(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(_OfflineChatRepository()),
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

  await tester.tap(find.byType(Tab).at(1));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('ChatMessageModel reads the message schema returned by the API', () {
    final model = ChatMessageModel.fromJson({
      'idx': 55,
      'uid': 7,
      'nn': 'Colega',
      'did': 'device-abc',
      'msg': 'bom estudo',
      'ts': 1762000000.5,
      'ua': 1762000001.0,
      'cat': 'study',
      'idel': false,
      'ilv': false,
    });

    expect(model.id, equals(55));
    expect(model.senderId, equals(7));
    expect(model.senderName, equals('Colega'));
    expect(model.message, equals('bom estudo'));
    expect(model.sentAt.millisecondsSinceEpoch, equals(1762000000500));
    // 'did' is a device id, so it must not leak into the studicon id.
    expect(model.studiconId, equals(-1));
  });

  test('sendMessage posts only the confirmed payload', () async {
    final apiClient = _CapturingApiClient();
    final repository = GroupRepository(apiClient: apiClient);

    await repository.sendMessage(groupId: 42, message: 'oi');

    expect(apiClient.lastPath, equals('/chat/group/message'));
    expect(apiClient.lastData, equals({'group_id': 42, 'message': 'oi'}));
  });

  testWidgets('a rejected message is rolled back and reported', (tester) async {
    await _pumpChat(tester);

    await tester.enterText(find.byType(TextField).last, 'mensagem de teste');
    await tester.pump();

    final sendButton = find.byIcon(Icons.send_rounded);
    await tester.ensureVisible(sendButton);
    await tester.pump();
    await tester.tap(sendButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('mensagem de teste'), findsNothing,
        reason: 'a bolha otimista precisa sumir quando o envio falha');
    expect(find.textContaining('Falha ao enviar mensagem'), findsOneWidget);
  });
}
