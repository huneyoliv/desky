import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';
import '../settings_notifier.dart';

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

class SelectLanguageDialog extends ConsumerWidget {
  const SelectLanguageDialog({super.key});

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(code: 'pt', name: 'Português', nativeName: 'Português (Brasil)', flag: '🇧🇷'),
    LanguageOption(code: 'en', name: 'English', nativeName: 'English (US)', flag: '🇺🇸'),
    LanguageOption(code: 'es', name: 'Español', nativeName: 'Español', flag: '🇪🇸'),
    LanguageOption(code: 'ko', name: 'Coreano', nativeName: '한국어', flag: '🇰🇷'),
    LanguageOption(code: 'ja', name: 'Japonês', nativeName: '日本語', flag: '🇯🇵'),
    LanguageOption(code: 'zh_hans', name: 'Chinês Simplificado', nativeName: '简体中文', flag: '🇨🇳'),
    LanguageOption(code: 'zh_hant', name: 'Chinês Tradicional', nativeName: '繁體中文', flag: '🇹🇼'),
  ];

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SelectLanguageDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsNotifierProvider);
    final t = ref.watch(appTranslationProvider);
    final currentLang = settingsState.selectedLanguage;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        t.tr('select_language', fallback: 'Selecionar Idioma'),
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 380,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: supportedLanguages.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
          itemBuilder: (context, index) {
            final lang = supportedLanguages[index];
            final isSelected = lang.code == currentLang;

            return ListTile(
              leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
              title: Text(
                lang.name,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryLight : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                lang.nativeName,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                  : null,
              onTap: () async {
                final nav = Navigator.of(context);
                await ref.read(settingsNotifierProvider.notifier).selectLanguage(lang.code);
                await ref.read(appTranslationProvider.notifier).loadLanguage(lang.code);
                nav.pop();
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.tr('close', fallback: 'Fechar'), style: const TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }
}
