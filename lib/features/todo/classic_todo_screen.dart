import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/classic_layout.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import '../../data/models/todo_item_model.dart';
import '../settings/settings_notifier.dart';
import '../statistics/stats_data.dart' show mondayOf;
import '../timer/timer_notifier.dart';
import 'todo_notifier.dart';
import 'todo_screen.dart';
import 'widgets/todo_dialog.dart';

/// `/todo`: the Classic YPT to-do list when that look is on.
class HomeTodoScreen extends ConsumerWidget {
  const HomeTodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classic = ref.watch(settingsNotifierProvider.select((s) => s.classicYptLook));
    return classic ? const ClassicTodoScreen() : const TodoScreen();
  }
}

/// YPT-style to-dos: a Mon–Sun strip on top, then every subject with its
/// tasks for the selected day and a "+" to add one inline.
class ClassicTodoScreen extends ConsumerStatefulWidget {
  const ClassicTodoScreen({super.key});

  @override
  ConsumerState<ClassicTodoScreen> createState() => _ClassicTodoScreenState();
}

class _ClassicTodoScreenState extends ConsumerState<ClassicTodoScreen> {
  /// Subject whose inline "new to-do" field is open (0 = no subject).
  int? _addingTo;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    final subject = _addingTo;
    setState(() => _addingTo = null);
    _controller.clear();
    if (title.isEmpty) return;
    await ref.read(todoNotifierProvider.notifier).add(title, subjectId: subject == 0 ? null : subject);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final state = ref.watch(todoNotifierProvider);
    final notifier = ref.read(todoNotifierProvider.notifier);
    final subjects =
        ref.watch(timerNotifierProvider.select((s) => s.subjects)).where((s) => !s.isArchived && !s.isDeleted).toList();
    final active = DateTime.tryParse(notifier.activeDay) ?? DateTime.now();
    final monday = mondayOf(active);
    final today = DateUtils.dateOnly(DateTime.now());

    // Tasks by subject; anything not matching a current subject goes last.
    final bySubject = <int, List<TodoItemModel>>{};
    for (final todo in state.todos) {
      final known = subjects.any((s) => s.id == todo.subjectId);
      bySubject.putIfAbsent(known ? todo.subjectId! : 0, () => []).add(todo);
    }

    Widget section(int id, String title, Color color) {
      final todos = bySubject[id] ?? const <TodoItemModel>[];
      final done = todos.where((d) => d.isCompleted).length;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClassicCard(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  ),
                  if (todos.isNotEmpty)
                    Text('$done/${todos.length}', style: TextStyle(fontSize: 13, color: palette.textMuted)),
                  TextButton.icon(
                    key: ValueKey('classic-todo-add-$id'),
                    onPressed: () => setState(() {
                      _addingTo = id;
                      _controller.clear();
                    }),
                    icon: Icon(Icons.add_rounded, size: 18, color: color),
                    label: Text(t.tr('classic_add', fallback: 'Add'), style: TextStyle(fontSize: 13, color: color)),
                  ),
                ],
              ),
              for (final todo in todos)
                _TodoRow(
                  todo: todo,
                  onToggle: () => notifier.toggle(todo),
                  onEdit: () => TodoDialog.show(context, existing: todo),
                  onDelete: () => notifier.remove(todo),
                ),
              if (_addingTo == id)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 15, color: palette.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.radio_button_unchecked_rounded, size: 18, color: palette.textMuted),
                      hintText: t.tr('classic_enter_todo', fallback: 'Enter to-do'),
                      hintStyle: TextStyle(fontSize: 15, color: palette.textMuted),
                    ),
                    onSubmitted: (_) => _submit(),
                    onTapOutside: (_) => _submit(),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: ClassicPage(
        maxWidth: 860,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(DateFormat('EEE, MMM d').format(active),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.chevron_left, size: 18, color: palette.textSecondary),
                    onPressed: () => notifier.shiftDay(-7),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.chevron_right, size: 18, color: palette.textSecondary),
                    onPressed: () => notifier.shiftDay(7),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _WeekDay(
                        day: monday.add(Duration(days: i)),
                        selected: DateUtils.isSameDay(monday.add(Duration(days: i)), active),
                        isToday: DateUtils.isSameDay(monday.add(Duration(days: i)), today),
                        onTap: () => notifier.selectDay(DateFormat('yyyy-MM-dd').format(monday.add(Duration(days: i)))),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        for (final s in subjects) section(s.id, s.title, Color(s.colorInt)),
                        if (subjects.isEmpty || bySubject.containsKey(0))
                          section(0, t.tr('classic_todo_general', fallback: 'General'), palette.textMuted),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({required this.day, required this.selected, required this.isToday, required this.onTap});
  final DateTime day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = selected ? palette.background : (isToday ? const Color(0xFFFF6B1A) : palette.textPrimary);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(DateFormat('E').format(day), style: TextStyle(fontSize: 12, color: palette.textMuted)),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.textPrimary : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !selected ? Border.all(color: const Color(0xFFFF6B1A), width: 1.5) : null,
              ),
              child: Text('${day.day}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, required this.onToggle, required this.onEdit, required this.onDelete});
  final TodoItemModel todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onToggle,
      onLongPress: onEdit,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
        child: Row(
          children: [
            Icon(
              todo.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: todo.isCompleted ? Color(todo.subjectColorInt) : palette.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                todo.title,
                style: TextStyle(
                  fontSize: 15,
                  color: todo.isCompleted ? palette.textMuted : palette.textPrimary,
                  decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            PopupMenuButton<String>(
              iconSize: 16,
              icon: Icon(Icons.more_vert, size: 16, color: palette.textMuted),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
