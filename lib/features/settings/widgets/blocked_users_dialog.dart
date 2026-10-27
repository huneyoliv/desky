import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_translation.dart';
import '../settings_notifier.dart';

class BlockedUsersDialog extends ConsumerStatefulWidget {
  const BlockedUsersDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const BlockedUsersDialog(),
    );
  }

  @override
  ConsumerState<BlockedUsersDialog> createState() => _BlockedUsersDialogState();
}

class _BlockedUsersDialogState extends ConsumerState<BlockedUsersDialog> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block_rounded, color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.tr('drawer_settings_block_user_title', fallback: 'Usuários Bloqueados'),
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

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: t.tr('block_user_hint', fallback: 'Bloquear apelido de usuário...'),
                      hintStyle: TextStyle(color: context.appTextMuted),
                      filled: true,
                      fillColor: context.appSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _addController.text.trim();
                    if (text.isNotEmpty) {
                      notifier.blockUser(text);
                      _addController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(t.tr('block', fallback: 'Bloquear'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (settings.blockedUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.sentiment_satisfied_rounded, size: 40, color: context.appTextMuted),
                      const SizedBox(height: 12),
                      Text(
                        t.tr('drawer_settings_block_user_empty_msg', fallback: 'Você não tem nenhum usuário bloqueado.'),
                        style: TextStyle(color: context.appTextSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: settings.blockedUsers.length,
                  separatorBuilder: (_, __) => Divider(color: context.appBorder, height: 1),
                  itemBuilder: (context, index) {
                    final user = settings.blockedUsers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: context.appSurface,
                        child: Icon(Icons.person_off_rounded, size: 18, color: AppColors.error),
                      ),
                      title: Text(user, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: TextButton(
                        onPressed: () => notifier.unblockUser(user),
                        child: Text(t.tr('unblock', fallback: 'Desbloquear'), style: TextStyle(color: context.appPrimary)),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.tr('close_btn', fallback: 'Fechar'), style: TextStyle(color: context.appTextMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
