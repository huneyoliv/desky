import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../core/utils/study_date_helper.dart';
import '../../data/models/dday_model.dart';
import '../../data/models/todo_item_model.dart';
import '../../data/repositories/planner_repository.dart';
import '../settings/settings_notifier.dart';
import 'timetable_screen.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository();
});

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late DateTime _selectedDate;
  List<DDayModel> _ddays = [];
  List<TodoItemModel> _todos = [];
  bool _isLoading = true;

  final _todoTitleController = TextEditingController();
  final _ddayTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final dayResetHour = ref.read(settingsNotifierProvider).dayResetHour;
    _selectedDate = StudyDateHelper.getStudyDate(null, dayResetHour);
    _loadData();
  }

  @override
  void dispose() {
    _todoTitleController.dispose();
    _ddayTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(plannerRepositoryProvider);
    final dayResetHour = ref.read(settingsNotifierProvider).dayResetHour;
    final dateStr = StudyDateHelper.getStudyDateString(_selectedDate, dayResetHour);

    final results = await Future.wait([
      repo.fetchDDays(),
      repo.fetchTodos(dateStr),
    ]);

    if (mounted) {
      setState(() {
        _ddays = results[0] as List<DDayModel>;
        _todos = results[1] as List<TodoItemModel>;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date, AppTranslation t) {
    try {
      final locale = t.languageCode == 'zh-cn'
          ? 'zh_CN'
          : (t.languageCode == 'zh-tw' ? 'zh_TW' : t.languageCode);
      return DateFormat('EEEE, d MMMM yyyy', locale).format(date);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _toggleTodo(TodoItemModel todo) async {
    final updatedList = _todos.map((t) {
      if (t.id == todo.id) {
        return t.copyWith(isCompleted: !t.isCompleted);
      }
      return t;
    }).toList();

    setState(() {
      _todos = updatedList;
    });

    final repo = ref.read(plannerRepositoryProvider);
    await repo.toggleTodo(todo);
  }

  void _showAddTodoDialog() {
    final t = ref.read(appTranslationProvider);
    bool isRecurring = false;
    Set<int> selectedDays = {1, 2, 3, 4, 5};
    DateTime endDate = _selectedDate.add(const Duration(days: 30));

    final weekdayNames = [
      {'id': 1, 'label': t.tr('day_mon_short', fallback: 'Seg')},
      {'id': 2, 'label': t.tr('day_tue_short', fallback: 'Ter')},
      {'id': 3, 'label': t.tr('day_wed_short', fallback: 'Qua')},
      {'id': 4, 'label': t.tr('day_thu_short', fallback: 'Qui')},
      {'id': 5, 'label': t.tr('day_fri_short', fallback: 'Sex')},
      {'id': 6, 'label': t.tr('day_sat_short', fallback: 'Sáb')},
      {'id': 7, 'label': t.tr('day_sun_short', fallback: 'Dom')},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(t.tr('alert_todo_add', fallback: 'Nova Tarefa do Planner'), style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _todoTitleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: t.tr('todo_desc_hint', fallback: 'Descrição da tarefa...'),
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(t.tr('repeat_multiple_days', fallback: 'Repetir em vários dias'), style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(t.tr('repeat_multiple_days_desc', fallback: 'Criar em múltiplos dias consecutivamente'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  value: isRecurring,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => isRecurring = val);
                  },
                ),
                if (isRecurring) ...[
                  const SizedBox(height: 12),
                  Text(t.tr('weekdays', fallback: 'Dias da Semana:'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: weekdayNames.map((w) {
                      final id = w['id'] as int;
                      final isSelected = selectedDays.contains(id);
                      return FilterChip(
                        label: Text(w['label'] as String, style: TextStyle(color: isSelected ? Colors.white : AppColors.textMuted, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              selectedDays.add(id);
                            } else {
                              selectedDays.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.tr('repeat_until', fallback: 'Repetir até:'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
                        label: Text(DateFormat('dd/MM/yyyy').format(endDate), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: _selectedDate,
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = _todoTitleController.text.trim();
                if (text.isEmpty) return;

                final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                _todoTitleController.clear();
                Navigator.of(context).pop();

                RecurrenceRuleModel? rr;
                if (isRecurring && selectedDays.isNotEmpty) {
                  rr = RecurrenceRuleModel(
                    frequency: 1,
                    interval: 1,
                    daysOfWeek: selectedDays.toList()..sort(),
                    endDate: DateFormat("yyyy-MM-dd'T'23:59:59.000").format(endDate),
                  );
                }

                setState(() {
                  _isLoading = true;
                });

                final repo = ref.read(plannerRepositoryProvider);
                await repo.createTodo(
                  title: text,
                  dateYmd: dateStr,
                  recurrenceRule: rr,
                );

                if (mounted) {
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(t.tr('add', fallback: 'Adicionar'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDDayDialog() {
    final t = ref.read(appTranslationProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('dday', fallback: 'Novo D-Day'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ddayTitleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: t.tr('dday_title_hint', fallback: 'Título do D-Day...'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _ddayTitleController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(t.tr('add', fallback: 'Adicionar'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTodoDialog(TodoItemModel todo) async {
    final t = ref.read(appTranslationProvider);
    final controller = TextEditingController(text: todo.title);
    bool applyToAllSeries = todo.isRecurring;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(t.tr('edit', fallback: 'Editar Tarefa'), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: t.tr('todo_title', fallback: 'Título da tarefa'),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (todo.isRecurring) ...[
                const SizedBox(height: 16),
                Text(t.tr('recurring_todo_desc', fallback: 'Esta tarefa se repete em vários dias:'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                RadioListTile<bool>(
                  title: Text(t.tr('only_this_todo', fallback: 'Apenas esta tarefa'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  value: false,
                  groupValue: applyToAllSeries,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => applyToAllSeries = val!),
                ),
                RadioListTile<bool>(
                  title: Text(t.tr('all_series_todos', fallback: 'Esta e todas as tarefas da série'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  value: true,
                  groupValue: applyToAllSeries,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => applyToAllSeries = val!),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop();
                  setState(() {
                    _todos = _todos.map((t) => t.id == todo.id ? t.copyWith(title: text) : t).toList();
                  });
                  final repo = ref.read(plannerRepositoryProvider);
                  await repo.editTodo(todo, text, applyToAll: applyToAllSeries);
                  if (mounted) {
                    _loadData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(t.tr('save', fallback: 'Salvar'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTodo(TodoItemModel todo) async {
    final t = ref.read(appTranslationProvider);
    bool deleteAllSeries = todo.isRecurring;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('${t.tr("delete", fallback: "Excluir")} "${todo.title}"?', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('delete_todo_confirm', fallback: 'Tem certeza que deseja excluir esta tarefa?'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (todo.isRecurring) ...[
                const SizedBox(height: 16),
                Text(t.tr('recurring_todo_desc', fallback: 'Esta tarefa se repete em vários dias:'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                RadioListTile<bool>(
                  title: Text(t.tr('delete_only_this_todo', fallback: 'Excluir apenas esta tarefa'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  value: false,
                  groupValue: deleteAllSeries,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => deleteAllSeries = val!),
                ),
                RadioListTile<bool>(
                  title: Text(t.tr('delete_all_series_todos', fallback: 'Excluir todas as tarefas da série'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  value: true,
                  groupValue: deleteAllSeries,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => deleteAllSeries = val!),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _todos = _todos.where((t) => t.id != todo.id).toList();
                });
                final repo = ref.read(plannerRepositoryProvider);
                await repo.deleteTodo(todo.id, deleteAllSeries: deleteAllSeries);
                if (mounted) {
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(t.tr('delete', fallback: 'Excluir'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _todos.where((t) => t.isCompleted).length;
    final totalCount = _todos.length;
    final progressPct = totalCount > 0 ? completedCount / totalCount : 0.0;
    final t = ref.watch(appTranslationProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: t.tr('todo', fallback: 'Tarefas & D-Days')),
              Tab(text: t.tr('timetable', fallback: 'Grade Horária')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Row(
              children: [
                // Left Sidebar - Calendar & D-Days
                Container(
                  width: 380,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(t.tr('dday', fallback: 'Seus D-Days'), style: AppTextStyles.titleLarge),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: AppColors.primary),
                              onPressed: _showAddDDayDialog,
                              tooltip: t.tr('dday', fallback: 'Novo D-Day'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // D-Days Horizontal List
                        SizedBox(
                          height: 100,
                          child: _ddays.isEmpty
                              ? Center(
                                  child: Text(
                                    t.tr('dday_empty', fallback: 'Nenhum D-Day cadastrado'),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _ddays.length,
                                  itemBuilder: (context, index) {
                                    final dday = _ddays[index];
                                    return Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: dday.color.withValues(alpha: 0.6)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            dday.label,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: dday.color,
                                            ),
                                          ),
                                          Text(
                                            dday.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 32),

                        Text(t.tr('calendar', fallback: 'Calendário de Estudos'), style: AppTextStyles.titleLarge),
                        const SizedBox(height: 12),

                        // Mini Calendar View
                        CalendarDatePicker(
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          onDateChanged: (date) {
                            setState(() => _selectedDate = date);
                            _loadData();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Column - To-Do Checklist
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.tr('todo', fallback: 'Planner de Estudos (To-Do)'),
                                    style: AppTextStyles.displayMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppColors.textMuted),
                                          onPressed: () {
                                            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                                            _loadData();
                                          },
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _selectedDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2030),
                                            );
                                            if (picked != null) {
                                              setState(() => _selectedDate = picked);
                                              _loadData();
                                            }
                                          },
                                          child: Text(
                                            _formatDate(_selectedDate, t),
                                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
                                          onPressed: () {
                                            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                                            _loadData();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _showAddTodoDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: Text(t.tr('add', fallback: 'Nova Tarefa'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Progress Bar Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${t.tr("today", fallback: "Progresso")}: $completedCount / $totalCount ${t.tr("done", fallback: "concluídas")}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(progressPct * 100).toInt()}%',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progressPct,
                                  minHeight: 8,
                                  backgroundColor: AppColors.surface,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // To-Do Checklist Items
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _todos.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle_outline,
                                              size: 48, color: AppColors.textMuted),
                                          const SizedBox(height: 12),
                                          Text(
                                            t.tr('alert_todo_add_error', fallback: 'Nenhuma tarefa agendada para este dia.'),
                                            style: const TextStyle(color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: _showAddTodoDialog,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary),
                                            child: Text(t.tr('add', fallback: 'Adicionar Tarefa'),
                                                style: const TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _todos.length,
                                      itemBuilder: (context, index) {
                                        final todo = _todos[index];

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.card,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: todo.isCompleted
                                                  ? AppColors.border
                                                  : Color(todo.subjectColorInt)
                                                      .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: todo.isCompleted,
                                                activeColor: AppColors.primary,
                                                onChanged: (_) => _toggleTodo(todo),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: Color(todo.subjectColorInt),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            todo.title,
                                                            style: TextStyle(
                                                              color: todo.isCompleted
                                                                  ? AppColors.textMuted
                                                                  : Colors.white,
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w600,
                                                              decoration: todo.isCompleted
                                                                  ? TextDecoration.lineThrough
                                                                  : null,
                                                            ),
                                                          ),
                                                        ),
                                                        if (todo.isRecurring)
                                                          const Padding(
                                                            padding: EdgeInsets.only(left: 6),
                                                            child: Icon(Icons.sync_rounded,
                                                                size: 15, color: AppColors.primary),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      todo.subjectTitle,
                                                      style: const TextStyle(
                                                          color: AppColors.textMuted,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                                                    tooltip: t.tr('edit', fallback: 'Editar Tarefa'),
                                                    onPressed: () => _showEditTodoDialog(todo),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                                    tooltip: t.tr('delete', fallback: 'Excluir Tarefa'),
                                                    onPressed: () => _deleteTodo(todo),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const TimetableScreen(),
          ],
        ),
      ),
    );
  }
}
