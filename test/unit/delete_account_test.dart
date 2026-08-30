import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/api/auth_interceptor.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Account Deletion Tests', () {
    late FakeSecureStorage storage;

    setUp(() {
      storage = FakeSecureStorage();
    });

    test('deleteAccount calls /user/unregister and clears stored JWT token', () async {
      await storage.write(key: AuthInterceptor.keyJwtToken, value: 'active_token_123');

      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/user/unregister');
        expect(options.method, 'GET');
        return {
          'status': 200,
          'data': '{"s":true}',
        };
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      final success = await repo.deleteAccount();
      expect(success, true);

      final tokenAfter = await storage.read(key: AuthInterceptor.keyJwtToken);
      expect(tokenAfter, isNull);
    });

    test('AuthNotifier.deleteAccount resets state to unauthenticated', () async {
      await storage.write(key: AuthInterceptor.keyJwtToken, value: 'active_token_123');

      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path == '/user/unregister') {
          return {'status': 200, 'data': '{"s":true}'};
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      final notifier = AuthNotifier(repo);
      notifier.state = const AuthState(
        user: UserModel(
          id: 12345,
          name: 'Deletable User',
          email: 'delete@test.com',
          studiconId: 1,
          jwtToken: 'active_token_123',
        ),
      );

      expect(notifier.state.isAuthenticated, true);

      final ok = await notifier.deleteAccount();
      expect(ok, true);
      expect(notifier.state.isAuthenticated, false);
      expect(notifier.state.user, isNull);
    });
  });
}
