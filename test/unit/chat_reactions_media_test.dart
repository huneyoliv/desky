import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/models/chat_message_model.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDioWithReactionAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  dynamic lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    lastData = options.data;
    return ResponseBody.fromString(
      '{"s": true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Reactions and Media Tests', () {
    test('ChatMessageModel.fromJson parses img, th, and reactions correctly', () {
      final json = {
        'idx': 2,
        'uid': 16300695,
        'nn': 'Longkun',
        'msg': 'Photo',
        'ts': 1786320540.0499206,
        'img': 'https://alicdn.tgclab.com/chat/groups/6584641/1786320535133_0.jpg',
        'th': 'https://alicdn.tgclab.com/chat/groups/6584641/1786320535133_0_thumb.jpg',
        'reactions': {
          '👍': [16300695, 12345],
          '❤️': [999],
        },
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.id, 2);
      expect(msg.senderId, 16300695);
      expect(msg.senderName, 'Longkun');
      expect(msg.imageUrl, 'https://alicdn.tgclab.com/chat/groups/6584641/1786320535133_0.jpg');
      expect(msg.thumbUrl, 'https://alicdn.tgclab.com/chat/groups/6584641/1786320535133_0_thumb.jpg');
      expect(msg.reactions['👍']?.length, 2);
      expect(msg.reactions['❤️']?.first, 999);
    });

    test('ChatMessageModel copyWith updates reactions properly', () {
      final msg = ChatMessageModel(
        id: 1,
        senderId: 10,
        senderName: 'Carlos',
        studiconId: 377,
        message: 'Teste',
        sentAt: DateTime.now(),
      );

      final updated = msg.copyWith(reactions: {'🔥': [10]});
      expect(updated.reactions.containsKey('🔥'), true);
      expect(updated.reactions['🔥']?.first, 10);
    });

    test('GroupRepository sendReaction posts correct payload to API', () async {
      final dio = Dio();
      final adapter = MockDioWithReactionAdapter();
      dio.httpClientAdapter = adapter;
      final apiClient = ApiClient(customDio: dio);

      final repo = GroupRepository(apiClient: apiClient);
      final ok = await repo.sendReaction(groupId: 6584641, messageId: 2, emoji: '🔥');

      expect(ok, true);
      expect(adapter.lastOptions?.path, '/chat/group/reaction');
      expect(adapter.lastData['group_id'], 6584641);
      expect(adapter.lastData['idx'], 2);
      expect(adapter.lastData['reaction'], '🔥');
    });
  });
}
