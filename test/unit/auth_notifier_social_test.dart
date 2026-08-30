import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/oauth/oauth_exception.dart';
import 'package:desky/core/oauth/oauth_user_info.dart';
import 'package:desky/core/oauth/providers/google_oauth_service.dart';
import 'package:desky/data/models/user_model.dart';
import 'package:desky/data/repositories/auth_repository.dart';
import 'package:desky/features/auth/auth_notifier.dart';

class MockAuthRepository extends AuthRepository {
  OAuthUserInfo? lastSocialLogin;
  bool shouldFail = false;

  @override
  Future<UserModel> signInWithSocial({
    required String provider,
    required String socialId,
    required String email,
    required String name,
    String language = 'pt',
  }) async {
    if (shouldFail) {
      throw Exception('Falha ao autenticar no backend');
    }
    lastSocialLogin = OAuthUserInfo(
      provider: provider,
      socialId: socialId,
      email: email,
      name: name,
    );
    return UserModel(
      id: 123,
      name: name,
      email: email,
      studiconId: 19,
      jwtToken: 'jwt_mock_token_123',
    );
  }
}

class MockGoogleOAuthService extends GoogleOAuthService {
  bool shouldCancel = false;
  bool shouldFail = false;

  MockGoogleOAuthService() : super(clientId: 'mock-google-client-id');

  @override
  Future<OAuthUserInfo> authenticate({Duration timeout = const Duration(minutes: 3)}) async {
    if (shouldCancel) {
      throw const OAuthException('User cancelled', isCancelled: true);
    }
    if (shouldFail) {
      throw const OAuthException('Google authentication failed');
    }
    return const OAuthUserInfo(
      provider: 'Google',
      socialId: 'google_sub_10987654321',
      email: 'user@gmail.com',
      name: 'Google User',
    );
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  group('AuthNotifier Social Login Tests', () {
    late MockAuthRepository mockRepo;
    late MockGoogleOAuthService mockGoogle;
    late AuthNotifier notifier;

    setUp(() {
      mockRepo = MockAuthRepository();
      mockGoogle = MockGoogleOAuthService();
      notifier = AuthNotifier(
        mockRepo,
        googleOAuthService: mockGoogle,
      );
    });

    test('signInWithGoogle authenticates user and updates state', () async {
      await notifier.signInWithGoogle();

      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.user?.email, equals('user@gmail.com'));
      expect(notifier.state.user?.jwtToken, equals('jwt_mock_token_123'));
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
      expect(mockRepo.lastSocialLogin?.provider, equals('Google'));
      expect(mockRepo.lastSocialLogin?.socialId, equals('google_sub_10987654321'));
    });

    test('signInWithGoogle handles cancellation without setting error', () async {
      mockGoogle.shouldCancel = true;
      await notifier.signInWithGoogle();

      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    test('signInWithGoogle sets errorMessage on failure', () async {
      mockGoogle.shouldFail = true;
      await notifier.signInWithGoogle();

      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('cancelOAuth cancels active oauth services and resets loading', () async {
      notifier.state = notifier.state.copyWith(isLoading: true);
      await notifier.cancelOAuth();

      expect(notifier.state.isLoading, isFalse);
    });

    test('updateStudicon updates authenticated user studiconId', () async {
      await notifier.signInWithGoogle();
      expect(notifier.state.user?.studiconId, 19);

      final success = await notifier.updateStudicon(-1);
      expect(success, isTrue);
      expect(notifier.state.user?.studiconId, -1);
    });
  });
}
