import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'oauth_exception.dart';

class OAuthDesktopService {
  HttpServer? _server;
  Completer<Map<String, String>>? _completer;

  Future<Map<String, String>> startAuthFlow({
    required Uri Function(int port) authUrlBuilder,
    String? expectedState,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    await cancel();

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    final completer = Completer<Map<String, String>>();
    _completer = completer;

    final port = server.port;
    final authUri = authUrlBuilder(port);

    server.listen(
      (HttpRequest request) async {
        final uri = request.uri;
        final params = uri.queryParameters;

        final isFavicon = uri.path.endsWith('favicon.ico');
        if (isFavicon) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final code = params['code'];
        final error = params['error'] ?? params['error_description'];
        final state = params['state'];

        final bool isSuccess = code != null &&
            code.isNotEmpty &&
            (expectedState == null || state == expectedState);

        request.response.headers.contentType =
            ContentType('text', 'html', charset: 'utf-8');
        request.response.statusCode = isSuccess ? HttpStatus.ok : HttpStatus.badRequest;

        final html = _buildResponseHtml(
          isSuccess: isSuccess,
          error: error ??
              (expectedState != null && state != expectedState
                  ? 'State mismatch (CSRF protection)'
                  : null),
        );
        request.response.write(html);
        await request.response.close();

        if (isSuccess) {
          if (!completer.isCompleted) {
            completer.complete(params);
          }
        } else if (error != null) {
          if (!completer.isCompleted) {
            completer.completeError(OAuthException(error));
          }
        }
      },
      onError: (err) {
        if (!completer.isCompleted) {
          completer.completeError(OAuthException('Erro no servidor local: $err'));
        }
      },
      cancelOnError: true,
    );

    try {
      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const OAuthException('Não foi possível abrir o navegador padrão.');
      }

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw const OAuthException('Tempo limite de autenticação excedido (3 minutos).');
        },
      );
      return result;
    } finally {
      await cancel();
    }
  }

  Future<void> cancel() async {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(
        const OAuthException('Autenticação cancelada pelo usuário.', isCancelled: true),
      );
    }
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
    }
    _completer = null;
  }

  String _buildResponseHtml({required bool isSuccess, String? error}) {
    final title = isSuccess ? 'Login realizado com sucesso!' : 'Falha na autenticação';
    final desc = isSuccess
        ? 'Você já pode fechar esta aba e retornar ao <strong>Desky</strong>.'
        : 'Ocorreu um erro: ${error ?? "Autorização negada."}. Retorne ao aplicativo.';
    final bgGradient = isSuccess
        ? 'linear-gradient(135deg, #121212 0%, #1e1e1e 100%)'
        : 'linear-gradient(135deg, #1e1212 0%, #2a1515 100%)';
    final badgeColor = isSuccess ? '#FF6B00' : '#E53935';
    final iconSvg = isSuccess
        ? '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#FF6B00" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>'
        : '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#E53935" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>';

    return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Desky - $title</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background: $bgGradient;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #FFFFFF;
    }
    .card {
      background: rgba(30, 30, 30, 0.85);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 16px;
      padding: 40px;
      max-width: 440px;
      text-align: center;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(10px);
    }
    .icon {
      margin-bottom: 20px;
    }
    h1 {
      font-size: 22px;
      margin: 0 0 12px 0;
      font-weight: 700;
    }
    p {
      font-size: 15px;
      color: #A0A0A0;
      line-height: 1.5;
      margin: 0 0 24px 0;
    }
    .brand {
      font-size: 13px;
      font-weight: 600;
      color: $badgeColor;
      text-transform: uppercase;
      letter-spacing: 1.5px;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">$iconSvg</div>
    <h1>$title</h1>
    <p>$desc</p>
    <div class="brand">Desky</div>
  </div>
</body>
</html>
''';
  }
}
