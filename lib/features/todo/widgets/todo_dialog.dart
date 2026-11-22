import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/todo_item_model.dart';
import '../../timer/timer_notifier.dart';
import '../todo_notifier.dart';

/// Creates a task or edits its title and explicit subject association.
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
  static const int _noSubject = -1;

  late final TextEditingController _controller;
  late int _selectedSubjectId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.title ?? '');
    _selectedSubjectId = widget.existing?.subjectId ?? _noSubject;
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
    final subjectId =
        _selectedSubjectId == _noSubject ? null : _selectedSubjectId;

    final ok = existing == null
        ? await notifier.add(title, subjectId: subjectId)
        : await notifier.rename(
            existing,
            title,
            subjectId: subjectId,
            updateSubject: true,
          );

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
    final subjects = ref.watch(
      timerNotifierProvider.select((state) => state.subjects),
    );
    final items = <DropdownMenuItem<int>>[
      DropdownMenuItem<int>(
        value: _noSubject,
        child: Text(t.tr('todo_no_subject', fallback: 'Sem matéria')),
      ),
      for (final subject in subjects)
        if (!subject.isArchived)
          DropdownMenuItem<int>(
            value: subject.id,
            child: Text(
              subject.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
    ];

    // Preserve an association whose subject was not returned by the current
    // subject list, without crashing DropdownButton or silently changing it.
    final existingId = widget.existing?.subjectId;
    if (existingId != null && items.every((item) => item.value != existingId)) {
      final fallbackTitle = widget.existing?.subjectTitle.trim() ?? '';
      items.add(
        DropdownMenuItem<int>(
          value: existingId,
          child: Text(
            fallbackTitle.isEmpty || fallbackTitle == 'Geral'
                ? '${t.tr('todo_subject', fallback: 'Matéria')} $existingId'
                : fallbackTitle,
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: context.appCard,
      title: Text(
        isEditing
            ? t.tr('todo_edit', fallback: 'Editar tarefa')
            : t.tr('todo_new', fallback: 'Nova tarefa'),
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedSubjectId,
              isExpanded: true,
              dropdownColor: context.appCard,
              decoration: InputDecoration(
                labelText: t.tr('todo_subject', fallback: 'Matéria'),
                labelStyle: TextStyle(color: context.appTextMuted),
              ),
              items: items,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedSubjectId = value);
                      }
                    },
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
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
