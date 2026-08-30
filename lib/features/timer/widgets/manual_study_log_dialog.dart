import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';
import '../../../data/models/subject_model.dart';
import '../timer_notifier.dart';

class ManualStudyLogDialog extends ConsumerStatefulWidget {
  const ManualStudyLogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ManualStudyLogDialog(),
    );
  }

  @override
  ConsumerState<ManualStudyLogDialog> createState() => _ManualStudyLogDialogState();
}

class _ManualStudyLogDialogState extends ConsumerState<ManualStudyLogDialog> {
  SubjectModel? _selectedSubject;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now().replacing(
    hour: TimeOfDay.now().hour > 0 ? TimeOfDay.now().hour - 1 : 0,
  );
  TimeOfDay _stopTime = TimeOfDay.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final timerState = ref.read(timerNotifierProvider);
    _selectedSubject = timerState.currentSubject ??
        (timerState.subjects.isNotEmpty ? timerState.subjects.first : null);
  }

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _stopDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _stopTime.hour,
        _stopTime.minute,
      );

  Duration get _calculatedDuration => _stopDateTime.difference(_startDateTime);

  String _formatDuration(Duration d) {
    if (d.isNegative || d.inMinutes == 0) return '0 min';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '$mins min';
  }

  Future<void> _handleSave() async {
    final t = ref.read(appTranslationProvider);
    if (_selectedSubject == null) {
      setState(() => _errorMessage = t.tr('select_subject', fallback: 'Selecione uma matéria.'));
      return;
    }

    if (_stopDateTime.isBefore(_startDateTime) || _stopDateTime == _startDateTime) {
      setState(() => _errorMessage = t.tr('invalid_time_range', fallback: 'O horário de término deve ser posterior ao início.'));
      return;
    }

    if (_stopDateTime.isAfter(DateTime.now())) {
      setState(() => _errorMessage = t.tr('no_future_study', fallback: 'Não é permitido registrar estudos no futuro.'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref.read(timerNotifierProvider.notifier).logManualStudy(
          subjectId: _selectedSubject!.id,
          subjectTitle: _selectedSubject!.title,
          startAt: _startDateTime,
          stopAt: _stopDateTime,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.tr("study", fallback: "Estudo")} ${_selectedSubject!.title} ${t.tr("success", fallback: "registrado com sucesso!")}'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _errorMessage = t.tr('manual_log_failed', fallback: 'Falha ao registrar estudo manual no servidor.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerNotifierProvider);
    final t = ref.watch(appTranslationProvider);
    final subjects = timerState.subjects;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.edit_calendar_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            t.tr('manual_study_record', fallback: 'Registro Manual de Estudo'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Subject Dropdown
              Text(t.tr('subjects', fallback: 'Matéria:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<SubjectModel>(
                value: _selectedSubject,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: subjects.map((s) {
                  return DropdownMenuItem<SubjectModel>(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(s.title, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubject = val),
              ),
              const SizedBox(height: 16),

              // Date Selector
              Text(t.tr('date', fallback: 'Data do Estudo:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Times Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.tr('start_time', fallback: 'Início:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (picked != null) {
                              setState(() => _startTime = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.tr('end_time', fallback: 'Término:'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _stopTime,
                            );
                            if (picked != null) {
                              setState(() => _stopTime = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_stopTime.hour.toString().padLeft(2, '0')}:${_stopTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Duration Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.tr('calculated_duration', fallback: 'Duração calculada:'), style: const TextStyle(color: AppColors.primaryLight, fontSize: 13)),
                    Text(
                      _formatDuration(_calculatedDuration),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(t.tr('save', fallback: 'Registrar Estudo'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
