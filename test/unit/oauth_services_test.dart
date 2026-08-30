import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/oauth/providers/google_oauth_service.dart';

void main() {
  group('GoogleOAuthService configuration & instantiation', () {
    test('instantiates with custom or env client id and secret', () {
      final service = GoogleOAuthService(
        clientId: 'custom-google-id.apps.googleusercontent.com',
        clientSecret: 'custom-google-secret',
      );
      expect(service.effectiveClientId, equals('custom-google-id.apps.googleusercontent.com'));
      expect(service.effectiveClientSecret, equals('custom-google-secret'));
      expect(service.isConfigured, isTrue);
    });

    test('defaults to environment or default client id', () {
      final service = GoogleOAuthService();
      expect(service.effectiveClientId.contains('apps.googleusercontent.com'), isTrue);
      expect(service.isConfigured, isTrue);
    });
  });
}
