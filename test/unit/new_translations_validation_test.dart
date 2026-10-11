import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';

void main() {
  group('New Translations & All 28 Locales Validation Tests', () {
    const newKeys = [
      'notifications_center',
      'no_recent_notifications',
      'reset',
      'frame',
      'initial_subject',
      'sessions_synced_success',
      'sessions_sync_failed',
      'no_pending_sessions',
    ];

    test('All 28 translation json files contain newly added keys', () {
      final dir = Directory('assets/translations');
      expect(dir.existsSync(), isTrue);

      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
      expect(files.length, equals(28));

      for (final file in files) {
        final content = file.readAsStringSync();
        final Map<String, dynamic> data = json.decode(content);
        for (final key in newKeys) {
          expect(data.containsKey(key), isTrue,
              reason: 'File ${file.path} is missing key "$key"');
          expect(data[key].toString().trim().isNotEmpty, isTrue,
              reason: 'File ${file.path} has empty translation for "$key"');
        }
      }
    });

    test('AppTranslation fallback translations resolve for new keys across core languages', () {
      for (final lang in ['pt', 'en', 'es', 'ja', 'ko', 'zh-cn', 'fr', 'de', 'it', 'ru']) {
        final t = AppTranslation(languageCode: lang);
        for (final key in newKeys) {
          final resolved = t.tr(key);
          expect(resolved, isNot(equals(key)),
              reason: 'Key "$key" should be translated for lang "$lang"');
          expect(resolved.isNotEmpty, isTrue);
        }
      }
    });

    test('AppTranslation tr replaces placeholder arguments for formatted messages', () {
      final tPt = AppTranslation(languageCode: 'pt');
      final syncSuccessPt = tPt.tr('sessions_synced_success', args: ['5']);
      expect(syncSuccessPt, contains('5 sessões sincronizadas com sucesso!'));

      final syncFailedPt = tPt.tr('sessions_sync_failed', args: ['3', '2']);
      expect(syncFailedPt, contains('3 sincronizadas, 2 falharam.'));

      final tEn = AppTranslation(languageCode: 'en');
      final syncSuccessEn = tEn.tr('sessions_synced_success', args: ['5']);
      expect(syncSuccessEn, contains('5 sessions synced successfully!'));

      final syncFailedEn = tEn.tr('sessions_sync_failed', args: ['3', '2']);
      expect(syncFailedEn, contains('3 synced, 2 failed.'));
    });
  });
}
