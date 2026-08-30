import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_repository.dart';

void main() {
  group('GroupRepository Studicon Tests', () {
    late GroupRepository repository;
    late Dio mockDio;

    setUp(() {
      mockDio = Dio();
      final apiClient = ApiClient(customDio: mockDio);
      repository = GroupRepository(apiClient: apiClient);
    });

    test('updateGroupMemberStudicon sends correct payload to /group/join/v2', () async {
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/group/join/v2')) {
              expect(options.data['id'], 12345);
              expect(options.data['studiconID'], 46);
              expect(options.data['nickname'], 'Longkun');
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

      final result = await repository.updateGroupMemberStudicon(
        groupId: 12345,
        studiconId: 46,
        nickname: 'Longkun',
      );

      expect(result, isTrue);
    });
  });
}
