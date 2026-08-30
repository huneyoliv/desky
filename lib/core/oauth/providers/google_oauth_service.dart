import 'package:dio/dio.dart';
import '../../config/env_config.dart';
import '../oauth_desktop_service.dart';
import '../oauth_exception.dart';
import '../oauth_pkce.dart';
import '../oauth_user_info.dart';

class GoogleOAuthService {
  final Dio _dio;
  final OAuthDesktopService _desktopService;
  final String clientId;
  final String? clientSecret;

  GoogleOAuthService({
    Dio? dio,
    OAuthDesktopService? desktopService,
    String? clientId,
    this.clientSecret,
  })  : _dio = dio ?? Dio(),
        _desktopService = desktopService ?? OAuthDesktopService(),
        clientId = clientId ?? '';

  String get effectiveClientId =>
      clientId.isNotEmpty ? clientId : EnvConfig.googleClientId;

  String? get effectiveClientSecret =>
      (clientSecret != null && clientSecret!.isNotEmpty)
          ? clientSecret
          : (EnvConfig.googleClientSecret.isNotEmpty
              ? EnvConfig.googleClientSecret
              : null);

  bool get isConfigured => effectiveClientId.isNotEmpty;

  Future<OAuthUserInfo> authenticate({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final activeClientId = effectiveClientId;
    final activeClientSecret = effectiveClientSecret;

    if (activeClientId.isEmpty) {
      throw const OAuthException('Google Client ID não configurado no arquivo .env.');
    }

    final verifier = OAuthPkce.generateVerifier();
    final challenge = OAuthPkce.generateChallenge(verifier);
    final state = OAuthPkce.generateState();
    int? activePort;

    try {
      final callbackParams = await _desktopService.startAuthFlow(
        authUrlBuilder: (port) {
          activePort = port;
          final redirectUri = 'http://127.0.0.1:$port';
          return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
            'client_id': activeClientId,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            'scope': 'openid email profile',
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
            'state': state,
            'prompt': 'select_account',
          });
        },
        expectedState: state,
        timeout: timeout,
      );

      final code = callbackParams['code'];
      if (code == null || code.isEmpty) {
        throw const OAuthException('Código de autorização não recebido do Google.');
      }

      final redirectUri = 'http://127.0.0.1:$activePort';
      final Map<String, dynamic> tokenRequestBody = {
        'client_id': activeClientId,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      };
      if (activeClientSecret != null && activeClientSecret.isNotEmpty) {
        tokenRequestBody['client_secret'] = activeClientSecret;
      }

      final tokenResponse = await _dio.post(
        'https://oauth2.googleapis.com/token',
        data: tokenRequestBody,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final tokenData = tokenResponse.data;
      if (tokenData is! Map || tokenData['id_token'] == null) {
        final errorDesc = tokenData is Map
            ? (tokenData['error_description'] ?? tokenData['error'] ?? 'Falha ao trocar código Google por token')
            : 'Resposta inválida do servidor Google';
        throw OAuthException(errorDesc.toString());
      }

      final idToken = tokenData['id_token'].toString();
      final payload = OAuthPkce.decodeJwtPayload(idToken);

      final socialId = payload['sub']?.toString() ?? '';
      final email = payload['email']?.toString() ?? '';
      final name = payload['name']?.toString() ??
          (email.isNotEmpty ? email.split('@').first : 'Usuário Google');

      if (socialId.isEmpty) {
        throw const OAuthException('Identificador de usuário Google não encontrado no token.');
      }

      return OAuthUserInfo(
        provider: 'Google',
        socialId: socialId,
        email: email,
        name: name,
      );
    } catch (e) {
      if (e is OAuthException) rethrow;
      throw OAuthException('Erro ao autenticar com Google: $e');
    }
  }

  Future<void> cancel() => _desktopService.cancel();
}
