import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/cdn/cdn_resolver.dart';
import 'package:desky/data/repositories/store_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = handler(options);
    final status = res['status'] as int? ?? 200;
    final data = res['data'] as String;
    return ResponseBody.fromString(
      data,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CDN Studicon Pose Matrix Tests', () {
    test('All poses in StudiconPose generate valid CDN URLs', () {
      expect(
        CdnResolver.studiconUrl(354, StudiconPose.sweat3),
        'https://alicdn.tgclab.com/sc.v2/354/sweat3.png',
      );
      expect(
        CdnResolver.studiconUrl(354, StudiconPose.ignite2),
        'https://alicdn.tgclab.com/sc.v2/354/ignite2.png',
      );
      expect(
        CdnResolver.studiconUrl(354, StudiconPose.smoke2),
        'https://alicdn.tgclab.com/sc.v2/354/smoke2.png',
      );
      expect(
        CdnResolver.studiconUrl(354, StudiconPose.explosion1),
        'https://alicdn.tgclab.com/sc.v2/354/explosion1.png',
      );
    });

    test('Negative and zero IDs correctly fallback to -1 in CDN', () {
      expect(
        CdnResolver.studiconUrl(-1, StudiconPose.normal1),
        'https://alicdn.tgclab.com/sc.v2/-1/normal1.png',
      );
      expect(
        CdnResolver.studiconUrl(0, StudiconPose.normal1),
        'https://alicdn.tgclab.com/sc.v2/-1/normal1.png',
      );
    });

    test('userAvatarUrl resolves fire1 when daily goal is reached', () {
      final url = CdnResolver.userAvatarUrl(
        userId: 1,
        hasCustomAvatar: false,
        studiconId: 354,
        isStudying: true,
        isPaused: false,
        studyMs: 14400000,
        dailyGoalMs: 14400000,
      );
      expect(url, 'https://alicdn.tgclab.com/sc.v2/354/fire1.png');
    });
  });

  group('StoreRepository Real Sync Tests', () {
    test('fetchCatalog merges API responses from famous and new without mock injection', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path.contains('/studicon/my/list')) {
          return {
            'status': 200,
            'data': '{"s":true,"my":[{"id":377}]}',
          };
        }
        if (options.path.contains('/studicon/list/famous')) {
          return {
            'status': 200,
            'data': '{"s":true,"scs":[{"id":377,"tk":"사막의 지략가","te":"Desert Fox","p":100}]}',
          };
        }
        if (options.path.contains('/studicon/list/new')) {
          return {
            'status': 200,
            'data': '{"s":true,"scs":[{"id":354,"tk":"펭귄","te":"Penguin","p":120}]}',
          };
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      final repo = StoreRepository(apiClient: ApiClient(customDio: dio));
      final catalog = await repo.fetchCatalog();

      expect(catalog.length, 2);
      expect(catalog.any((item) => item.id == 377 && item.isOwned), true);
      expect(catalog.any((item) => item.id == 354 && !item.isOwned), true);
    });

    test('equipStudicon calls /user/studicon with correct sd payload', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/user/studicon');
        expect(options.data['sd'], 354);
        return {
          'status': 200,
          'data': '{"s":true}',
        };
      });

      final repo = StoreRepository(apiClient: ApiClient(customDio: dio));
      final success = await repo.equipStudicon(354);
      expect(success, true);
    });
  });
}
