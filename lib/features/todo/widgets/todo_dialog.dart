import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/todo_item_model.dart';
import '../todo_notifier.dart';

/// Creates a task, or renames an existing one.
///
/// The API keeps more fields (subject, recurrence, order) that the planner
/// already manages; this dialog edits only what the standalone list exposes:
/// the title.
class TodoDialog extends ConsumerStatefulWidget {
  const TodoDialog({super.key, this.existing});

  final TodoItemModel? existing;

  static Future<void> show(BuildContext context, {TodoItemModel? existing}) {
    return showDialog(
      context: context,
      builder: (_) => TodoDialog(existing: existing),
    );
  }

  @override
  ConsumerState<TodoDialog> createState() => _TodoDialogState();
}

class _TodoDialogState extends ConsumerState<TodoDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.title ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(todoNotifierProvider.notifier);
    final existing = widget.existing;

    final ok = existing == null
        ? await notifier.add(title)
        : await notifier.rename(existing, title);

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _error = 'save_failed';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final isEditing = widget.existing != null;

    return AlertDialog(
      backgroundColor: context.appCard,
      title: Text(
        isEditing
            ? t.tr('todo_edit', fallback: 'Editar tarefa')
            : t.tr('todo_new', fallback: 'Nova tarefa'),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText:
                    t.tr('todo_input_hint', fallback: 'O que você vai fazer?'),
                labelStyle: TextStyle(color: context.appTextMuted),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                t.tr('todo_save_failed',
                    fallback: 'Could not save. Please try again.'),
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.tr('cancel', fallback: 'Cancelar'),
            style: TextStyle(color: context.appTextMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: context.appPrimary),
          child: Text(
            t.tr('save', fallback: 'Salvar'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}