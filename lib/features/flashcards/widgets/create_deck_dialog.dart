import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';

class CreateDeckDialog extends ConsumerStatefulWidget {
  final void Function(String title, int colorInt, String? description) onSave;

  const CreateDeckDialog({super.key, required this.onSave});

  static Future<void> show(
    BuildContext context, {
    required void Function(String title, int colorInt, String? description) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CreateDeckDialog(onSave: onSave),
    );
  }

  @override
  ConsumerState<CreateDeckDialog> createState() => _CreateDeckDialogState();
}

class _CreateDeckDialogState extends ConsumerState<CreateDeckDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _selectedColor = 4292557552;

  static const List<int> _colorOptions = [
    4292557552, // Teal
    4294924032, // Coral/Orange
    4281775359, // Purple
    4280549375, // Blue
    4282827050, // Green
    4294947910, // Pink
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(t.tr('new_deck', fallback: 'Novo Baralho de Flashcards'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: t.tr('deck_title', fallback: 'Título do Baralho'),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: t.tr('deck_title_hint', fallback: 'Ex: Vocabulário em Inglês'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: t.tr('description_optional', fallback: 'Descrição (opcional)'),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: t.tr('deck_desc_hint', fallback: 'Ex: Palavras mais frequentes'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            Text(t.tr('deck_color', fallback: 'Cor do Baralho:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _colorOptions.map((c) {
                final isSelected = _selectedColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isNotEmpty) {
              widget.onSave(title, _selectedColor, _descController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(t.tr('create', fallback: 'Criar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
