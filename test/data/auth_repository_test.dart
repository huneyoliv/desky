import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/core/api/api_exception.dart';
import 'package:desky/core/constants/api_constants.dart';
import 'package:desky/core/oauth/social_signup_exception.dart';
import 'package:desky/data/repositories/auth_repository.dart';

class MockStorage extends FlutterSecureStorage {
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
    if (value != null) _data[key] = value;
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
}

void main() {
  group('AuthRepository Tests', () {
    late AuthRepository repository;
    late MockStorage mockStorage;
    late Dio mockDio;

    setUp(() {
      mockStorage = MockStorage();
      mockDio = Dio();
      // Setup adapter interceptor mock
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/user/sign-in-jwt')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'jwt': 'fake_jwt_token_123',
                    'id': 16300695,
                    'n': 'Test User',
                    'e': 'test@example.com',
                    'pv': 377,
                  },
                ),
              );
            }
            if (options.path.contains('/user/v2/splash-login')) {
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
      repository = AuthRepository(apiClient: apiClient, storage: mockStorage);
    });

    test('signInWithEmail authenticates and stores JWT token', () async {
      final user = await repository.signInWithEmail(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(user.id, equals(16300695));
      expect(user.name, equals('Test User'));
      expect(user.jwtToken, equals('fake_jwt_token_123'));

      final storedToken = await mockStorage.read(key: 'jwt_token');
      expect(storedToken, equals('fake_jwt_token_123'));
    });

    test('signInWithEmail handles error code 112 (wrong password)', () async {
      final errorDio = Dio();
      errorDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': false, 'c': '112'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: errorDio), storage: mockStorage);

      expect(
        () => repo.signInWithEmail(email: 'test@example.com', password: 'wrong'),
        throwsA(predicate((e) => e.toString().contains('Senha incorreta'))),
      );
    });

    test('signInWithEmail handles error code 113 (email not found)', () async {
      final errorDio = Dio();
      errorDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': false, 'c': '113'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: errorDio), storage: mockStorage);

      expect(
        () => repo.signInWithEmail(email: 'notfound@example.com', password: 'pass'),
        throwsA(predicate((e) => e.toString().contains('E-mail não cadastrado'))),
      );
    });

    test('signInWithEmail handles error code 114 (account suspended)', () async {
      final errorDio = Dio();
      errorDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': false, 'c': '114'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: errorDio), storage: mockStorage);

      expect(
        () => repo.signInWithEmail(email: 'suspended@example.com', password: 'pass'),
        throwsA(predicate((e) => e.toString().contains('Conta suspensa'))),
      );
    });

    test('logout deletes stored JWT token', () async {
      await mockStorage.write(key: 'jwt_token', value: 'token_abc');
      await repository.logout();

      final storedToken = await mockStorage.read(key: 'jwt_token');
      expect(storedToken, isNull);
    });

    test('signInWithSocial sends password:null and returns user on success', () async {
      Map<String, dynamic>? capturedData;
      final socialDio = Dio();
      socialDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/user/social/sign-up-jwt') || options.path.contains('/user/sign-in-jwt')) {
              capturedData = options.data as Map<String, dynamic>?;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'jwt': 'social_jwt_token',
                    'id': 99999,
                    'n': 'Google User',
                    'e': 'google@gmail.com',
                    'pv': 1,
                  },
                ),
              );
            }
            if (options.path.contains('/user/v2/splash-login')) {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {'s': true}),
              );
            }
            return handler.next(options);
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: socialDio), storage: mockStorage);

      final user = await repo.signInWithSocial(
        provider: 'Google',
        socialId: 'google_sub_12345',
        email: 'google@gmail.com',
        name: 'Google User',
      );

      expect(user.id, equals(99999));
      expect(user.name, equals('Google User'));
      expect(capturedData, isNotNull);
      expect(capturedData!.containsKey('providerId'), isTrue);
      expect(capturedData!['providerId'], equals('google_sub_12345'));
      expect(capturedData!['loginProvider'], equals('Google'));
    });

    test('signInWithSocial throws SocialSignUpRequiredException on error c:111 (social id not found)', () async {
      final errorDio = Dio();
      errorDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': false, 'c': '111'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: errorDio), storage: mockStorage);

      expect(
        () => repo.signInWithSocial(
          provider: 'Google',
          socialId: 'nonexistent_sub',
          email: 'ghost@gmail.com',
          name: 'Ghost',
        ),
        throwsA(isA<SocialSignUpRequiredException>()),
      );
    });

    test('signUpWithSocial completes registration and returns user model', () async {
      Map<String, dynamic>? capturedData;
      final socialDio = Dio();
      socialDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/user/social/sign-up-jwt')) {
              capturedData = options.data as Map<String, dynamic>?;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'jwt': 'social_jwt_created',
                    'id': 112233,
                    'n': 'NewUser',
                    'e': 'new@gmail.com',
                    'pv': 1,
                  },
                ),
              );
            }
            if (options.path.contains('/user/v2/splash-login')) {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {'s': true}),
              );
            }
            return handler.next(options);
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: socialDio), storage: mockStorage);

      final user = await repo.signUpWithSocial(
        provider: 'Google',
        socialId: 'google_new_sub',
        email: 'new@gmail.com',
        name: 'New Google User',
        nickname: 'NewUser',
        countryId: 1,
        categoryId: 10,
      );

      expect(user.id, equals(112233));
      expect(user.name, equals('NewUser'));
      expect(capturedData, isNotNull);
      expect(capturedData!['nickname'], equals('NewUser'));
      expect(capturedData!['countryId'], equals(1));
      expect(capturedData!['categoryId'], equals(10));
    });

    test('signInWithJwt saves token and returns user model on valid splashLogin', () async {
      final jwtDio = Dio();
      jwtDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/user/v2/splash-login')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'id': 77777,
                    'n': 'QR Synced User',
                    'e': 'qr@gmail.com',
                    'pv': 19,
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: jwtDio), storage: mockStorage);

      final user = await repo.signInWithJwt('JWT valid_qr_jwt_token_123');

      expect(user.id, equals(77777));
      expect(user.name, equals('QR Synced User'));
      expect(user.jwtToken, equals('valid_qr_jwt_token_123'));

      final stored = await mockStorage.read(key: 'jwt_token');
      expect(stored, equals('valid_qr_jwt_token_123'));
    });

    test('signInWithJwt throws ApiException on empty or invalid token', () async {
      final repo = AuthRepository(apiClient: ApiClient(customDio: mockDio), storage: mockStorage);

      expect(
        () => repo.signInWithJwt(''),
        throwsA(isA<ApiException>()),
      );
    });

    test('sendSignUpVerificationCode calls /user/v2/send-signup-code and handles success', () async {
      Map<String, dynamic>? requestData;
      String? requestPath;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestPath = options.path;
            requestData = options.data as Map<String, dynamic>?;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': true},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);

      final result = await repo.sendSignUpVerificationCode('newuser@example.com', language: 'pt');
      expect(result, isTrue);
      expect(requestPath, contains('/user/v2/send-signup-code'));
      expect(requestData?['email'], equals('newuser@example.com'));
      expect(requestData?['language'], equals('pt'));
    });

    test('sendSignUpVerificationCode throws ApiException on error code 106 (already registered)', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': false, 'c': '106'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);

      expect(
        () => repo.sendSignUpVerificationCode('registered@example.com'),
        throwsA(predicate((e) => e.toString().contains('já está registrado'))),
      );
    });

    test('verifySignUpCode calls /user/v2/verify-code and verifies valid code', () async {
      Map<String, dynamic>? requestData;
      String? requestPath;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestPath = options.path;
            requestData = options.data as Map<String, dynamic>?;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': true},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);

      final result = await repo.verifySignUpCode('newuser@example.com', '628029');
      expect(result, isTrue);
      expect(requestPath, contains('/user/v2/verify-code'));
      expect(requestData?['code'], equals('628029'));
    });

    test('verifySignUpCode throws on invalid code', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': false, 'c': 'invalid_auth_code_msg'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);

      expect(
        () => repo.verifySignUpCode('user@example.com', '000000'),
        throwsA(predicate((e) => e.toString().contains('não corresponde'))),
      );
    });

    test('signUp calls /user/v2/create-email-account, updates nickname and stores token', () async {
      final pathsCalled = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            pathsCalled.add(options.path);
            if (options.path.contains('/user/v2/create-email-account')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'jwt': 'created_jwt_token_456',
                    'id': 17729897,
                    'e': 'socloud476@gmail.com',
                    'n': '',
                    'lp': 'Email',
                  },
                ),
              );
            }
            if (options.path.contains('/user/nickname/change')) {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {'s': true, 'pv': 1}),
              );
            }
            if (options.path.contains('/category/category-by-country')) {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {'s': true, 'cid': 438}),
              );
            }
            if (options.path.contains('/user/v2/splash-login')) {
              return handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: {'s': true}),
              );
            }
            return handler.next(options);
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);

      final user = await repo.signUp(
        email: 'socloud476@gmail.com',
        password: 'Password123!',
        code: '628029',
        nickname: 'Katchau',
        categoryId: 438,
        countryId: 23,
      );

      expect(user.id, equals(17729897));
      expect(user.jwtToken, equals('created_jwt_token_456'));
      expect(pathsCalled, contains('/user/v2/create-email-account'));
      expect(pathsCalled, contains('/user/nickname/change'));
      expect(pathsCalled, contains('/category/category-by-country'));

      final storedToken = await mockStorage.read(key: 'jwt_token');
      expect(storedToken, equals('created_jwt_token_456'));
    });

    test('deleteAccount calls GET /user/unregister and deletes token on success', () async {
      String? calledMethod;
      String? calledPath;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calledMethod = options.method;
            calledPath = options.path;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'s': true, 'm': '정상적으로 탈퇴 되었습니다.'},
              ),
            );
          },
        ),
      );
      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);
      await mockStorage.write(key: 'jwt_token', value: 'token_to_delete');

      final success = await repo.deleteAccount();
      expect(success, isTrue);
      expect(calledMethod, equals('GET'));
      expect(calledPath, contains('/user/unregister'));

      final stored = await mockStorage.read(key: 'jwt_token');
      expect(stored, isNull);
    });

    test('tryRestoreSession preserves locally saved studicon when server returns -1', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'valid_token_789',
        AuthRepository.keyUserEquippedStudiconId: 354,
        AuthRepository.keyCachedUser: '{"id":16300695,"name":"User","email":"u@test.com","sd":354}',
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains(ApiConstants.splashLogin)) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'p': {'csd': -1, 'ssd': -1, 'pv': 46},
                    'scs': [354],
                  },
                ),
              );
            }
            if (options.path.contains(ApiConstants.reloadInfo)) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'p': {'csd': -1, 'ssd': -1, 'pv': 46},
                    'scs': [354],
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);
      final restored = await repo.tryRestoreSession();

      expect(restored, isNotNull);
      expect(restored!.studiconId, equals(354));
    });

    test('tryRestoreSession updates studicon when server returns positive sd > 0', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'valid_token_789',
        AuthRepository.keyUserEquippedStudiconId: 354,
        AuthRepository.keyCachedUser: '{"id":16300695,"name":"User","email":"u@test.com","sd":354}',
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains(ApiConstants.splashLogin)) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'p': {'sd': 100, 'pv': 46},
                    'scs': [354, 100],
                  },
                ),
              );
            }
            if (options.path.contains(ApiConstants.reloadInfo)) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    's': true,
                    'p': {'sd': 100, 'pv': 46},
                    'scs': [354, 100],
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final repo = AuthRepository(apiClient: ApiClient(customDio: dio), storage: mockStorage);
      final restored = await repo.tryRestoreSession();

      expect(restored, isNotNull);
      expect(restored!.studiconId, equals(100));
    });
  });
}
