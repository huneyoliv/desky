import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/timetable_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/timetable_repository.dart';

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return TimetableRepository();
});

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository();
});

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  List<TimetableBlock> _blocks = [];
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> _getDays(AppTranslation t) => [
    {'id': 1, 'name': t.tr('monday', fallback: 'Segunda-feira'), 'short': t.tr('monday_short', fallback: 'Seg')},
    {'id': 2, 'name': t.tr('tuesday', fallback: 'Terça-feira'), 'short': t.tr('tuesday_short', fallback: 'Ter')},
    {'id': 3, 'name': t.tr('wednesday', fallback: 'Quarta-feira'), 'short': t.tr('wednesday_short', fallback: 'Qua')},
    {'id': 4, 'name': t.tr('thursday', fallback: 'Quinta-feira'), 'short': t.tr('thursday_short', fallback: 'Qui')},
    {'id': 5, 'name': t.tr('friday', fallback: 'Sexta-feira'), 'short': t.tr('friday_short', fallback: 'Sex')},
    {'id': 6, 'name': t.tr('saturday', fallback: 'Sábado'), 'short': t.tr('saturday_short', fallback: 'Sáb')},
    {'id': 7, 'name': t.tr('sunday', fallback: 'Domingo'), 'short': t.tr('sunday_short', fallback: 'Dom')},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final timetableRepo = ref.read(timetableRepositoryProvider);
    final subjectRepo = ref.read(subjectRepositoryProvider);

    final results = await Future.wait([
      timetableRepo.fetchTimetable(),
      subjectRepo.fetchSubjects(),
    ]);

    if (mounted) {
      setState(() {
        _blocks = results[0] as List<TimetableBlock>;
        _subjects = results[1] as List<SubjectModel>;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddBlockDialog({int? defaultDay, int? defaultStartHour}) async {
    final t = ref.read(appTranslationProvider);
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('alert_planner_add_study_log_error1', fallback: 'Nenhuma matéria cadastrada. Crie uma matéria primeiro!')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    SubjectModel selectedSubject = _subjects.first;
    int selectedDay = defaultDay ?? 1;
    int startHour = defaultStartHour ?? 8;
    int endHour = (startHour + 2).clamp(1, 24);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(t.tr('add_timetable', fallback: 'Adicionar Horário de Aula'), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.tr('subject', fallback: 'Matéria:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<SubjectModel>(
                value: selectedSubject,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _subjects.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(s.title),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedSubject = val);
                },
              ),
              const SizedBox(height: 16),
              Text(t.tr('day_of_week', fallback: 'Dia da Semana:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: selectedDay,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _getDays(t).map((d) {
                  return DropdownMenuItem(
                    value: d['id'] as int,
                    child: Text(d['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedDay = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.tr('start_time', fallback: 'Início:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: startHour,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: List.generate(24, (i) => i).map((h) {
                            return DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                startHour = val;
                                if (endHour <= startHour) endHour = startHour + 1;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.tr('end_time', fallback: 'Fim:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: endHour,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: List.generate(24, (i) => i + 1).where((h) => h > startHour).map((h) {
                            return DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => endHour = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                final repo = ref.read(timetableRepositoryProvider);
                final block = await repo.createBlock(
                  subjectId: selectedSubject.id,
                  subjectTitle: selectedSubject.title,
                  colorInt: selectedSubject.color.toARGB32(),
                  dayOfWeek: selectedDay,
                  startHour: startHour,
                  endHour: endHour,
                );

                if (block != null) {
                  setState(() => _blocks = [..._blocks, block]);
                } else {
                  final fallbackBlock = TimetableBlock(
                    id: DateTime.now().millisecondsSinceEpoch,
                    subjectId: selectedSubject.id,
                    subjectTitle: selectedSubject.title,
                    colorInt: selectedSubject.color.toARGB32(),
                    dayOfWeek: selectedDay,
                    startHour: startHour,
                    endHour: endHour,
                  );
                  setState(() => _blocks = [..._blocks, fallbackBlock]);
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

  Future<void> _deleteBlock(TimetableBlock block) async {
    final t = ref.read(appTranslationProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.tr('delete_timetable', fallback: 'Excluir Horário'), style: const TextStyle(color: Colors.white)),
        content: Text(
          '${t.tr("delete", fallback: "Excluir")} "${block.subjectTitle}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(t.tr('delete', fallback: 'Excluir'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _blocks = _blocks.where((b) => b.id != block.id).toList();
      });
      final repo = ref.read(timetableRepositoryProvider);
      await repo.deleteBlock(block.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.tr('timetable', fallback: 'Grade Horária Semanal'),
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.tr('timetable_desc', fallback: 'Organize seus horários de aulas e sessões de estudo'),
                        style: AppTextStyles.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(t.tr('add_timetable', fallback: 'Novo Horário'), style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => _showAddBlockDialog(),
                ),
              ],
            ),
          ),

          // Days Header
          Container(
            height: 40,
            color: AppColors.card,
            child: Row(
              children: [
                const SizedBox(width: 60),
                ..._getDays(t).map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),

          // Timetable Grid 24h
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: 24 * 50.0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        children: List.generate(24, (hour) {
                          return SizedBox(
                            height: 50,
                            child: Center(
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    Expanded(
                      child: Stack(
                        children: [
                          Column(
                            children: List.generate(24, (index) {
                              return Container(
                                height: 50,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.border, width: 0.5),
                                  ),
                                ),
                              );
                            }),
                          ),

                          Row(
                            children: List.generate(7, (dayIdx) {
                              final dayOfWeek = dayIdx + 1;
                              final dayBlocks = _blocks.where((b) => b.dayOfWeek == dayOfWeek).toList();

                              return Expanded(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: AppColors.border, width: 0.5),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      ...List.generate(24, (hour) {
                                        return Positioned(
                                          top: hour * 50.0,
                                          left: 0,
                                          right: 0,
                                          height: 50,
                                          child: InkWell(
                                            onTap: () => _showAddBlockDialog(
                                              defaultDay: dayOfWeek,
                                              defaultStartHour: hour,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        );
                                      }),

                                      ...dayBlocks.map((block) {
                                        final top = block.startHour * 50.0;
                                        final height = (block.endHour - block.startHour) * 50.0;
                                        final color = Color(block.colorInt);

                                        return Positioned(
                                          top: top + 2,
                                          left: 4,
                                          right: 4,
                                          height: height - 4,
                                          child: GestureDetector(
                                            onTap: () => _deleteBlock(block),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: color, width: 1.5),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    block.subjectTitle,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${block.startHour.toString().padLeft(2, '0')}:00 - ${block.endHour.toString().padLeft(2, '0')}:00',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
