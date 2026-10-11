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

    test('resolves ranks and profile UI keys in English and Portuguese', () {
      final tEn = AppTranslation(languageCode: 'en');
      expect(tEn.tr('stats'), equals('Stats & 24h Map'));
      expect(tEn.tr('subject_distribution'), equals('Subject Distribution'));
      expect(tEn.tr('no_status_msg'), equals('No status message.'));
      expect(tEn.tr('device'), equals('Device'));
      expect(tEn.tr('no_data'), equals('No study data recorded this week.'));
      expect(tEn.tr('no_ranks'), equals('No rankings available at the moment.'));
      expect(tEn.tr('graduation'), equals('College / University'));

      final tPt = AppTranslation(languageCode: 'pt');
      expect(tPt.tr('stats'), equals('Estatísticas & Mapa 24h'));
      expect(tPt.tr('subject_distribution'), equals('Distribuição por Matéria'));
      expect(tPt.tr('no_status_msg'), equals('Sem status.'));
      expect(tPt.tr('device'), equals('Dispositivo'));
      expect(tPt.tr('no_data'), equals('Nenhum dado registrado esta semana.'));
      expect(tPt.tr('no_ranks'), equals('Nenhum ranking disponível no momento.'));
      expect(tPt.tr('graduation'), equals('Graduação'));
    });

    test('resolves no_status_msg via alias when loaded from translation map', () {
      final translation = AppTranslation(
        languageCode: 'en',
        translations: {
          'status_dialog_no_status_msg': 'No status message from json.',
        },
      );
      expect(translation.tr('no_status_msg'), equals('No status message from json.'));
    });
  });
}
