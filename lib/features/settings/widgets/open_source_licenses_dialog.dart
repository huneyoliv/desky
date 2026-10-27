import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';

class OpenSourceLicensesDialog extends ConsumerWidget {
  const OpenSourceLicensesDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const OpenSourceLicensesDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);

    final packages = [
      {'name': 'Flutter SDK', 'license': 'BSD-3-Clause', 'desc': 'Google Inc.'},
      {'name': 'flutter_riverpod', 'license': 'MIT License', 'desc': 'Remi Rousselet'},
      {'name': 'dio', 'license': 'MIT License', 'desc': 'FlutterChina / CFug'},
      {'name': 'shared_preferences', 'license': 'BSD-3-Clause', 'desc': 'Flutter Community'},
      {'name': 'window_manager', 'license': 'MIT License', 'desc': 'LeanFlutter'},
      {'name': 'google_fonts', 'license': 'Apache-2.0', 'desc': 'Material Design Authors'},
      {'name': 'intl', 'license': 'BSD-3-Clause', 'desc': 'Dart Team'},
      {'name': 'camera', 'license': 'BSD-3-Clause', 'desc': 'Flutter Authors'},
      {'name': 'path_provider', 'license': 'BSD-3-Clause', 'desc': 'Flutter Authors'},
    ];

    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code_rounded, color: context.appPrimary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('open_source_licenses', fallback: 'Licenças de Código Aberto'),
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.appTextMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(color: context.appBorder, height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: packages.length,
                separatorBuilder: (_, __) => Divider(color: context.appBorder, height: 1),
                itemBuilder: (context, index) {
                  final pkg = packages[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    title: Text(pkg['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text('${pkg['desc']} • ${pkg['license']}', style: TextStyle(color: context.appTextSecondary, fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Text(pkg['license']!, style: TextStyle(color: context.appTextMuted, fontSize: 11)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(t.tr('close_btn', fallback: 'Fechar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
