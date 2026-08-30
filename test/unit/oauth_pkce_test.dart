import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/oauth/oauth_pkce.dart';
import 'package:desky/core/oauth/oauth_user_info.dart';
import 'package:desky/core/oauth/oauth_exception.dart';

void main() {
  group('OAuthPkce Tests', () {
    test('generateVerifier returns url-safe string with requested length', () {
      final v1 = OAuthPkce.generateVerifier(64);
      expect(v1.length, equals(64));
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v1), isTrue);

      final v2 = OAuthPkce.generateVerifier(43);
      expect(v2.length, equals(43));
      expect(v1, isNot(equals(v2)));
    });

    test('generateChallenge returns valid base64url sha256 hash without padding', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final challenge = OAuthPkce.generateChallenge(verifier);
      expect(challenge.contains('='), isFalse);
      expect(challenge.contains('+'), isFalse);
      expect(challenge.contains('/'), isFalse);
      expect(challenge.isNotEmpty, isTrue);

      // Same verifier produces identical challenge
      final challenge2 = OAuthPkce.generateChallenge(verifier);
      expect(challenge, equals(challenge2));
    });

    test('generateState returns random string with specified length', () {
      final s1 = OAuthPkce.generateState(32);
      final s2 = OAuthPkce.generateState(32);
      expect(s1.length, equals(32));
      expect(s1, isNot(equals(s2)));
    });

    test('decodeJwtPayload decodes valid JWT payload into Map', () {
      final payloadData = {
        'sub': '1234567890',
        'name': 'Test User',
        'email': 'test@example.com',
        'iat': 1516239022
      };
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'RS256'}))).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode(jsonEncode(payloadData))).replaceAll('=', '');
      const signature = 'fake_signature_bytes';
      final mockJwt = '$header.$payload.$signature';

      final decoded = OAuthPkce.decodeJwtPayload(mockJwt);
      expect(decoded['sub'], equals('1234567890'));
      expect(decoded['name'], equals('Test User'));
      expect(decoded['email'], equals('test@example.com'));
    });

    test('decodeJwtPayload throws FormatException on invalid structure', () {
      expect(() => OAuthPkce.decodeJwtPayload('invalid.jwt'), throwsFormatException);
      expect(() => OAuthPkce.decodeJwtPayload('not_a_jwt'), throwsFormatException);
    });
  });

  group('OAuthUserInfo & OAuthException Tests', () {
    test('OAuthUserInfo stores and serializes correctly', () {
      const info = OAuthUserInfo(
        provider: 'Google',
        socialId: 'google_123',
        email: 'user@gmail.com',
        name: 'Google User',
      );
      expect(info.provider, equals('Google'));
      expect(info.socialId, equals('google_123'));
      expect(info.email, equals('user@gmail.com'));
      expect(info.name, equals('Google User'));

      final json = info.toJson();
      expect(json['provider'], equals('Google'));
      expect(json['socialId'], equals('google_123'));
    });

    test('OAuthException contains error message and cancelled state', () {
      const ex1 = OAuthException('Connection failed');
      expect(ex1.toString(), equals('Connection failed'));
      expect(ex1.isCancelled, isFalse);

      const ex2 = OAuthException('User cancelled', isCancelled: true);
      expect(ex2.isCancelled, isTrue);
    });
  });
}
