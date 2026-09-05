import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'oauth_exception.dart';

class OAuthDesktopService {
  HttpServer? _server;
  Completer<Map<String, String>>? _completer;

  static const Map<String, Map<String, String>> _i18n = {
    'pt': {
      'success_title': 'Login realizado com sucesso!',
      'success_desc': 'Você já pode fechar esta aba e retornar ao <strong>Desky</strong>.',
      'success_badge': 'Conectado',
      'error_title': 'Falha na autenticação',
      'error_desc': 'Ocorreu um erro durante a autenticação. Retorne ao <strong>Desky</strong> para tentar novamente.',
      'error_badge': 'Erro',
      'btn_close': 'Fechar Janela',
      'brand_tagline': 'Sua área de estudos produtiva',
    },
    'en': {
      'success_title': 'Login successful!',
      'success_desc': 'You can now close this tab and return to <strong>Desky</strong>.',
      'success_badge': 'Connected',
      'error_title': 'Authentication failed',
      'error_desc': 'An error occurred during authentication. Return to <strong>Desky</strong> to try again.',
      'error_badge': 'Error',
      'btn_close': 'Close Window',
      'brand_tagline': 'Your productive study space',
    },
    'es': {
      'success_title': '¡Inicio de sesión exitoso!',
      'success_desc': 'Ya puedes cerrar esta pestaña y volver a <strong>Desky</strong>.',
      'success_badge': 'Conectado',
      'error_title': 'Error de autenticación',
      'error_desc': 'Ocurrió un error durante la autenticación. Vuelve a <strong>Desky</strong> para intentarlo de nuevo.',
      'error_badge': 'Error',
      'btn_close': 'Cerrar Ventana',
      'brand_tagline': 'Tu espacio de estudio productivo',
    },
    'ko': {
      'success_title': '로그인이 완료되었습니다!',
      'success_desc': '이 탭을 닫고 <strong>Desky</strong>로 돌아가셔도 좋습니다.',
      'success_badge': '연결됨',
      'error_title': '인증 실패',
      'error_desc': '인증 중 오류가 발생했습니다. <strong>Desky</strong>로 돌아가 다시 시도해 주세요.',
      'error_badge': '오류',
      'btn_close': '창 닫기',
      'brand_tagline': '당신의 스마트한 학습 공간',
    },
    'ja': {
      'success_title': 'ログインが完了しました！',
      'success_desc': 'このタブを閉じて<strong>Desky</strong>に戻ることができます。',
      'success_badge': '接続完了',
      'error_title': '認証に失敗しました',
      'error_desc': '認証中にエラーが発生しました。<strong>Desky</strong>に戻ってやり直してください。',
      'error_badge': 'エラー',
      'btn_close': 'ウィンドウを閉じる',
      'brand_tagline': 'あなたの集中学習スペース',
    },
    'zh': {
      'success_title': '登录成功！',
      'success_desc': '您现在可以关闭此标签页并返回 <strong>Desky</strong>。',
      'success_badge': '已连接',
      'error_title': '认证失败',
      'error_desc': '认证过程中发生错误。请返回 <strong>Desky</strong> 重试。',
      'error_badge': '错误',
      'btn_close': '关闭窗口',
      'brand_tagline': '你的高效自习空间',
    },
  };

  static String resolveLanguage(String? acceptLanguage) {
    if (acceptLanguage == null || acceptLanguage.trim().isEmpty) return 'en';
    final lower = acceptLanguage.toLowerCase();
    final tags = lower.split(',').map((e) => e.split(';').first.trim());
    for (final tag in tags) {
      final prefix = tag.split('-').first.trim();
      if (_i18n.containsKey(prefix)) {
        return prefix;
      }
    }
    return 'en';
  }

