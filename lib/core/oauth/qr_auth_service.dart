import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'oauth_exception.dart';
import 'oauth_pkce.dart';

class LanInterfaceInfo {
  final String name;
  final String ip;
  final bool isVirtual;

  const LanInterfaceInfo({
    required this.name,
    required this.ip,
    this.isVirtual = false,
  });
}

class QrAuthSession {
  final String sessionId;
  final String pairingUrl;
  final String hostIp;
  final int port;
  final List<LanInterfaceInfo> availableIps;
  final Future<String> tokenFuture;

  const QrAuthSession({
    required this.sessionId,
    required this.pairingUrl,
    required this.hostIp,
    required this.port,
    required this.availableIps,
    required this.tokenFuture,
  });

  QrAuthSession copyWithIp(String newIp) {
    return QrAuthSession(
      sessionId: sessionId,
      pairingUrl: 'http://$newIp:$port/pair?session=$sessionId',
      hostIp: newIp,
      port: port,
      availableIps: availableIps,
      tokenFuture: tokenFuture,
    );
  }
}

class QrAuthService {
  HttpServer? _server;
  Completer<String>? _completer;
  String? _activeSessionId;

  Future<List<LanInterfaceInfo>> getAvailableIpAddresses() async {
    final physical = <LanInterfaceInfo>[];
    final virtual = <LanInterfaceInfo>[];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        final nameLower = iface.name.toLowerCase();
        final isVirtual = nameLower.contains('vethernet') ||
            nameLower.contains('wsl') ||
            nameLower.contains('virtual') ||
            nameLower.contains('hyper-v') ||
            nameLower.contains('vmnet') ||
            nameLower.contains('vbox') ||
            nameLower.contains('docker') ||
            nameLower.contains('bluetooth') ||
            nameLower.contains('loopback');

        for (final address in iface.addresses) {
          final ip = address.address;
          if (!address.isLoopback &&
              !ip.startsWith('169.254.') &&
              !ip.startsWith('127.') &&
              !ip.startsWith('192.168.56.')) {
            if (!isVirtual && !ip.startsWith('172.24.')) {
              physical.add(LanInterfaceInfo(name: iface.name, ip: ip));
            } else {
              virtual.add(LanInterfaceInfo(name: '${iface.name} (Virtual)', ip: ip, isVirtual: true));
            }
          }
        }
      }
    } catch (_) {}

    final all = [...physical, ...virtual];
    if (all.isEmpty) {
      all.add(const LanInterfaceInfo(name: 'Localhost', ip: '127.0.0.1'));
    }
    return all;
  }

  Future<String> getLocalIpAddress({String? preferredIp}) async {
    if (preferredIp != null && preferredIp.isNotEmpty) {
      return preferredIp;
    }
    final available = await getAvailableIpAddresses();
    return available.first.ip;
  }

  Future<QrAuthSession> startSession({
    Duration timeout = const Duration(minutes: 5),
    String? preferredIp,
  }) async {
    await cancel();

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    } on SocketException catch (e) {
      throw OAuthException(
        'Falha ao iniciar servidor local para autenticação por QR Code: ${e.message} (código ${e.osError?.errorCode ?? -1}). Verifique as permissões de rede do aplicativo.',
      );
    }
    _server = server;

    final completer = Completer<String>();
    _completer = completer;

    final sessionId = OAuthPkce.generateState(32);
    _activeSessionId = sessionId;

    final availableIps = await getAvailableIpAddresses();
    final localIp = preferredIp ?? availableIps.first.ip;
    final port = server.port;
    final pairingUrl = 'http://$localIp:$port/pair?session=$sessionId';

    server.listen(
      (HttpRequest request) async {
        final uri = request.uri;

        if (uri.path.endsWith('favicon.ico')) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        if (request.method == 'GET' && uri.path == '/pair') {
          final reqSession = uri.queryParameters['session'];
          final isValid = reqSession == _activeSessionId && reqSession != null;

          request.response.headers.contentType =
              ContentType('text', 'html', charset: 'utf-8');
          request.response.statusCode =
              isValid ? HttpStatus.ok : HttpStatus.unauthorized;
          request.response.write(_buildMobilePairingHtml(
            isValid: isValid,
            sessionId: reqSession ?? '',
          ));
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && uri.path == '/api/pair') {
          try {
            final bodyBytes = await request.fold<List<int>>(
              <int>[],
              (prev, elem) => prev..addAll(elem),
            );
            final bodyStr = utf8.decode(bodyBytes);
            final Map<String, dynamic> body = jsonDecode(bodyStr);

            final reqSession = body['session']?.toString();
            final jwtToken = body['jwt']?.toString().trim();

            if (reqSession != _activeSessionId ||
                jwtToken == null ||
                jwtToken.isEmpty) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                's': false,
                'm': 'Sessão inválida ou token ausente.',
              }));
              await request.response.close();
              return;
            }

            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              's': true,
              'm': 'Pareamento concluído com sucesso!',
            }));
            await request.response.close();

            if (!completer.isCompleted) {
              completer.complete(jwtToken);
            }
          } catch (e) {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'s': false, 'm': e.toString()}));
            await request.response.close();
          }
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      },
      onError: (err) {
        if (!completer.isCompleted) {
          completer.completeError(OAuthException('Erro no servidor local: $err'));
        }
      },
      cancelOnError: true,
    );

    final tokenFuture = completer.future.timeout(
      timeout,
      onTimeout: () {
        cancel();
        throw const OAuthException('Tempo limite para pareamento QR Code excedido (5 minutos).');
      },
    );

    return QrAuthSession(
      sessionId: sessionId,
      pairingUrl: pairingUrl,
      hostIp: localIp,
      port: port,
      availableIps: availableIps,
      tokenFuture: tokenFuture,
    );
  }

  Future<void> cancel() async {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(
        const OAuthException('Pareamento QR Code cancelado.', isCancelled: true),
      );
    }
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
    }
    _completer = null;
    _activeSessionId = null;
  }

  String _buildMobilePairingHtml({
    required bool isValid,
    required String sessionId,
  }) {
    if (!isValid) {
      return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Desky - Sessão Inválida</title>
  <style>
    body {
      margin: 0; padding: 24px;
      display: flex; justify-content: center; align-items: center; min-height: 100vh;
      background: #121212; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #FFFFFF; text-align: center;
    }
    .card { background: #1E1E1E; border-radius: 16px; padding: 32px; max-width: 400px; border: 1px solid #333; }
    h1 { color: #E53935; font-size: 20px; margin-bottom: 12px; }
    p { color: #A0A0A0; font-size: 14px; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Sessão Expirada ou Inválida</h1>
    <p>O QR Code escaneado não é mais válido. Gere um novo QR Code no Desky.</p>
  </div>
</body>
</html>
''';
    }

    return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Desky - Conectar ao Desktop</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0; padding: 20px;
      display: flex; justify-content: center; align-items: center; min-height: 100vh;
      background: linear-gradient(135deg, #121212 0%, #1e1e1e 100%);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #FFFFFF;
    }
    .card {
      background: rgba(30, 30, 30, 0.95);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 20px;
      padding: 32px 24px;
      max-width: 440px;
      width: 100%;
      box-shadow: 0 16px 40px rgba(0,0,0,0.6);
      text-align: center;
    }
    .brand { color: #FF6B00; font-weight: 800; font-size: 13px; letter-spacing: 2px; text-transform: uppercase; margin-bottom: 8px; }
    h1 { font-size: 22px; font-weight: 700; margin: 0 0 12px 0; }
    p { font-size: 14px; color: #A0A0A0; line-height: 1.5; margin: 0 0 24px 0; }
    .input-group { text-align: left; margin-bottom: 20px; }
    label { display: block; font-size: 12px; font-weight: 600; color: #CCCCCC; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.5px; }
    textarea {
      width: 100%; height: 100px;
      background: #141414; border: 1px solid #333333; border-radius: 10px;
      color: #FFFFFF; padding: 12px; font-size: 13px; font-family: monospace;
      resize: none; outline: none; transition: border-color 0.2s;
    }
    textarea:focus { border-color: #FF6B00; }
    .btn {
      width: 100%; padding: 14px;
      background: #FF6B00; color: #FFFFFF;
      border: none; border-radius: 12px;
      font-size: 15px; font-weight: 700; cursor: pointer;
      box-shadow: 0 4px 14px rgba(255, 107, 0, 0.4);
      transition: opacity 0.2s, transform 0.1s;
    }
    .btn:active { transform: scale(0.98); }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .status { margin-top: 16px; font-size: 14px; min-height: 20px; }
    .status.success { color: #4CAF50; font-weight: 600; }
    .status.error { color: #E53935; }
    .hint-box {
      margin-top: 24px; padding: 16px;
      background: rgba(255, 107, 0, 0.08);
      border: 1px solid rgba(255, 107, 0, 0.2);
      border-radius: 12px; text-align: left;
    }
    .hint-title { font-size: 13px; font-weight: 700; color: #FF6B00; margin-bottom: 6px; }
    .hint-text { font-size: 12px; color: #CCCCCC; line-height: 1.4; margin: 0; }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">Desky Companion</div>
    <h1>Conectar ao Desktop</h1>
    <p>Cole o token de autenticação (JWT) ou exporte a sessão do aplicativo para concluir o login no seu computador.</p>

    <div class="input-group">
      <label for="jwtInput">Token JWT de Autenticação</label>
      <textarea id="jwtInput" placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI..."></textarea>
    </div>

    <button id="sendBtn" class="btn" onclick="sendToken()">Enviar para o Desky</button>
    <div id="status" class="status"></div>

    <div class="hint-box">
      <div class="hint-title">💡 Dica Rápida:</div>
      <p class="hint-text">
        Se preferir entrar diretamente no computador sem token, acesse no app oficial do celular: <strong>Configurações &rarr; Conta &rarr; Definir Senha</strong>. Depois, basta entrar com seu e-mail e a senha criada.
      </p>
    </div>
  </div>

  <script>
    async function sendToken() {
      const btn = document.getElementById('sendBtn');
      const status = document.getElementById('status');
      const token = document.getElementById('jwtInput').value.trim();

      if (!token) {
        status.className = 'status error';
        status.textContent = 'Por favor, insira o token JWT.';
        return;
      }

      btn.disabled = true;
      status.className = 'status';
      status.textContent = 'Enviando sessão para o Desky...';

      try {
        const res = await fetch('/api/pair', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            session: '$sessionId',
            jwt: token
          })
        });

        const data = await res.json();
        if (data.s) {
          status.className = 'status success';
          status.textContent = '✓ Conectado! Pode retornar ao Desky no seu computador.';
          document.getElementById('jwtInput').disabled = true;
        } else {
          status.className = 'status error';
          status.textContent = data.m || 'Falha ao conectar com o computador.';
          btn.disabled = false;
        }
      } catch (err) {
        status.className = 'status error';
        status.textContent = 'Erro de conexão com o Desky local.';
        btn.disabled = false;
      }
    }
  </script>
</body>
</html>
''';
  }
}

final qrAuthServiceProvider = Provider<QrAuthService>((ref) {
  return QrAuthService();
});
