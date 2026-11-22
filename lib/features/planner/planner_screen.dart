import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../core/utils/study_day_helper.dart';
import '../../data/models/dday_model.dart';
import '../../data/models/todo_item_model.dart';
import '../../data/repositories/planner_repository.dart';
import '../settings/settings_notifier.dart';
import '../timer/timer_notifier.dart';
import 'timetable_screen.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository();
});

/// Valor sentinela do seletor de materia: nenhuma materia associada.
const int _kNoSubject = -1;

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
    _selectedDate = DateTime.parse(
      StudyDayHelper.todayYmd(gmtOffset: _gmtOffset, resetHour: _resetHour),
    );
    _loadData();
  }

  /// YPT closes the study day using the selected country's fixed GMT offset and
  /// start hour, which is also what the mobile app shows in the planner.
  Duration get _gmtOffset =>
      ref.read(settingsNotifierProvider).selectedCountry.gmtOffsetDuration ??
      DateTime.now().timeZoneOffset;

  int get _resetHour =>
      ref.read(settingsNotifierProvider).selectedCountry.startHour;

  @override
  void dispose() {
    _todoTitleController.dispose();
    _ddayTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(plannerRepositoryProvider);
    final gmtOffset = _gmtOffset;
    final resetHour = _resetHour;
    final dateStr = StudyDayHelper.formatYmd(_selectedDate);

    final results = await Future.wait([
      repo.fetchDDays(),
      repo.fetchTodos(dateStr, gmtOffset: gmtOffset, resetHour: resetHour),
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
    await repo.toggleTodo(todo, gmtOffset: _gmtOffset, resetHour: _resetHour);
  }

  /// Inicia o cronometro para a materia da tarefa.
  ///
  /// Mesmas pre-condicoes que o To-Do antigo aplicava: a tarefa precisa estar
  /// aberta, ter materia associada, essa materia precisa existir na lista atual
  /// e o cronometro nao pode estar em andamento. Caso contrario avisamos em vez
  /// de abrir uma sessao sem materia.
  Future<void> _startTodoStudy(TodoItemModel todo) async {
    final t = ref.read(appTranslationProvider);
    final messenger = ScaffoldMessenger.of(context);
    final timerState = ref.read(timerNotifierProvider);
    final matches = timerState.subjects
        .where((subject) => subject.id == todo.subjectId)
        .toList();

    final blocked = todo.isCompleted ||
        todo.subjectId == null ||
        matches.isEmpty ||
        timerState.isRunning ||
        timerState.isPaused;

    if (blocked) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t.tr('todo_start_failed',
                fallback: 'Não foi possível iniciar estudo para esta tarefa.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final timer = ref.read(timerNotifierProvider.notifier);
    timer.selectSubject(matches.first);
    await timer.startStudy(taskId: todo.id);
    if (!mounted) return;

    if (!ref.read(timerNotifierProvider).isRunning) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t.tr('todo_start_failed',
                fallback: 'Não foi possível iniciar estudo para esta tarefa.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    context.go('/home');
  }

  /// Aviso unico para criacao/edicao/exclusao recusadas pela API.
  ///
  /// O To-Do antigo mostrava "Nao foi possivel salvar" e mantinha o item; o
  /// Planner fechava o dialogo em silencio. Mantemos a mesma mensagem para o
  /// usuario nao ficar sem retorno.
  void _showSaveFailed(AppTranslation t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t.tr('todo_save_failed',
              fallback: 'Não foi possível salvar. Tente novamente.'),
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// Seletor de materia compartilhado por criacao e edicao de tarefa.
  ///
  /// Reaproveita o mesmo cuidado do dialogo antigo do To-Do: uma materia que
  /// nao veio na lista atual (arquivada ou removida) continua selecionavel, em
  /// vez de quebrar o `DropdownButtonFormField` ou trocar a associacao sozinha.
  Widget _buildSubjectDropdown({
    required AppTranslation t,
    required int value,
    required bool enabled,
    required ValueChanged<int> onChanged,
    TodoItemModel? existing,
  }) {
    final subjects =
        ref.watch(timerNotifierProvider.select((state) => state.subjects));
    final items = <DropdownMenuItem<int>>[
      DropdownMenuItem<int>(
        value: _kNoSubject,
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

    final existingId = existing?.subjectId;
    if (existingId != null &&
        existingId != _kNoSubject &&
        items.every((item) => item.value != existingId)) {
      final fallbackTitle = existing?.subjectTitle.trim() ?? '';
      items.add(
        DropdownMenuItem<int>(
          value: existingId,
          child: Text(
            fallbackTitle.isEmpty || fallbackTitle == 'Geral'
                ? '${t.tr('todo_subject', fallback: 'Matéria')} $existingId'
                : fallbackTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final hasValue = items.any((item) => item.value == value);
    return DropdownButtonFormField<int>(
      value: hasValue ? value : _kNoSubject,
      isExpanded: true,
      dropdownColor: context.appCard,
      decoration: InputDecoration(
        labelText: t.tr('todo_subject', fallback: 'Matéria'),
        labelStyle: TextStyle(color: context.appTextMuted),
        filled: true,
        fillColor: context.appSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: items,
      onChanged: enabled
          ? (selected) {
              if (selected != null) onChanged(selected);
            }
          : null,
    );
  }

  void _showAddTodoDialog() {
    final t = ref.read(appTranslationProvider);
    bool isRecurring = false;
    Set<int> selectedDays = {1, 2, 3, 4, 5};
    // -1 representa "sem materia", como no dialogo do To-Do.
    int subjectChoice = _kNoSubject;
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
          backgroundColor: context.appCard,
          title: Text(t.tr('alert_todo_add', fallback: 'Nova Tarefa do Planner'), style: const TextStyle(color: context.appTextPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _todoTitleController,
                  style: const TextStyle(color: context.appTextPrimary),
                  decoration: InputDecoration(
                    hintText: t.tr('todo_desc_hint', fallback: 'Descrição da tarefa...'),
                    hintStyle: TextStyle(color: context.appTextMuted),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSubjectDropdown(
                  t: t,
                  value: subjectChoice,
                  enabled: true,
                  onChanged: (value) =>
                      setDialogState(() => subjectChoice = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(t.tr('repeat_multiple_days', fallback: 'Repetir em vários dias'), style: const TextStyle(color: context.appTextPrimary, fontSize: 14)),
                  subtitle: Text(t.tr('repeat_multiple_days_desc', fallback: 'Criar em múltiplos dias consecutivamente'), style: TextStyle(color: context.appTextMuted, fontSize: 12)),
                  value: isRecurring,
                  activeColor: context.appPrimary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => isRecurring = val);
                  },
                ),
                if (isRecurring) ...[
                  const SizedBox(height: 12),
                  Text(t.tr('weekdays', fallback: 'Dias da Semana:'), style: const TextStyle(color: context.appTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: weekdayNames.map((w) {
                      final id = w['id'] as int;
                      final isSelected = selectedDays.contains(id);
                      return FilterChip(
                        label: Text(w['label'] as String, style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.appTextMuted, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: context.appPrimary,
                        backgroundColor: context.appSurface,
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
                      Text(t.tr('repeat_until', fallback: 'Repetir até:'), style: const TextStyle(color: context.appTextPrimary, fontSize: 13)),
                      TextButton.icon(
                        icon: Icon(Icons.calendar_month, color: context.appPrimary, size: 18),
                        label: Text(DateFormat('dd/MM/yyyy').format(endDate), style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.bold)),
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
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: TextStyle(color: context.appTextMuted)),
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
                final created = await repo.createTodo(
                  title: text,
                  dateYmd: dateStr,
                  gmtOffset: _gmtOffset,
                  resetHour: _resetHour,
                  subjectId:
                      subjectChoice == _kNoSubject ? null : subjectChoice,
                  recurrenceRule: rr,
                );

                if (!mounted) return;
                // Antes de portar o To-Do para o Planner, uma criacao recusada
                // pela API fechava o dialogo e nao deixava rastro: a tarefa
                // simplesmente nao aparecia. Avisamos e recarregamos.
                if (created == null) {
                  _showSaveFailed(t);
                }
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.appPrimary),
              child: Text(t.tr('add', fallback: 'Adicionar'), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  /// D-Day deletion had no entry point either; long-press asks for confirm.
  Future<void> _confirmDeleteDDay(DDayModel dday) async {
    final t = ref.read(appTranslationProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appCard,
        title: Text(
          t.tr('dday_delete_title', fallback: 'Excluir D-Day'),
          style: const TextStyle(color: context.appTextPrimary),
        ),
        content: Text(
          dday.title,
          style: TextStyle(color: context.appTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t.tr('cancel', fallback: 'Cancelar'),
              style: TextStyle(color: context.appTextMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: context.appPrimary),
            child: Text(
              t.tr('delete', fallback: 'Excluir'),
              style: const TextStyle(color: context.appTextPrimary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final removed =
        await ref.read(plannerRepositoryProvider).deleteDDay(dday.id);
    if (removed) {
      await _loadData();
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? t.tr('dday_deleted', fallback: 'D-Day excluído')
              : t.tr('dday_delete_failed',
                  fallback: 'Não foi possível excluir o D-Day'),
        ),
      ),
    );
  }

  /// The dialog used to only close itself, so tapping "Adicionar" discarded
  /// the typed title and no record was ever sent. It now collects the target
  /// date the API requires and calls [createDDay].
  Future<void> _showAddDDayDialog() async {
    final t = ref.read(appTranslationProvider);
    var targetDate = _selectedDate;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: targetDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setDialogState(() => targetDate = picked);
            }
          }

          return AlertDialog(
            backgroundColor: context.appCard,
            title: Text(
              t.tr('dday', fallback: 'Novo D-Day'),
              style: const TextStyle(color: context.appTextPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _ddayTitleController,
                  style: const TextStyle(color: context.appTextPrimary),
                  decoration: InputDecoration(
                    hintText: t.tr('dday_title_hint', fallback: 'Título do D-Day...'),
                    hintStyle: TextStyle(color: context.appTextMuted),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    '${targetDate.day.toString().padLeft(2, '0')}/'
                    '${targetDate.month.toString().padLeft(2, '0')}/'
                    '${targetDate.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.appPrimary,
                  ),
                ),
              ],
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
                onPressed: () async {
                  final title = _ddayTitleController.text.trim();
                  if (title.isEmpty) return;
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  navigator.pop();
                  final created = await ref
                      .read(plannerRepositoryProvider)
                      .createDDay(
                        title: title,
                        targetDate: targetDate,
                        colorInt: 4294948685,
                      );
                  _ddayTitleController.clear();
                  if (created != null) {
                    await _loadData();
                  }
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        created != null
                            ? t.tr('dday_created', fallback: 'D-Day criado')
                            : t.tr('dday_create_failed',
                                fallback: 'Não foi possível criar o D-Day'),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPrimary,
                ),
                child: Text(
                  t.tr('add', fallback: 'Adicionar'),
                  style: const TextStyle(color: context.appTextPrimary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditTodoDialog(TodoItemModel todo) async {
    final t = ref.read(appTranslationProvider);
    final controller = TextEditingController(text: todo.title);
    int subjectChoice = todo.subjectId ?? _kNoSubject;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.appCard,
          title: Text(t.tr('edit', fallback: 'Editar Tarefa'), style: const TextStyle(color: context.appTextPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: context.appTextPrimary),
                decoration: InputDecoration(
                  hintText: t.tr('todo_title', fallback: 'Título da tarefa'),
                  filled: true,
                  fillColor: context.appSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              _buildSubjectDropdown(
                t: t,
                value: subjectChoice,
                enabled: true,
                existing: todo,
                onChanged: (value) =>
                    setDialogState(() => subjectChoice = value),
              ),
              if (todo.isRecurring) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: context.appTextMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.tr('edit_only_this_todo_desc',
                              fallback:
                                  'Esta tarefa se repete em vários dias. Apenas esta ocorrência será alterada; as demais permanecem.'),
                          style: TextStyle(
                              color: context.appTextMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: TextStyle(color: context.appTextMuted)),
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
                  final edited = await repo.editTodo(
                    todo,
                    text,
                    gmtOffset: _gmtOffset,
                    resetHour: _resetHour,
                    subjectId:
                        subjectChoice == _kNoSubject ? null : subjectChoice,
                    updateSubject: true,
                  );
                  if (!mounted) return;
                  if (!edited) _showSaveFailed(t);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: context.appPrimary),
              child: Text(t.tr('save', fallback: 'Salvar'), style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTodo(TodoItemModel todo) async {
    final t = ref.read(appTranslationProvider);
    // A exclusao da serie so voltou a UI depois da prova live com target:all,
    // releitura e limpeza. A ocorrencia continua sendo a opcao padrao.
    var deleteAllSeries = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.appCard,
          title: Text('${t.tr("delete", fallback: "Excluir")} "${todo.title}"?', style: const TextStyle(color: context.appTextPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('delete_todo_confirm', fallback: 'Tem certeza que deseja excluir esta tarefa?'),
                style: TextStyle(color: context.appTextSecondary),
              ),
              if (todo.isRecurring) ...[
                const SizedBox(height: 16),
                RadioListTile<bool>(
                  value: false,
                  groupValue: deleteAllSeries,
                  contentPadding: EdgeInsets.zero,
                  activeColor: context.appPrimary,
                  title: Text(
                    t.tr('delete_only_this_todo', fallback: 'Excluir apenas esta tarefa'),
                    style: const TextStyle(color: context.appTextPrimary, fontSize: 13),
                  ),
                  onChanged: (value) => setDialogState(
                    () => deleteAllSeries = value ?? false,
                  ),
                ),
                RadioListTile<bool>(
                  value: true,
                  groupValue: deleteAllSeries,
                  contentPadding: EdgeInsets.zero,
                  activeColor: context.appPrimary,
                  title: Text(
                    t.tr('delete_all_series_todos', fallback: 'Excluir todas as tarefas da série'),
                    style: const TextStyle(color: context.appTextPrimary, fontSize: 13),
                  ),
                  onChanged: (value) => setDialogState(
                    () => deleteAllSeries = value ?? true,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: context.appTextMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.tr(
                            deleteAllSeries
                                ? 'delete_all_series_todos_desc'
                                : 'delete_only_this_todo_desc',
                            fallback: deleteAllSeries
                                ? 'Todas as ocorrências desta série serão excluídas. Esta ação não pode ser desfeita.'
                                : 'Esta tarefa se repete em vários dias. Apenas esta ocorrência será excluída; as demais permanecem.',
                          ),
                          style: TextStyle(
                              color: context.appTextMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: TextStyle(color: context.appTextMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _todos = _todos.where((t) => t.id != todo.id).toList();
                });
                final repo = ref.read(plannerRepositoryProvider);
                final deleted = await repo.deleteTodo(
                  todo.id,
                  deleteAllSeries: deleteAllSeries,
                );
                if (!mounted) return;
                if (!deleted) {
                  // A remocao local ja aconteceu; se a API recusou, recarregar
                  // devolve o item em vez de deixar a lista mentindo.
                  _showSaveFailed(t);
                }
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(t.tr('delete', fallback: 'Excluir'), style: TextStyle(color: Theme.of(context).colorScheme.onError)),
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
    final palette = context.palette;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            indicatorColor: palette.primary,
            labelColor: palette.textPrimary,
            unselectedLabelColor: palette.textSecondary,
            tabs: [
              Tab(text: t.tr('todo', fallback: 'Tarefas & D-Days')),
              Tab(
                text: t.tr(
                  'planner_calendar_tab',
                  fallback: 'Calendário',
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // stretch: sem isso o painel esquerdo (largura fixa) fica centralizado
            // na vertical e sobra uma faixa vazia acima dos D-Days e abaixo do calendario.
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Sidebar - Calendar & D-Days
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(right: BorderSide(color: palette.border)),
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
                              icon: Icon(Icons.add_circle_outline,
                                  color: context.appPrimary),
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
                                    style: TextStyle(color: context.appTextMuted, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _ddays.length,
                                  itemBuilder: (context, index) {
                                    final dday = _ddays[index];
                                    return GestureDetector(
                                      onLongPress: () => _confirmDeleteDDay(dday),
                                      child: Container(
                                        width: 160,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: palette.card,
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
                                              color: context.appTextPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
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
                                          icon: Icon(Icons.arrow_back_ios_rounded, size: 16, color: context.appTextMuted),
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
                                            style: AppTextStyles.bodyMedium.copyWith(color: context.appPrimary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.appTextMuted),
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
                                backgroundColor: context.appPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.add, color: context.appTextPrimary, size: 18),
                              label: Text(t.tr('add', fallback: 'Nova Tarefa'),
                                  style: const TextStyle(
                                      color: context.appTextPrimary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Progress Bar Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.appCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.appBorder),
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
                                          color: context.appTextPrimary,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(progressPct * 100).toInt()}%',
                                    style: TextStyle(
                                        color: context.appPrimary,
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
                                  backgroundColor: context.appSurface,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      context.appPrimary),
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
                                          Icon(Icons.check_circle_outline,
                                              size: 48, color: context.appTextMuted),
                                          const SizedBox(height: 12),
                                          Text(
                                            t.tr('alert_todo_add_error', fallback: 'Nenhuma tarefa agendada para este dia.'),
                                            style: TextStyle(color: context.appTextSecondary),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: _showAddTodoDialog,
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: context.appPrimary),
                                            child: Text(t.tr('add', fallback: 'Adicionar Tarefa'),
                                                style: const TextStyle(color: context.appTextPrimary)),
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
                                            color: context.appCard,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: todo.isCompleted
                                                  ? context.appBorder
                                                  : Color(todo.subjectColorInt)
                                                      .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: todo.isCompleted,
                                                activeColor: context.appPrimary,
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
                                                                  ? context.appTextMuted
                                                                  : context.appTextPrimary,
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w600,
                                                              decoration: todo.isCompleted
                                                                  ? TextDecoration.lineThrough
                                                                  : null,
                                                            ),
                                                          ),
                                                        ),
                                                        if (todo.isRecurring)
                                                          Padding(
                                                            padding: EdgeInsets.only(left: 6),
                                                            child: Icon(Icons.sync_rounded,
                                                                size: 15, color: context.appPrimary),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      todo.subjectTitle,
                                                      style: TextStyle(
                                                          color: context.appTextMuted,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.play_arrow_rounded, color: context.appTextSecondary, size: 18),
                                                    tooltip: t.tr('todo_start_study', fallback: 'Iniciar estudo'),
                                                    onPressed: () => _startTodoStudy(todo),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: context.appTextSecondary, size: 18),
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
