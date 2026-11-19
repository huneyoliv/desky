import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/todo_model.dart';
import '../todo_notifier.dart';

/// Create or edit a task. The time is optional, so a plain reminder and a
/// scheduled task use the same dialog.
class TodoDialog extends ConsumerStatefulWidget {
  const TodoDialog({super.key, required this.day, this.existing});

  final String day;
  final TodoModel? existing;

  static Future<void> show(
    BuildContext context, {
    required String day,
    TodoModel? existing,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TodoDialog(day: day, existing: existing),
    );
  }

  @override
  ConsumerState<TodoDialog> createState() => _TodoDialogState();
}

class _TodoDialogState extends ConsumerState<TodoDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    final minute = existing?.startMinute;
    if (minute != null) {
      _time = TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    final notifier = ref.read(todoNotifierProvider.notifier);
    final minute = _time == null ? null : _time!.hour * 60 + _time!.minute;

    final existing = widget.existing;
    if (existing == null) {
      await notifier.add(
        title: title,
        note: _noteController.text,
        day: widget.day,
        startMinute: minute,
      );
    } else {
      await notifier.update(
        id: existing.id,
        title: title,
        note: _noteController.text,
        startMinute: minute,
        clearStartMinute: minute == null,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
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
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: t.tr('todo_input_hint', fallback: 'O que você vai fazer?'),
                labelStyle: TextStyle(color: context.appTextMuted),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: t.tr('todo_note', fallback: 'Observação (opcional)'),
                labelStyle: TextStyle(color: context.appTextMuted),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  t.tr('todo_start_time', fallback: 'Horário de início'),
                  style: TextStyle(color: context.appTextSecondary, fontSize: 13),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: Icon(Icons.schedule, size: 18, color: context.appPrimary),
                  label: Text(
                    _time == null
                        ? t.tr('todo_time_none', fallback: 'Sem horário')
                        : _time!.format(context),
                    style: TextStyle(color: context.appPrimary),
                  ),
                ),
                if (_time != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: context.appTextMuted),
                    onPressed: () => setState(() => _time = null),
                  ),
              ],
            ),
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