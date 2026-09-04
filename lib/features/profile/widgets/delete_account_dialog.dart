import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';
import '../../auth/auth_notifier.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _confirmationController = TextEditingController();
  bool _isConsentChecked = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  bool _canDelete(String requiredPhrase) {
    final input = _confirmationController.text.trim().toLowerCase();
    return _isConsentChecked &&
        (input == requiredPhrase.toLowerCase() ||
            input == 'delete' ||
            input == 'excluir minha conta');
  }

  Future<void> _handleDeleteAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success =
        await ref.read(authStateProvider.notifier).deleteAccount();

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = ref.read(authStateProvider).errorMessage ??
              'Falha ao excluir a conta. Verifique sua conexão.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final requiredPhrase = t.tr('delete_confirm_phrase', fallback: 'delete');

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 10),
          Text(
            t.tr('delete_account_title', fallback: 'Excluir Conta'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('delete_account_warning_intro', fallback: 'Esta ação é permanente e irreversível. Ao excluir sua conta:'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),

              _buildBullet(
                icon: Icons.delete_forever_outlined,
                text: t.tr('delete_account_warning_1', fallback: 'Todos os seus registros de estudo, matérias, metas e histórico de tempo serão permanentemente apagados.'),
              ),
              const SizedBox(height: 12),
              _buildBullet(
                icon: Icons.group_off_outlined,
                text: t.tr('delete_account_warning_2', fallback: 'Você será removido de todos os grupos de estudo, desafios e rankings comunitários.'),
              ),
              const SizedBox(height: 12),
              _buildBullet(
                icon: Icons.person_off_outlined,
                text: t.tr('delete_account_warning_3', fallback: 'Todos os avatares adquiridos, itens e conquistas serão perdidos sem reembolso.'),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Consent Checkbox
              InkWell(
                onTap: () {
                  setState(() => _isConsentChecked = !_isConsentChecked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _isConsentChecked,
                        activeColor: AppColors.error,
                        onChanged: (val) {
                          setState(() => _isConsentChecked = val ?? false);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.tr('delete_account_consent', fallback: 'Compreendo as consequências e confirmo que desejo excluir minha conta de forma permanente.'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirmation Phrase Input
              Text(
                '${t.tr("type_to_confirm", fallback: "Digite exatamente")} "$requiredPhrase" ${t.tr("to_confirm", fallback: "para confirmar:")}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: requiredPhrase,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            t.tr('cancel', fallback: 'Cancelar'),
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _canDelete(requiredPhrase) && !_isLoading ? _handleDeleteAccount : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  t.tr('delete_account', fallback: 'Excluir Conta Definitivamente'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildBullet({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
