import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';

void main() {
  group('AppTranslation Tests', () {
    test('tr returns exact match or alias or fallback', () {
      final translation = AppTranslation(
        languageCode: 'pt',
        translations: {
          'study_time_title': 'Tempo de Estudo',
          'save': 'Salvar',
        },
      );

      // Direct match
      expect(translation.tr('study_time_title'), equals('Tempo de Estudo'));

      // Alias match: 'home' points to 'study_time_title'
      expect(translation.tr('home'), equals('Tempo de Estudo'));

      // Direct match on common key
      expect(translation.tr('save'), equals('Salvar'));

      // Fallback
      expect(translation.tr('unknown_key', fallback: 'Texto Padrão'), equals('Texto Padrão'));
    });

    test('supports language codes pt, en, es, ko, zh, ja', () {
      for (final code in ['pt', 'en', 'es', 'ko', 'zh', 'ja']) {
        final t = AppTranslation(languageCode: code);
        expect(t.languageCode, equals(code));
      }
    });
  });
}
