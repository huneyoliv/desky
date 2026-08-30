import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/group_admin_repository.dart';

void main() {
  group('GroupAdminRepository Tests', () {
    late GroupAdminRepository repository;
    late Dio mockDio;

    setUp(() {
      mockDio = Dio(BaseOptions(baseUrl: 'https://pi.tgclab.com'));
    });

    test('disbandGroup succeeds with DELETE request', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'DELETE' && options.path.contains('/group/setting/breakup')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'s': true},
            ));
          }
          return handler.next(options);
        },
      ));

      repository = GroupAdminRepository(apiClient: ApiClient(customDio: mockDio));
      final result = await repository.disbandGroup(12345);
      expect(result, isTrue);
    });

    test('disbandGroup falls back to POST request when DELETE fails', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'DELETE' && options.path.contains('/group/setting/breakup')) {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 405),
              type: DioExceptionType.badResponse,
            ));
          }
          if (options.method == 'POST' && options.path == '/group/setting/breakup') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'s': true},
            ));
          }
          return handler.next(options);
        },
      ));

      repository = GroupAdminRepository(apiClient: ApiClient(customDio: mockDio));
      final result = await repository.disbandGroup(12345);
      expect(result, isTrue);
    });

    test('disbandGroup returns false when both DELETE and POST fail', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 500),
            type: DioExceptionType.badResponse,
          ));
        },
      ));

      repository = GroupAdminRepository(apiClient: ApiClient(customDio: mockDio));
      final result = await repository.disbandGroup(12345);
      expect(result, isFalse);
    });

    test('updateGroupName succeeds on valid response', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' && options.path == '/group/setting/name') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'s': true},
            ));
          }
          return handler.next(options);
        },
      ));

      repository = GroupAdminRepository(apiClient: ApiClient(customDio: mockDio));
      final result = await repository.updateGroupName(12345, 'Novo Nome');
      expect(result, isTrue);
    });

    test('banMember and unbanMember execute correctly', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' &&
              (options.path == '/group/user/ban' || options.path == '/group/user/unban')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'s': true},
            ));
          }
          return handler.next(options);
        },
      ));

      repository = GroupAdminRepository(apiClient: ApiClient(customDio: mockDio));
      expect(await repository.banMember(12345, 999), isTrue);
      expect(await repository.unbanMember(12345, 999), isTrue);
    });
  });
}
