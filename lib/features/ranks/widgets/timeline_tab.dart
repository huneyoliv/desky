import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../../data/repositories/rank_repository.dart';
import '../../settings/settings_notifier.dart';
import '../../timer/widgets/manual_study_log_dialog.dart';
import '../session_derivations.dart';
import '../timeline_derivations.dart';

class TimelineTab extends ConsumerStatefulWidget {
  const TimelineTab({
    super.key,
    required this.repository,
    required this.userId,
  });

  final RankRepository repository;
  final int userId;

  @override
  ConsumerState<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<TimelineTab> {
  DateTime _selectedDay = DateTime.now();
  TimelineDaySummary _summary = const TimelineDaySummary(
    sessions: [],
    gaps: [],
    totalStudyMs: 0,
  );
  bool _loading = true;
  int _requestId = 0;

  String get _dayKey => DateFormat('yyyy-MM-dd').format(_selectedDay);

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    final request = ++_requestId;
    setState(() => _loading = true);
    if (widget.userId <= 0) {
      setState(() {
        _summary = const TimelineDaySummary(
          sessions: [],
          gaps: [],
          totalStudyMs: 0,
        );
        _loading = false;
      });
      return;
    }
    try {
      final sessions = await widget.repository.fetchStudySessions(
        userId: widget.userId,
        startDate: _dayKey,
        endDate: _dayKey,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _summary = summarizeTimelineDay(sessions, _dayKey);
        _loading = false;
      });
    } catch (_) {
      if (mounted && request == _requestId) {
        setState(() {
          _summary = const TimelineDaySummary(
            sessions: [],
            gaps: [],
            totalStudyMs: 0,
          );
          _loading = false;
        });
      }
    }
  }

  void _changeDay(int delta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: delta));
    });
    _loadDay();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDay = picked);
    _loadDay();
  }

  Future<void> _addManualStudy() async {
    final saved = await ManualStudyLogDialog.show(
      context,
      initialDate: _selectedDay,
    );
    if (saved) _loadDay();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);
    final showGaps = ref.watch(settingsNotifierProvider).showRestTime;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: context.appSurface,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: t.tr('timeline_previous_day', fallback: 'Dia anterior'),
                onPressed: () => _changeDay(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton(
                onPressed: _pickDay,
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDay)),
              ),
              IconButton(
                tooltip: t.tr('timeline_next_day', fallback: 'Próximo dia'),
                onPressed: () => _changeDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedDay = DateTime.now());
                  _loadDay();
                },
                child: Text(t.tr('today', fallback: 'Hoje')),
              ),
              const SizedBox(width: 8),
              Text(
                '${t.tr('timeline_total', fallback: 'Total do dia')}: '
                '${formatTimelineDuration(_summary.totalStudyMs)}',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addManualStudy,
                icon: const Icon(Icons.add, size: 18),
                label: Text(t.tr('alert_planner_add_study_log',
                    fallback: 'Registro Manual de Estudo')),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: !_loading && _summary.sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      t.tr('timeline_empty',
                          fallback: 'Nenhuma sessão de estudo neste dia.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (var index = 0; index < _summary.sessions.length; index++) ...[
                      _SessionCard(session: _summary.sessions[index]),
                      if (showGaps) ..._gapCards(index),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _gapCards(int index) {
    return [
      for (final gap in _summary.gaps.where(
        (gap) => gap.afterSessionIndex == index,
      ))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.more_time, size: 16, color: context.appTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ref.read(appTranslationProvider).tr('timeline_gap_derived', fallback: 'Intervalo derivado entre sessões')}: '
                  '${formatMinuteOfDay(gap.startMinute)}–${formatMinuteOfDay(gap.endMinute)} '
                  '(${gap.durationMinutes}min)',
                  style: TextStyle(color: context.appTextMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final color = session.subject.isEmpty
        ? context.appPrimary
        : ColorUtils.fromArgbInt(ColorUtils.defaultSubjectColors[
            session.subject.hashCode.abs() %
                ColorUtils.defaultSubjectColors.length
          ]);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.subject.isEmpty
                        ? t.tr('timeline_no_subject', fallback: 'Sem matéria')
                        : session.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMinuteOfDay(session.startMinute)}–'
                    '${formatMinuteOfDay(session.endMinute)}',
                    style: TextStyle(color: context.appTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatTimelineDuration(session.durationMs),
              style: TextStyle(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
