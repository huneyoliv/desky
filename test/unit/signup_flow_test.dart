import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/api/api_exception.dart';
import 'package:desky/core/api/auth_interceptor.dart';
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
  group('Sign-Up & Email Verification Tests', () {
    late FakeSecureStorage storage;

    setUp(() {
      storage = FakeSecureStorage();
    });

    test('sendSignUpVerificationCode succeeds on valid email', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/user/v2/send-signup-code');
        return {
          'status': 200,
          'data': '{"s":true}',
        };
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      final success = await repo.sendSignUpVerificationCode('test@gmail.com');
      expect(success, true);
    });

    test('sendSignUpVerificationCode throws ApiException when email already in use', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        return {
          'status': 200,
          'data': '{"s":false,"c":"106"}',
        };
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      expect(
        () => repo.sendSignUpVerificationCode('used@gmail.com'),
        throwsA(isA<ApiException>()),
      );
    });

    test('verifySignUpCode validates 6-digit code', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/user/v2/verify-code');
        return {
          'status': 200,
          'data': '{"s":true}',
        };
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      final ok = await repo.verifySignUpCode('test@gmail.com', '123456');
      expect(ok, true);
    });

    test('signUp registers user and stores JWT token', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path == '/user/v2/create-email-account') {
          return {
            'status': 200,
            'data': '{"s":true,"jwt":"new_user_jwt_token_xyz","id":998877,"email":"novo@gmail.com","name":"NovoUser","todayStudyTime":0,"totalStudyTime":0,"dday":null}',
          };
        }
        if (options.path.contains('/user/nickname/change') ||
            options.path.contains('/category/category-by-country') ||
            options.path.contains('/user/v2/splash-login')) {
          return {'status': 200, 'data': '{"s":true}'};
        }
        return {'status': 404, 'data': '{"s":false}'};
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      final user = await repo.signUp(
        email: 'novo@gmail.com',
        password: 'Password123!',
        code: '123456',
        nickname: 'NovoUser',
        categoryId: 1,
        countryId: 23,
      );

      expect(user.id, 998877);
      expect(user.name, 'NovoUser');
      expect(user.email, 'novo@gmail.com');
      expect(user.jwtToken, 'new_user_jwt_token_xyz');

      final stored = await storage.read(key: AuthInterceptor.keyJwtToken);
      expect(stored, 'new_user_jwt_token_xyz');
    });

    test('AuthNotifier.signUp transitions state to authenticated user', () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = MockAdapter((options) {
        if (options.path == '/user/v2/create-email-account') {
          return {
            'status': 200,
            'data': '{"s":true,"jwt":"jwt_notifier_test","id":1001,"email":"notifier@test.com","name":"NotifierUser","todayStudyTime":0,"totalStudyTime":0,"dday":null}',
          };
        }
        return {'status': 200, 'data': '{"s":true}'};
      });

      final repo = AuthRepository(
        apiClient: ApiClient(customDio: dio),
        storage: storage,
      );

      final notifier = AuthNotifier(repo);
      final ok = await notifier.signUp(
        email: 'notifier@test.com',
        password: 'pass',
        code: '123456',
        nickname: 'NotifierUser',
        categoryId: 1,
        countryId: 23,
      );

      expect(ok, true);
      expect(notifier.state.isAuthenticated, true);
      expect(notifier.state.user?.name, 'NotifierUser');
    });
  });
}
