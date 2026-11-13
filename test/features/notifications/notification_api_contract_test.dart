import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/theme/app_colors.dart';
import 'package:desky/data/models/notification_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/shared/widgets/notification_visuals.dart';

class _CapturingApiClient extends ApiClient {
  _CapturingApiClient({this.getResponse}) : super(customDio: Dio());

  final Map<String, dynamic>? getResponse;
  final List<String> getPaths = [];
  final List<MapEntry<String, dynamic>> posts = [];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    String? baseUrl,
  }) async {
    getPaths.add(path);
    return Response(
      requestOptions: RequestOptions(path: path),
      data: getResponse,
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    posts.add(MapEntry(path, data));
    return Response(
      requestOptions: RequestOptions(path: path),
      data: const {'s': true},
      statusCode: 200,
    );
  }
}

/// One notification exactly as the live API returns it.
Map<String, dynamic> _notice({
  int id = 7,
  String i1 = 'Grupo aprovado',
  String i2 = '',
  String i3 = '',
  String i4 = '',
  bool ir = false,
  String nt = 'GROUP_JOIN_APPROVED',
  String c = '2026-11-13 07:33:00.000000',
}) =>
    {'id': id, 'i1': i1, 'i2': i2, 'i3': i3, 'i4': i4, 'ir': ir, 'nt': nt, 'c': c};

void main() {
  group('Contrato real das notificacoes', () {
    test('markAsRead usa /user/read-notice com noticeID', () async {
      final api = _CapturingApiClient();
      final repo = NotificationRepository(apiClient: api);

      final ok = await repo.markAsRead(7);

      expect(ok, isTrue);
      expect(api.posts, hasLength(1));
      expect(api.posts.single.key, equals('/user/read-notice'));
      expect(api.posts.single.value, equals({'noticeID': 7}));
    });

    test('markAllAsRead marca cada nao lida individualmente', () async {
      final api = _CapturingApiClient();
      final repo = NotificationRepository(apiClient: api);

      await repo.markAllAsRead(ids: [1, 2, 3]);

      expect(api.posts, hasLength(3));
      expect(api.posts.every((p) => p.key == '/user/read-notice'), isTrue);
      expect(api.posts.map((p) => (p.value as Map)['noticeID']).toList(), equals([1, 2, 3]));
    });

    test('fetchNotifications le o schema real do array ns', () async {
      final api = _CapturingApiClient(
        getResponse: {'s': true, 'ns': [_notice(id: 11), _notice(id: 12, ir: true)]},
      );
      final repo = NotificationRepository(apiClient: api);

      final items = await repo.fetchNotifications();

      expect(items, hasLength(2));
      expect(items.first.id, equals(11));
      expect(items.first.title, equals('Grupo aprovado'));
      expect(items.first.type, equals('GROUP_JOIN_APPROVED'));
      expect(items.first.isRead, isFalse);
      expect(items.first.createdAt.year, equals(2026));
      expect(items.first.createdAt.month, equals(11));
      expect(items.first.createdAt.day, equals(13));
      // i2/i3 vazios: nao inventar texto de detalhe
      expect(items.first.message, isEmpty);
    });

    test('fetchUnreadCount conta os nao lidos de ns', () async {
      final api = _CapturingApiClient(
        getResponse: {
          's': true,
          'ns': [_notice(id: 1), _notice(id: 2, ir: true), _notice(id: 3)],
        },
      );
      final repo = NotificationRepository(apiClient: api);

      expect(await repo.fetchUnreadCount(), equals(2));
    });

    test('fetchUnreadCount nao usa a rota morta /notice/unread_count', () async {
      final api = _CapturingApiClient(getResponse: {'s': true, 'ns': []});
      final repo = NotificationRepository(apiClient: api);

      expect(await repo.fetchUnreadCount(), equals(0));
      expect(api.getPaths.any((p) => p.contains('/notice/unread_count')), isFalse);
    });
  });

  group('Tipo real da notificacao (nt)', () {
    test('normaliza os codigos que a API devolve', () {
      String kind(String nt) => NotificationModel.fromJson(_notice(nt: nt)).normalizedType;

      expect(kind('GROUP_WARNING'), equals('warning'));
      expect(kind('WARNING'), equals('warning'));
      expect(kind('GROUP_JOIN_APPROVED'), equals('join'));
      expect(kind('GROUP_JOIN_REJECTED'), equals('join'));
      expect(kind('GROUP_JOIN_WAITING'), equals('request'));
      expect(kind('GROUP_NEW_REQUEST'), equals('request'));
      expect(kind('GROUP_POST_COMMENT'), equals('post'));
      expect(kind('GROUP_NEW_MEMBER'), equals('member'));
      expect(kind('GROUP_OUT'), equals('membership'));
      expect(kind('GROUP_OWNER'), equals('membership'));
      expect(kind('algo_desconhecido'), equals('info'));
      // O app oficial nao possui tipo de cutucada: 'shake' nao existe na API.
      expect(kind('shake'), equals('info'));
    });

    test('advertencia de grupo recebe o icone de aviso', () {
      final warning = NotificationModel.fromJson(_notice(nt: 'GROUP_WARNING'));
      final normal = NotificationModel.fromJson(_notice(nt: 'GROUP_JOIN_APPROVED'));

      expect(notificationIcon(warning), equals(Icons.warning_amber_rounded));
      expect(notificationIcon(normal), equals(Icons.group_add_outlined));
      expect(
        notificationColor(warning, primary: const Color(0xFF123456)),
        equals(AppColors.error),
      );
      expect(
        notificationColor(normal, primary: const Color(0xFF123456)),
        equals(const Color(0xFF123456)),
      );
    });
  });
}
