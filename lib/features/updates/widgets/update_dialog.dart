import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/package_helper.dart';
import '../models/update_model.dart';
import '../update_notifier.dart';

class UpdateDialog extends ConsumerWidget {
  final AppRelease release;

  const UpdateDialog({
    super.key,
    required this.release,
  });

  static Future<void> show(BuildContext context, AppRelease release) {
    if (PackageHelper.isStoreOrMsix) return Future.value();
    final targetContext = rootNavigatorKey.currentContext ?? context;
    return showDialog(
      context: targetContext,
      useRootNavigator: true,
      builder: (context) => UpdateDialog(release: release),
    );
  }

  Future<void> _launchUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final updateState = ref.watch(updateNotifierProvider);
    final platformAsset = release.getAssetForPlatform(defaultTargetPlatform);
    final df = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: AppColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tr('update_available', fallback: 'Atualização Disponível'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'v${updateState.currentVersion}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textMuted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          release.cleanVersion.isNotEmpty ? 'v${release.cleanVersion}' : release.tagName,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (release.publishedAt != null) ...[
              Text(
                '${t.tr('released_on', fallback: 'Lançado em')}: ${df.format(release.publishedAt!)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              t.tr('changelog', fallback: 'Novidades & Changelog'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: release.body.isNotEmpty
                      ? release.body
                      : t.tr('no_changelog', fallback: 'Melhorias de desempenho e correções gerais.'),
                  selectable: true,
                  onTapLink: (text, href, title) {
                    if (href != null && href.isNotEmpty) {
                      _launchUrl(href);
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                    h1: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    h2: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    h3: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    strong: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    em: const TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    listBullet: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                    code: TextStyle(
                      color: AppColors.warning,
                      backgroundColor: AppColors.card,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                      border: const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      ),
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                    a: const TextStyle(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: release.htmlUrl.isNotEmpty
              ? () => _launchUrl(release.htmlUrl)
              : null,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(t.tr('view_on_github', fallback: 'Ver no GitHub')),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (platformAsset != null && platformAsset.downloadUrl.isNotEmpty) {
              _launchUrl(platformAsset.downloadUrl);
            } else if (release.htmlUrl.isNotEmpty) {
              _launchUrl(release.htmlUrl);
            }
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(
            platformAsset != null
                ? '${t.tr('download_installer', fallback: 'Baixar Instalador')} (${platformAsset.name})'
                : t.tr('download_update', fallback: 'Baixar Atualização'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}