  Future<Map<String, String>> startAuthFlow({
    required Uri Function(int port) authUrlBuilder,
    String? expectedState,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    await cancel();

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } on SocketException catch (e) {
      throw OAuthException(
        'Falha ao iniciar porta de redirecionamento local para autenticação: ${e.message} (código ${e.osError?.errorCode ?? -1}). Verifique as permissões de rede do aplicativo.',
      );
    }
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

        final acceptLanguage = request.headers.value('accept-language');
        final html = buildResponseHtml(
          isSuccess: isSuccess,
          error: error ??
              (expectedState != null && state != expectedState
                  ? 'State mismatch (CSRF protection)'
                  : null),
          acceptLanguage: acceptLanguage,
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

  static String buildResponseHtml({
    required bool isSuccess,
    String? error,
    String? acceptLanguage,
  }) {
    final lang = resolveLanguage(acceptLanguage);
    final dict = _i18n[lang] ?? _i18n['en']!;

    final title = isSuccess ? dict['success_title']! : dict['error_title']!;
    final desc = isSuccess
        ? dict['success_desc']!
        : (error ?? dict['error_desc']!);
    final badge = isSuccess ? dict['success_badge']! : dict['error_badge']!;
    final btnClose = dict['btn_close']!;
    final brandTagline = dict['brand_tagline']!;
    final serializedI18n = jsonEncode(_i18n);

    final statusClass = isSuccess ? 'success' : 'error';
    final accentGlow = isSuccess
        ? 'rgba(0, 229, 160, 0.15)'
        : 'rgba(255, 83, 112, 0.15)';
    final accentBorder = isSuccess
        ? 'rgba(0, 229, 160, 0.35)'
        : 'rgba(255, 83, 112, 0.35)';

    final statusIcon = isSuccess
        ? '''<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#00E5A0" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>'''
        : '''<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#FF5370" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="15" y1="9" x2="9" y2="15"></line>
            <line x1="9" y1="9" x2="15" y2="15"></line>
          </svg>''';

    return '''<!DOCTYPE html>
<html lang="$lang">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Desky - $title</title>
  <style>
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      background-color: #000000;
      background-image: 
        radial-gradient(circle at 50% 25%, $accentGlow 0%, transparent 60%),
        radial-gradient(circle at 50% 85%, rgba(167, 139, 250, 0.08) 0%, transparent 50%);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Inter", "Helvetica Neue", Arial, sans-serif;
      color: #F5F3FF;
      padding: 20px;
      overflow-x: hidden;
    }
    .card {
      position: relative;
      background: rgba(13, 13, 20, 0.85);
      border: 1px solid rgba(167, 139, 250, 0.22);
      border-radius: 24px;
      padding: 44px 36px 36px;
      max-width: 460px;
      width: 100%;
      text-align: center;
      box-shadow: 
        0 24px 60px rgba(0, 0, 0, 0.75),
        0 0 35px rgba(167, 139, 250, 0.08);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(12px) scale(0.98); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    .brand-header {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      margin-bottom: 28px;
    }
    .brand-title {
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 3px;
      text-transform: uppercase;
      background: linear-gradient(135deg, #CFD3F0 0%, #A78BFA 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .status-icon-wrapper {
      position: relative;
      width: 76px;
      height: 76px;
      margin: 0 auto 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      border: 1px solid $accentBorder;
    }
    .status-icon-wrapper.success {
      background: radial-gradient(circle, rgba(0, 229, 160, 0.22) 0%, rgba(0, 229, 160, 0.05) 75%);
      box-shadow: 0 0 25px rgba(0, 229, 160, 0.3);
    }
    .status-icon-wrapper.error {
      background: radial-gradient(circle, rgba(255, 83, 112, 0.22) 0%, rgba(255, 83, 112, 0.05) 75%);
      box-shadow: 0 0 25px rgba(255, 83, 112, 0.3);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      padding: 4px 12px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 1px;
      text-transform: uppercase;
      margin-bottom: 14px;
    }
    .badge.success {
      background: rgba(0, 229, 160, 0.12);
      color: #00E5A0;
      border: 1px solid rgba(0, 229, 160, 0.3);
    }
    .badge.error {
      background: rgba(255, 83, 112, 0.12);
      color: #FF5370;
      border: 1px solid rgba(255, 83, 112, 0.3);
    }
    h1 {
      font-size: 22px;
      font-weight: 700;
      color: #F5F3FF;
      margin: 0 0 10px 0;
      line-height: 1.3;
    }
    p.desc {
      font-size: 14px;
      color: #A89FBD;
      line-height: 1.6;
      margin: 0 0 28px 0;
    }
    p.desc strong {
      color: #F5F3FF;
      font-weight: 600;
    }
    .action-btn {
      width: 100%;
      background: linear-gradient(135deg, rgba(167, 139, 250, 0.18) 0%, rgba(109, 76, 167, 0.22) 100%);
      border: 1px solid rgba(167, 139, 250, 0.4);
      color: #F5F3FF;
      padding: 13px 20px;
      border-radius: 14px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      outline: none;
    }
    .action-btn:hover {
      background: linear-gradient(135deg, rgba(167, 139, 250, 0.32) 0%, rgba(109, 76, 167, 0.36) 100%);
      border-color: #A78BFA;
      box-shadow: 0 8px 24px rgba(167, 139, 250, 0.28);
      transform: translateY(-1px);
    }
    .action-btn:active {
      transform: translateY(0);
    }
    .footer-text {
      margin-top: 22px;
      font-size: 12px;
      color: #685F7D;
      letter-spacing: 0.3px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand-header">
      <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="url(#deskyGrad)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <defs>
          <linearGradient id="deskyGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#CFD3F0" />
            <stop offset="100%" stop-color="#A78BFA" />
          </linearGradient>
        </defs>
        <path d="M5 22h14"></path>
        <path d="M5 2h14"></path>
        <path d="M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22"></path>
        <path d="M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2"></path>
      </svg>
      <span class="brand-title">Desky</span>
    </div>

    <div class="status-icon-wrapper $statusClass">
      $statusIcon
    </div>

    <div>
      <span id="badge" class="badge $statusClass">$badge</span>
      <h1 id="heading">$title</h1>
      <p id="desc" class="desc" ${error != null ? 'data-custom-error="true"' : ''}>$desc</p>
    </div>

    <button id="close-btn" class="action-btn" onclick="window.close()">$btnClose</button>
    <div id="tagline" class="footer-text">$brandTagline</div>
  </div>

  <script>
    (function() {
      try {
        const i18n = $serializedI18n;
        const isSuccess = $isSuccess;
        const navLangs = navigator.languages || [navigator.language || ''];
        for (let i = 0; i < navLangs.length; i++) {
          const raw = (navLangs[i] || '').toLowerCase();
          const code = raw.split('-')[0];
          if (i18n[code]) {
            const dict = i18n[code];
            document.documentElement.lang = code;
            document.title = 'Desky - ' + (isSuccess ? dict.success_title : dict.error_title);
            const heading = document.getElementById('heading');
            if (heading) heading.textContent = isSuccess ? dict.success_title : dict.error_title;
            const desc = document.getElementById('desc');
            if (desc && !desc.getAttribute('data-custom-error')) {
              desc.innerHTML = isSuccess ? dict.success_desc : dict.error_desc;
            }
            const badge = document.getElementById('badge');
            if (badge) badge.textContent = isSuccess ? dict.success_badge : dict.error_badge;
            const btn = document.getElementById('close-btn');
            if (btn) btn.textContent = dict.btn_close;
            const tagline = document.getElementById('tagline');
            if (tagline) tagline.textContent = dict.brand_tagline;
            break;
          }
        }
      } catch (e) {}
    })();
  </script>
</body>
</html>
''';
  }
}
