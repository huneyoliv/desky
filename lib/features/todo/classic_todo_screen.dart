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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Row(
              children: [
                Container(width: 3, height: 14, color: color),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                const SizedBox(width: 4),
                InkWell(
                  key: ValueKey('classic-todo-add-$id'),
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    _addingTo = id;
                    _controller.clear();
                  }),
                  child: Icon(Icons.add_circle_outline, size: 14, color: palette.textSecondary),
                ),
              ],
            ),
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
              padding: const EdgeInsets.only(left: 10, right: 40),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: palette.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t.tr('classic_enter_todo', fallback: 'Enter to-do'),
                  hintStyle: TextStyle(fontSize: 14, color: palette.textMuted),
                ),
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) => _submit(),
              ),
            ),
        ],
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
                  Text(DateFormat('EEE, M/d').format(active),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary)),
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text('${day.day} ${DateFormat('E').format(day)}',
                style: TextStyle(fontSize: 11, color: isToday ? palette.textPrimary : palette.textMuted)),
            const SizedBox(height: 4),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Container(width: 18, height: 2, color: selected ? palette.textPrimary : Colors.transparent),
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
        padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(
              todo.isCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: todo.isCompleted ? Color(todo.subjectColorInt) : palette.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                todo.title,
                style: TextStyle(
                  fontSize: 14,
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
