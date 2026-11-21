import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_translation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/todo_item_model.dart';
import 'todo_notifier.dart';
import 'widgets/todo_dialog.dart';

/// Standalone To-Do section: the planner's tasks, on their own screen with day
/// navigation, so they are reachable straight from the sidebar.
class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final state = ref.watch(todoNotifierProvider);
    final notifier = ref.read(todoNotifierProvider.notifier);
    final progress = notifier.progress;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        title: Text(
          t.tr('todo_tab_title', fallback: 'To-Do'),
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          IconButton(
            tooltip: t.tr('todo_today', fallback: 'Hoje'),
            icon: const Icon(Icons.today_rounded),
            onPressed: notifier.isToday ? null : () => notifier.selectDay(null),
          ),
          IconButton(
            tooltip: t.tr('refresh', fallback: 'Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TodoDialog.show(context),
        backgroundColor: context.appPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          t.tr('todo_add', fallback: 'Adicionar tarefa'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _DayHeader(
            day: notifier.activeDay,
            isToday: notifier.isToday,
            total: progress.total,
            done: progress.done,
            onPrevious: () => notifier.shiftDay(-1),
            onNext: () => notifier.shiftDay(1),
            onPick: () => _pickDay(context, notifier),
          ),
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: AppColors.error.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                t.tr('todo_sync_failed',
                    fallback: 'Could not save to the server. The list was reloaded.'),
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? Center(child: CircularProgressIndicator(color: context.appPrimary))
                : state.todos.isEmpty
                    ? _EmptyState(t: t)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                        itemCount: state.todos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final todo = state.todos[index];
                          return _TodoTile(
                            todo: todo,
                            onToggle: () => notifier.toggle(todo),
                            onEdit: () => TodoDialog.show(context, existing: todo),
                            onDelete: () => notifier.remove(todo),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static Future<void> _pickDay(BuildContext context, TodoNotifier notifier) async {
    final parsed = DateTime.tryParse(notifier.activeDay) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(parsed.year - 5),
      lastDate: DateTime(parsed.year + 5),
    );
    if (picked != null) {
      notifier.selectDay(DateFormat('yyyy-MM-dd').format(picked));
    }
  }
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.total,
    required this.done,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final String day;
  final bool isToday;
  final int total;
  final int done;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final parsed = DateTime.tryParse(day);
    final label = parsed == null
        ? day
        : DateFormat('EEEE, d MMMM', Localizations.localeOf(context).toString())
            .format(parsed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: context.appSurface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: context.appTextSecondary,
            onPressed: onPrevious,
            tooltip: t.tr('previous_day', fallback: 'Dia anterior'),
          ),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      isToday ? '${t.tr('today', fallback: 'Hoje')} · $label' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? t.tr('todo_no_tasks_day',
                              fallback: 'Nenhuma tarefa neste dia')
                          : '$done/$total ${t.tr('todo_done_of', fallback: 'done')}',
                      style: TextStyle(color: context.appTextMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: context.appTextSecondary,
            onPressed: onNext,
            tooltip: t.tr('next_day', fallback: 'Próximo dia'),
          ),
        ],
      ),
    );
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItemModel todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final subtitle = StringBuffer(todo.subjectTitle);
    if (todo.isRecurring) {
      if (subtitle.isNotEmpty) subtitle.write(' · ');
      subtitle.write(t.tr('todo_recurring', fallback: 'recurring'));
    }

    return Material(
      color: context.appCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: todo.isCompleted,
                activeColor: context.appPrimary,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: todo.isCompleted
                            ? context.appTextMuted
                            : context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration:
                            todo.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: t.tr('delete', fallback: 'Excluir'),
                icon: Icon(Icons.delete_outline,
                    size: 20, color: context.appTextMuted),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.t});

  final AppTranslation t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rounded, size: 64, color: context.appTextMuted),
            const SizedBox(height: 16),
            Text(
              t.tr('todo_empty_title', fallback: 'Nenhuma tarefa para este dia'),
              style: TextStyle(color: context.appTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              t.tr('todo_empty_desc',
                  fallback: 'Use o botão abaixo para criar a primeira.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}