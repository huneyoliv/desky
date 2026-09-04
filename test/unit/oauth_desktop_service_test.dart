import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/oauth/oauth_desktop_service.dart';

void main() {
  group('OAuthDesktopService language resolution', () {
    test('resolves Portuguese language from Accept-Language header', () {
      expect(OAuthDesktopService.resolveLanguage('pt-BR,pt;q=0.9,en-US;q=0.8'), equals('pt'));
      expect(OAuthDesktopService.resolveLanguage('pt'), equals('pt'));
    });

    test('resolves English language from Accept-Language header', () {
      expect(OAuthDesktopService.resolveLanguage('en-US,en;q=0.5'), equals('en'));
      expect(OAuthDesktopService.resolveLanguage('en'), equals('en'));
    });

    test('resolves Spanish language from Accept-Language header', () {
      expect(OAuthDesktopService.resolveLanguage('es-ES,es;q=0.9'), equals('es'));
      expect(OAuthDesktopService.resolveLanguage('es'), equals('es'));
    });

    test('resolves Korean, Japanese and Chinese', () {
      expect(OAuthDesktopService.resolveLanguage('ko-KR,ko;q=0.9'), equals('ko'));
      expect(OAuthDesktopService.resolveLanguage('ja-JP,ja;q=0.9'), equals('ja'));
      expect(OAuthDesktopService.resolveLanguage('zh-CN,zh;q=0.9'), equals('zh'));
    });

    test('falls back to en for null, empty or unsupported language', () {
      expect(OAuthDesktopService.resolveLanguage(null), equals('en'));
      expect(OAuthDesktopService.resolveLanguage(''), equals('en'));
      expect(OAuthDesktopService.resolveLanguage('fr-FR,fr;q=0.9'), equals('en'));
    });
  });

  group('OAuthDesktopService buildResponseHtml', () {
    test('renders Portuguese success HTML with Desky brand and AMOLED colors', () {
      final html = OAuthDesktopService.buildResponseHtml(
        isSuccess: true,
        acceptLanguage: 'pt-BR',
      );

      expect(html, contains('<html lang="pt">'));
      expect(html, contains('Login realizado com sucesso!'));
      expect(html, contains('Você já pode fechar esta aba e retornar ao <strong>Desky</strong>.'));
      expect(html, contains('Conectado'));
      expect(html, contains('Fechar Janela'));
      expect(html, contains('Desky'));
      expect(html, contains('#000000'));
      expect(html, contains('#A78BFA'));
      expect(html, contains('#00E5A0'));
      expect(html, contains('navigator.languages'));
    });

    test('renders English success HTML when acceptLanguage is en-US', () {
      final html = OAuthDesktopService.buildResponseHtml(
        isSuccess: true,
        acceptLanguage: 'en-US',
      );

      expect(html, contains('<html lang="en">'));
      expect(html, contains('Login successful!'));
      expect(html, contains('You can now close this tab and return to <strong>Desky</strong>.'));
      expect(html, contains('Connected'));
      expect(html, contains('Close Window'));
    });

    test('renders Spanish success HTML when acceptLanguage is es-ES', () {
      final html = OAuthDesktopService.buildResponseHtml(
        isSuccess: true,
        acceptLanguage: 'es-ES',
      );

      expect(html, contains('<html lang="es">'));
      expect(html, contains('¡Inicio de sesión exitoso!'));
      expect(html, contains('Ya puedes cerrar esta pestaña y volver a <strong>Desky</strong>.'));
      expect(html, contains('Cerrar Ventana'));
    });

    test('renders Korean success HTML when acceptLanguage is ko-KR', () {
      final html = OAuthDesktopService.buildResponseHtml(
        isSuccess: true,
        acceptLanguage: 'ko-KR',
      );

      expect(html, contains('<html lang="ko">'));
      expect(html, contains('로그인이 완료되었습니다!'));
      expect(html, contains('창 닫기'));
    });

    test('renders error HTML with error styling and custom error message', () {
      final html = OAuthDesktopService.buildResponseHtml(
        isSuccess: false,
        error: 'Acesso recusado pelo provedor',
        acceptLanguage: 'pt-BR',
      );

      expect(html, contains('Falha na autenticação'));
      expect(html, contains('Acesso recusado pelo provedor'));
      expect(html, contains('Erro'));
      expect(html, contains('#FF5370'));
    });
  });
}
