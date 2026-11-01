import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';

void main() {
  group('AppTranslation fallback', () {
    test('non-Portuguese locales never receive Portuguese dictionary text', () {
      const en = AppTranslation(languageCode: 'en');
      expect(en.tr('idle'), 'Inactive');
      expect(en.tr('nickname'), 'Nickname');
    });

    test('Portuguese keeps the Portuguese dictionary text', () {
      const pt = AppTranslation(languageCode: 'pt');
      expect(pt.tr('idle'), 'Inativo');
      expect(pt.tr('nickname'), 'Apelido');
    });

    test('locales without their own dictionary entry fall back to English', () {
      const fr = AppTranslation(languageCode: 'fr');
      expect(fr.tr('idle'), 'Inactive');
    });

    test('keys used by the UI resolve without the caller fallback', () {
      const keys = [
        'action_irreversible',
        'ban_member_blacklist_desc',
        'ban_member_confirm',
        'cards_in_deck',
        'from_group_q',
        'inactive',
        'join_private_group',
        'leave',
        'nickname',
        'remove_member_confirm',
        'shake',
        'studied',
      ];

      for (final code in ['pt', 'en', 'es', 'ko', 'ja', 'zh-cn', 'zh-tw']) {
        final translation = AppTranslation(languageCode: code);
        for (final key in keys) {
          expect(
            translation.tr(key, fallback: '__missing__'),
            isNot('__missing__'),
            reason: '$code/$key',
          );
        }
      }
    });
  });
}
