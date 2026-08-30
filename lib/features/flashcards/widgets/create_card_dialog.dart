import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';

class CreateCardDialog extends ConsumerStatefulWidget {
  final void Function(String front, String back, String? hint) onSave;

  const CreateCardDialog({super.key, required this.onSave});

  static Future<void> show(
    BuildContext context, {
    required void Function(String front, String back, String? hint) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CreateCardDialog(onSave: onSave),
    );
  }

  @override
  ConsumerState<CreateCardDialog> createState() => _CreateCardDialogState();
}

class _CreateCardDialogState extends ConsumerState<CreateCardDialog> {
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _hintController = TextEditingController();

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(t.tr('new_flashcard', fallback: 'Novo Flashcard'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _frontController,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t.tr('card_front', fallback: 'Frente (Pergunta ou Termo)'),
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: t.tr('card_front_hint', fallback: 'Ex: Qual a fórmula da energia cinética?'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _backController,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t.tr('card_back', fallback: 'Verso (Resposta ou Definição)'),
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: t.tr('card_back_hint', fallback: 'Ex: Ec = (m * v²) / 2'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hintController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t.tr('hint_optional', fallback: 'Dica (opcional)'),
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: t.tr('hint_example', fallback: 'Ex: Depende da massa e velocidade'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final front = _frontController.text.trim();
            final back = _backController.text.trim();
            if (front.isNotEmpty && back.isNotEmpty) {
              widget.onSave(front, back, _hintController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(t.tr('add', fallback: 'Adicionar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
