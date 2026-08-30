import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_repository.dart';

void main() {
  group('GroupRepository Tests', () {
    late GroupRepository repository;
    late Dio mockDio;

    setUp(() {
      mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/logs/group/members/v2')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'ms': [
                      {
                        'ud': 16300695,
                        'n': 'Alice',
                        'st': 377,
                        'is': true,
                        'sm': 3600000,
                        'hasCustomAvatar': false,
                      },
                      {
                        'ud': 16300696,
                        'n': 'Bob',
                        'st': 100,
                        'is': false,
                        'sm': 0,
                        'hasCustomAvatar': true,
                      },
                    ],
                  },
                ),
              );
            }
            if (options.path.contains('/group/push/shake')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'s': true},
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final apiClient = ApiClient(customDio: mockDio);
      repository = GroupRepository(apiClient: apiClient);
    });

    test('fetchMembers parses active studying group members correctly', () async {
      final members = await repository.fetchMembers(6487271);

      expect(members.length, equals(2));
      expect(members[0].name, equals('Alice'));
      expect(members[0].isStudying, isTrue);
      expect(members[0].avatarUrl, equals('https://alicdn.tgclab.com/sc.v2/377/sweat1.png'));

      expect(members[1].name, equals('Bob'));
      expect(members[1].avatarUrl, equals('https://alicdn.tgclab.com/user/profile/16300696.jpg'));
    });

    test('shakeMember triggers shake push notification', () async {
      final success = await repository.shakeMember(groupId: 6487271, targetUserId: 16300696);
      expect(success, isTrue);
    });
  });
}
