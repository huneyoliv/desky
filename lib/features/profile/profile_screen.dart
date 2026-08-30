import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../auth/auth_notifier.dart';
import '../settings/settings_notifier.dart';
import '../settings/widgets/select_country_dialog.dart';
import '../settings/widgets/select_language_dialog.dart';
import '../timer/timer_notifier.dart';
import '../settings/widgets/privacy_policy_dialog.dart';
import '../settings/widgets/terms_of_service_dialog.dart';
import '../settings/widgets/faq_help_dialog.dart';
import '../settings/widgets/open_source_licenses_dialog.dart';
import '../settings/widgets/change_password_dialog.dart';
import '../settings/widgets/study_preferences_dialog.dart';
import '../settings/widgets/blocked_users_dialog.dart';
import 'widgets/delete_account_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _formatHours(int ms) {
    final mins = ms ~/ 60000;
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  void _showEditNicknameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final t = ref.read(appTranslationProvider);
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('edit_nickname', fallback: 'Alterar Apelido'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t.tr('nickname', fallback: 'Digite seu novo apelido'),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final success =
                    await ref.read(authStateProvider.notifier).updateNickname(newName);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? t.tr('success', fallback: 'Apelido alterado com sucesso!')
                            : t.tr('error', fallback: 'Falha ao alterar apelido no servidor'),
                      ),
                      backgroundColor: success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(t.tr('save', fallback: 'Salvar'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditStatusMsgDialog(BuildContext context, WidgetRef ref, String currentStatus) {
    final t = ref.read(appTranslationProvider);
    final controller = TextEditingController(text: currentStatus);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('edit_status_msg', fallback: 'Alterar Mensagem de Status'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t.tr('status_msg_hint', fallback: 'Digite sua mensagem de status...'),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStatus = controller.text.trim();
              final success =
                  await ref.read(authStateProvider.notifier).updateStatusMessage(newStatus);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? t.tr('success', fallback: 'Mensagem de status alterada!')
                          : t.tr('error', fallback: 'Falha ao atualizar status no servidor'),
                    ),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(t.tr('save', fallback: 'Salvar'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final timerState = ref.watch(timerNotifierProvider);
    final t = ref.watch(appTranslationProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${t.tr('profile', fallback: 'Perfil')} & ${t.tr('settings', fallback: 'Configurações')}', style: AppTextStyles.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  StudiconAvatar(
                    studiconId: user?.studiconId ?? -1,
                    size: 80,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?.name ?? 'Estudante YPT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                              tooltip: t.tr('edit', fallback: 'Editar Apelido'),
                              onPressed: () => _showEditNicknameDialog(
                                context,
                                ref,
                                user?.name ?? '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.statusMessage.isNotEmpty == true
                                    ? '"${user!.statusMessage}"'
                                    : t.tr('no_status_msg', fallback: 'Sem mensagem de status'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.mode_comment_outlined,
                                  size: 16, color: AppColors.textMuted),
                              tooltip: t.tr('edit', fallback: 'Editar Mensagem de Status'),
                              onPressed: () => _showEditStatusMsgDialog(
                                context,
                                ref,
                                user?.statusMessage ?? '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'contato@tgclab.com',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'ID: ${user?.id ?? 0}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.border),
                              avatar: const Icon(Icons.school, size: 14, color: AppColors.warning),
                              label: Text(
                                user?.categoryName.isNotEmpty == true
                                    ? user!.categoryName
                                    : t.tr('graduation', fallback: 'Graduação'),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              onPressed: () async {
                                final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
                                if (ref.read(settingsNotifierProvider).countryCategories.isEmpty) {
                                  await settingsNotifier.loadCategories();
                                }
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (context) => Consumer(
                                    builder: (context, ref, _) {
                                      final cats = ref.watch(settingsNotifierProvider).countryCategories;
                                      return AlertDialog(
                                        backgroundColor: AppColors.card,
                                        title: Text(
                                          t.tr('category', fallback: 'Selecionar Categoria / Objetivo'),
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        content: SizedBox(
                                          width: 420,
                                          height: 480,
                                          child: cats.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    t.tr('loading_categories', fallback: 'Carregando categorias da região...'),
                                                    style: const TextStyle(color: AppColors.textMuted),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount: cats.length,
                                                  itemBuilder: (context, idx) {
                                                    final cat = cats[idx];
                                                    final isSelected = user?.categoryId == cat.id;
                                                    final prevSection = idx > 0 ? cats[idx - 1].section : '';
                                                    final showSectionHeader = cat.section.isNotEmpty && cat.section != prevSection;
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (showSectionHeader)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 12, bottom: 4, left: 8),
                                                            child: Text(
                                                              cat.section,
                                                              style: const TextStyle(
                                                                color: AppColors.primary,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ListTile(
                                                          dense: true,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
                                                          title: Text(
                                                            cat.title,
                                                            style: TextStyle(
                                                              color: isSelected ? AppColors.primary : Colors.white,
                                                              fontSize: 14,
                                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                            ),
                                                          ),
                                                          trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 18) : null,
                                                          onTap: () async {
                                                            Navigator.of(context).pop();
                                                            final ok = await ref
                                                                .read(authStateProvider.notifier)
                                                                .updateCategory(cat.id, cat.title);
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    ok
                                                                        ? '${t.tr("category_changed_to", fallback: "Categoria alterada para")} ${cat.title}'
                                                                        : t.tr('category_change_fail', fallback: 'Falha ao atualizar categoria'),
                                                                  ),
                                                                  backgroundColor:
                                                                      ok ? AppColors.success : AppColors.error,
                                                                ),
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.timer, color: AppColors.primary, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          _formatHours(timerState.todayTotalMs),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(t.tr('today_total_study_time', fallback: 'Estudados Hoje'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.book_rounded, color: AppColors.success, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          '${timerState.subjects.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(t.tr('subjects', fallback: 'Matérias'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.groups_rounded, color: AppColors.accent, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          '${user?.userGroups.length ?? 0}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(t.tr('my_groups', fallback: 'Meus Grupos'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Settings Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${t.tr('settings', fallback: 'Configurações')} & ${t.tr('device', fallback: 'Dispositivo')}', style: AppTextStyles.titleMedium),
            ),
            const SizedBox(height: 16),

            Builder(builder: (context) {
              final settingsState = ref.watch(settingsNotifierProvider);
              final country = settingsState.selectedCountry;
              final langCode = settingsState.selectedLanguage;
              final langLabel = switch (langCode) {
                'pt' => 'Português (Brasil)',
                'en' => 'English (US)',
                'es' => 'Español',
                'ko' => '한국어 (Korean)',
                'ja' => '日本語 (Japanese)',
                'zh_hans' => '简体中文',
                'zh_hant' => '繁體中文',
                _ => langCode,
              };

              return Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.public, color: AppColors.primary),
                      title: Text(t.tr('region', fallback: 'Região / País'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${country.formattedName} (${country.code})',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () => SelectCountryDialog.show(context),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.language, color: AppColors.primary),
                      title: Text(t.tr('language', fallback: 'Idioma do Aplicativo'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        langLabel,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () => SelectLanguageDialog.show(context),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.access_time, color: AppColors.primary),
                      title: Text(t.tr('timezone', fallback: 'Fuso Horário da Região'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${country.timezone} (${country.gmtDisplay})',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.computer, color: AppColors.primary),
                      title: Text(t.tr('platform', fallback: 'Plataforma'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(t.tr('platform_value', fallback: 'Desky Desktop (Windows x64)'),
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: AppColors.primary),
                      title: Text(t.tr('version', fallback: 'Versão do Cliente API'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text('v${AppConstants.appVersion} (API v8.1.0)',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),

            // Study & Routine Preferences Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.tr('study_preferences', fallback: 'Preferências de Estudo & Rotina'),
                style: AppTextStyles.titleMedium,
              ),
            ),
            const SizedBox(height: 16),

            Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
                    title: Text(t.tr('study_preferences', fallback: 'Ajustes de Estudo e Alertas'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('study_pref_subtitle', fallback: 'Horário de reset do dia, exibição de descanso e notificações'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => StudyPreferencesDialog.show(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Account Security Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.tr('account_security', fallback: 'Segurança da Conta'),
                style: AppTextStyles.titleMedium,
              ),
            ),
            const SizedBox(height: 16),

            Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                    title: Text(t.tr('drawer_settings_reset_password_title', fallback: 'Alterar Senha'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('change_password_subtitle', fallback: 'Atualizar sua credencial de acesso'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => ChangePasswordDialog.show(context),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: AppColors.error),
                    title: Text(t.tr('drawer_settings_block_user_title', fallback: 'Usuários Bloqueados'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('blocked_users_subtitle', fallback: 'Gerenciar lista de usuários bloqueados'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => BlockedUsersDialog.show(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Legal & Support Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${t.tr('drawer_helps_title', fallback: 'Ajuda')} & ${t.tr('legal', fallback: 'Legal')}',
                style: AppTextStyles.titleMedium,
              ),
            ),
            const SizedBox(height: 16),

            Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                    title: Text(t.tr('drawer_settings_pallo_privacy_title', fallback: 'Política de Privacidade'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('privacy_subtitle', fallback: 'Como protegemos seus dados e logs de estudo'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => PrivacyPolicyDialog.show(context),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                    title: Text(t.tr('drawer_settings_pallo_terms_title', fallback: 'Termos de Uso'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('terms_subtitle', fallback: 'Condições de serviço e regras da comunidade'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => TermsOfServiceDialog.show(context),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                    title: Text('${t.tr('drawer_helps_title', fallback: 'Ajuda')} & FAQ',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('faq_subtitle', fallback: 'Dúvidas frequentes e canais de atendimento'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => FaqHelpDialog.show(context),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.code_rounded, color: AppColors.primary),
                    title: Text(t.tr('open_source_licenses', fallback: 'Licenças Open Source'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      t.tr('licenses_subtitle', fallback: 'Softwares e bibliotecas de código aberto'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => OpenSourceLicensesDialog.show(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About Desky & Legal Disclaimer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Desky v${AppConstants.appVersion} (${AppConstants.buildNumber})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.tr('legal_disclaimer', fallback: 'O Desky é um cliente de terceiros independente e de código aberto, não sendo afiliado, endossado, patrocinado ou associado à Pallo Inc. ou ao Yeolpumta (YPT). Todas as marcas registradas pertencem aos seus respectivos proprietários.'),
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Danger Zone Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.tr('danger_zone', fallback: 'Zona de Perigo'),
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: Text(
                  t.tr('delete_account', fallback: 'Excluir Minha Conta'),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  t.tr('delete_account_desc', fallback: 'Apagar permanentemente seus dados, histórico e desvincular grupos'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.error),
                onTap: () => DeleteAccountDialog.show(context),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
