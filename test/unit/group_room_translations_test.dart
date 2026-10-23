import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';

void main() {
  group('Group Room and Theme Translation Fallbacks Tests', () {
    test('resolves room tabs and header in English and Portuguese', () {
      final tEn = AppTranslation(languageCode: 'en');
      final tPt = AppTranslation(languageCode: 'pt');

      expect(tEn.tr('studying_now'), equals('Studying Now'));
      expect(tPt.tr('studying_now'), equals('Estudando Agora'));

      expect(tEn.tr('group_chat'), equals('Group Chat'));
      expect(tPt.tr('group_chat'), equals('Chat do Grupo'));

      expect(tEn.tr('weekly_ranking'), equals('Leaderboard'));
      expect(tPt.tr('weekly_ranking'), equals('Ranking Semanal'));

      expect(tEn.tr('resting_inactive'), equals('Resting / Inactive'));
      expect(tPt.tr('resting_inactive'), equals('Descansando / Inativos'));

      expect(tEn.tr('group_rank_total_time'), equals('Total time'));
      expect(tPt.tr('group_rank_total_time'), equals('Tempo Total'));

      expect(tEn.tr('day'), equals('day'));
      expect(tPt.tr('day'), equals('dia'));
    });

    test('resting does not resolve to Break (study_rest_label decoupled)', () {
      final tEn = AppTranslation(languageCode: 'en');
      expect(tEn.tr('resting'), isNot(equals('Break')));
      expect(tEn.tr('resting'), anyOf(equals('Resting'), equals('Rest')));
    });

    test('goal does not resolve to Total time', () {
      final tEn = AppTranslation(languageCode: 'en');
      expect(tEn.tr('goal'), isNot(equals('Total time')));
    });

    test('resolves chat action keys in English and Portuguese', () {
      final tEn = AppTranslation(languageCode: 'en');
      final tPt = AppTranslation(languageCode: 'pt');

      expect(tEn.tr('attach_image'), equals('Attach Image'));
      expect(tPt.tr('attach_image'), equals('Anexar Imagem'));

      expect(tEn.tr('stickers'), equals('Stickers'));
      expect(tPt.tr('stickers'), equals('Figurinhas'));

      expect(tEn.tr('type_message'), equals('Type a message...'));
      expect(tPt.tr('type_message'), equals('Digite sua mensagem...'));

      expect(tEn.tr('no_records'), equals('No records found for this period.'));
      expect(tPt.tr('no_records'), equals('Nenhum registro encontrado para este período.'));
    });

    test('resolves theme keys across languages', () {
      final tEn = AppTranslation(languageCode: 'en');
      final tPt = AppTranslation(languageCode: 'pt');
      final tEs = AppTranslation(languageCode: 'es');
      final tKo = AppTranslation(languageCode: 'ko');
      final tJa = AppTranslation(languageCode: 'ja');
      final tZh = AppTranslation(languageCode: 'zh-cn');

      expect(tEn.tr('theme_appearance'), equals('Appearance & Theme'));
      expect(tPt.tr('theme_appearance'), equals('Aparência & Tema'));

      expect(tEn.tr('theme_amoled_lilac'), contains('AMOLED Lilac'));
      expect(tPt.tr('theme_amoled_lilac'), contains('AMOLED Lilás'));

      expect(tEn.tr('theme_midnight_navy'), equals('Midnight Navy'));
      expect(tPt.tr('theme_midnight_navy'), equals('Azul Meia-Noite'));

      expect(tEs.tr('theme_cyberpunk'), equals('Cyberpunk Neón'));
      expect(tKo.tr('theme_forest_emerald'), equals('포레스트 에메랄드'));
      expect(tJa.tr('theme_sunset_amber'), equals('サンセット アンバー'));
      expect(tZh.tr('theme_active_badge'), equals('已应用'));
    });
  });
}
