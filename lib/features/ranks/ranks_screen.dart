import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/rank_entry_model.dart';
import '../../data/repositories/rank_repository.dart';
import '../../shared/widgets/studicon_avatar.dart';
import '../auth/auth_notifier.dart';
import '../settings/settings_notifier.dart';
import 'widgets/heatmap_grid.dart';
import 'widgets/study_calendar.dart';
import 'widgets/time_of_day_cards.dart';
import 'session_derivations.dart';

final rankRepositoryProvider = Provider<RankRepository>((ref) {
  return RankRepository();
});

class RanksScreen extends ConsumerStatefulWidget {
  const RanksScreen({super.key});

  @override
  ConsumerState<RanksScreen> createState() => _RanksScreenState();
}

/// Ranking scope: true = my category only, false = global/region
enum _RankScope { category, region }

/// Period shown by the per-subject series in the statistics tab.
enum _StatsRange { thisWeek, lastWeek, thisMonth, lastMonth }

class _RanksScreenState extends ConsumerState<RanksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'day';
  _RankScope _rankScope = _RankScope.category;
  int? _myRank;
  List<RankEntryModel> _ranks = [];
  Map<String, double> _subjectDistribution = {};
  _StatsRange _statsRange = _StatsRange.thisWeek;
  Map<String, Map<String, int>> _subjectDailyMs = {};
  bool _isLoadingSeries = true;
  DateTime _calendarMonth = DateTime.now();
  Map<String, int> _calendarStudyMs = {};
  Map<String, List<int>> _hourlyLogs = {};
  /// Sessions of the visible range, used by the time-of-day cards.
  List<StudySession> _sessions = [];
  bool _isLoadingTimeOfDay = true;
  bool _isLoadingRanks = true;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRanks();
    _loadUserStats();
    _loadCalendarMonth();
    _loadHourlyMap();
    _loadSubjectSeries();
    _loadTimeOfDay();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRanks() async {
    setState(() => _isLoadingRanks = true);
    final repo = ref.read(rankRepositoryProvider);
    final user = ref.read(authStateProvider).user;

    // In category mode, filter by the user's category; in region mode use 0 (global).
    final effectiveCategoryId =
        _rankScope == _RankScope.category ? (user?.categoryId ?? 0) : 0;

    // Rank inside the country the user actually picked: the previous hardcoded
    // default showed a Brazilian board even for someone in another country.
    final countryId = ref.read(settingsNotifierProvider).selectedCountry.id;

    final results = await Future.wait([
      repo.fetchGlobalRanks(
        period: _selectedPeriod,
        categoryId: effectiveCategoryId,
        countryId: countryId,
      ),
      repo.fetchMyCategoryRank(
        categoryId: effectiveCategoryId,
        countryId: countryId,
      ),
    ]);

    if (mounted) {
      setState(() {
        _ranks = results[0] as List<RankEntryModel>;
        _myRank = results[1] as int?;
        _isLoadingRanks = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    setState(() => _isLoadingStats = true);
    final user = ref.read(authStateProvider).user;
    if (user == null) {
      if (mounted) setState(() => _isLoadingStats = false);
      return;
    }

    final repo = ref.read(rankRepositoryProvider);
    final now = DateTime.now();
    final firstDayMonth = DateTime(now.year, now.month, 1);
    final lastDayMonth = DateTime(now.year, now.month + 1, 0);

    final startStr = DateFormat('yyyy-MM-dd').format(firstDayMonth);
    final endStr = DateFormat('yyyy-MM-dd').format(lastDayMonth);

    final data = await repo.fetchUserStats(
      userId: user.id,
      startDate: startStr,
      endDate: endStr,
    );

    final rawLogs = data['ls'];
    final subjectMap = <String, double>{};

    if (rawLogs is List) {
      for (final log in rawLogs) {
        if (log is Map<String, dynamic>) {
          final dtStr = log['dt'] as String? ?? '';
          final ms = (log['sm'] as int? ?? 0);
          final hours = ms / 3600000.0;
          if (dtStr.isEmpty) continue;

          // 'sb' lives on each session inside 'ls', never on the day object, so
          // reading it at day level collapsed the whole month into one 'Geral' slice.
          final sessions = log['ls'];
          var attributedToSubject = false;
          if (sessions is List) {
            for (final session in sessions) {
              if (session is! Map<String, dynamic>) continue;
              final subject = (session['sb'] as String? ?? '').trim();
              if (subject.isEmpty) continue;
              final sessionHours = (session['sm'] as int? ?? 0) / 3600000.0;
              subjectMap[subject] = (subjectMap[subject] ?? 0.0) + sessionHours;
              attributedToSubject = true;
            }
          }
          if (!attributedToSubject && hours > 0) {
            subjectMap['Geral'] = (subjectMap['Geral'] ?? 0.0) + hours;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _subjectDistribution = subjectMap;
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadCalendarMonth() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final repo = ref.read(rankRepositoryProvider);
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final byDay = await repo.fetchDailyStudyMs(
      userId: user.id,
      startDate: DateFormat('yyyy-MM-dd').format(firstDay),
      endDate: DateFormat('yyyy-MM-dd').format(lastDay),
    );
    if (mounted) setState(() => _calendarStudyMs = byDay);
  }

  /// Real 24h x 30d map: the previous widget was drawn from a hardcoded day.
  Future<void> _loadHourlyMap() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final repo = ref.read(rankRepositoryProvider);
    final now = DateTime.now();
    final byDay = await repo.fetchHourlyStudyMinutes(
      userId: user.id,
      startDate: DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29))),
      endDate: DateFormat('yyyy-MM-dd').format(now),
    );
    if (mounted) setState(() => _hourlyLogs = byDay);
  }

  /// Sessions of the visible range for the time-of-day cards.
  Future<void> _loadTimeOfDay() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) {
      if (mounted) setState(() => _isLoadingTimeOfDay = false);
      return;
    }
    setState(() => _isLoadingTimeOfDay = true);
    final (start, end) = _statsRangeBounds();
    final repo = ref.read(rankRepositoryProvider);
    final sessions = await repo.fetchStudySessions(
      userId: user.id,
      startDate: DateFormat('yyyy-MM-dd').format(start),
      endDate: DateFormat('yyyy-MM-dd').format(end),
    );
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoadingTimeOfDay = false;
      });
    }
  }

  /// Per-subject series with period navigation, stacked per day.
  Widget _buildSubjectSeriesCard(BuildContext context, AppTranslation t) {
    final (start, end) = _statsRangeBounds();

    final days = <String>[];
    for (var day = DateTime(start.year, start.month, start.day);
        !day.isAfter(DateTime(end.year, end.month, end.day));
        day = day.add(const Duration(days: 1))) {
      days.add(DateFormat('yyyy-MM-dd').format(day));
    }

    final totals = <String, int>{};
    for (final day in days) {
      final buckets = _subjectDailyMs[day];
      if (buckets == null) continue;
      buckets.forEach((subject, ms) {
        totals[subject] = (totals[subject] ?? 0) + ms;
      });
    }

    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const maxSlices = 5;
    final top = ranked.take(maxSlices).map((entry) => entry.key).toList();
    final hasOthers = ranked.length > maxSlices;

    final palette = <Color>[
      context.appPrimary,
      AppColors.flame,
      AppColors.success,
      AppColors.warning,
      context.appAccent,
    ];
    final colorOf = <String, Color>{
      for (var i = 0; i < top.length; i++) top[i]: palette[i % palette.length],
    };
    const othersColor = AppColors.error;

    String labelOf(String key) => key == RankRepository.unknownSubjectKey
        ? t.tr('general', fallback: 'Geral')
        : key;

    var maxHours = 1.0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final buckets = _subjectDailyMs[days[i]] ?? const <String, int>{};
      final stack = <BarChartRodStackItem>[];
      var from = 0.0;

      for (final subject in top) {
        final hours = (buckets[subject] ?? 0) / 3600000.0;
        if (hours <= 0) continue;
        stack.add(BarChartRodStackItem(from, from + hours, colorOf[subject]!));
        from += hours;
      }
      if (hasOthers) {
        var others = 0.0;
        for (final entry in ranked.skip(maxSlices)) {
          others += (buckets[entry.key] ?? 0) / 3600000.0;
        }
        if (others > 0) {
          stack.add(BarChartRodStackItem(from, from + others, othersColor));
          from += others;
        }
      }
      if (from > maxHours) maxHours = from;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: from,
            width: days.length > 15 ? 7 : 20,
            rodStackItems: stack,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ));
    }

    final hasData = totals.isNotEmpty;
    final weekdayNames = [
      t.tr('day_mon_short', fallback: 'Seg'),
      t.tr('day_tue_short', fallback: 'Ter'),
      t.tr('day_wed_short', fallback: 'Qua'),
      t.tr('day_thu_short', fallback: 'Qui'),
      t.tr('day_fri_short', fallback: 'Sex'),
      t.tr('day_sat_short', fallback: 'Sáb'),
      t.tr('day_sun_short', fallback: 'Dom'),
    ];

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.tr('analytics_stacked_bar_subject_name', fallback: 'Tempo de estudo por matéria'),
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 10),
            // Period navigation: any week or month, including the past ones.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _StatsRange.values.map((range) {
                final selected = _statsRange == range;
                return ChoiceChip(
                  label: Text(
                    _statsRangeLabel(range, t),
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white : context.appTextMuted,
                    ),
                  ),
                  selected: selected,
                  selectedColor: context.appPrimary,
                  backgroundColor: context.appCard,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    if (_statsRange == range) return;
                    setState(() => _statsRange = range);
                    _loadSubjectSeries();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoadingSeries
                  ? const Center(child: CircularProgressIndicator())
                  : !hasData
                      ? Center(
                          child: Text(
                            t.tr('no_study_records', fallback: 'Nenhum registro de estudo'),
                            style: TextStyle(color: context.appTextSecondary),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxHours * 1.2,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= days.length) {
                                      return const Text('');
                                    }
                                    final date = DateTime.parse(days[index]);
                                    if (days.length <= 7) {
                                      return Text(
                                        weekdayNames[(date.weekday - 1) % 7],
                                        style: TextStyle(
                                            color: context.appTextSecondary,
                                            fontSize: 12),
                                      );
                                    }
                                    // Only some day numbers, to stay readable.
                                    if (date.day % 5 != 0 &&
                                        index != days.length - 1 &&
                                        date.day != 1) {
                                      return const Text('');
                                    }
                                    return Text(
                                      '${date.day}',
                                      style: TextStyle(
                                          color: context.appTextSecondary,
                                          fontSize: 11),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: groups,
                          ),
                        ),
            ),
            if (hasData && top.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final subject in top)
                    _seriesLegendItem(context, labelOf(subject), colorOf[subject]!),
                  if (hasOthers)
                    _seriesLegendItem(
                        context, t.tr('others', fallback: 'Outros'), othersColor),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seriesLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: context.appTextSecondary, fontSize: 11),
        ),
      ],
    );
  }

  /// Start and end dates of the period currently selected in the series.
  (DateTime, DateTime) _statsRangeBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    switch (_statsRange) {
      case _StatsRange.thisWeek:
        return (monday, monday.add(const Duration(days: 6)));
      case _StatsRange.lastWeek:
        final last = monday.subtract(const Duration(days: 7));
        return (last, last.add(const Duration(days: 6)));
      case _StatsRange.thisMonth:
        return (DateTime(today.year, today.month, 1),
            DateTime(today.year, today.month + 1, 0));
      case _StatsRange.lastMonth:
        return (DateTime(today.year, today.month - 1, 1),
            DateTime(today.year, today.month, 0));
    }
  }

  String _statsRangeLabel(_StatsRange range, AppTranslation t) {
    switch (range) {
      case _StatsRange.thisWeek:
        return t.tr('analytics_stairs_info_this_week', fallback: 'Esta semana');
      case _StatsRange.lastWeek:
        return t.tr('analytics_stairs_info_last_week', fallback: 'Semana passada');
      case _StatsRange.thisMonth:
        return t.tr('analytics_stairs_info_this_month', fallback: 'Este mês');
      case _StatsRange.lastMonth:
        return t.tr('analytics_stairs_info_last_month', fallback: 'Mês passado');
    }
  }

  Future<void> _loadSubjectSeries() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    setState(() => _isLoadingSeries = true);

    final repo = ref.read(rankRepositoryProvider);
    final (start, end) = _statsRangeBounds();
    final byDay = await repo.fetchSubjectDailyMs(
      userId: user.id,
      startDate: DateFormat('yyyy-MM-dd').format(start),
      endDate: DateFormat('yyyy-MM-dd').format(end),
    );

    if (mounted) {
      setState(() {
        _subjectDailyMs = byDay;
        _isLoadingSeries = false;
      });
    }
  }

  String _formatMs(int ms) {
    final mins = ms ~/ 60000;
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m';
  }

  Widget _buildPodiumItem({
    required RankEntryModel member,
    required String badgeImage,
    required double height,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              StudiconAvatar(studiconId: member.studiconId, size: 70),
              Image.asset(badgeImage, width: 28, height: 28,
                  errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events,
                      color: Colors.amber, size: 24)),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: member.userName,
            child: Text(
              member.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatMs(member.studyMs),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Container(
            width: 100,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: color),
            ),
            child: Center(
              child: Text(
                '#${member.rank}',
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      context.appPrimary,
      AppColors.flame,
      AppColors.success,
      AppColors.warning,
      context.appAccent,
    ];

    double totalSubjectHours = _subjectDistribution.values.fold(0.0, (a, b) => a + b);
    if (totalSubjectHours == 0) totalSubjectHours = 1.0;

    int colorIdx = 0;
    final pieSections = _subjectDistribution.entries.map((e) {
      final percentage = (e.value / totalSubjectHours * 100).round();
      final color = colors[colorIdx % colors.length];
      colorIdx++;
      return PieChartSectionData(
        color: color,
        value: e.value > 0 ? e.value : 1,
        title: '$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(t.tr('ranks', fallback: 'Rankings & Estatísticas'), style: AppTextStyles.titleLarge),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: palette.primary,
          labelColor: Colors.white,
          unselectedLabelColor: palette.textSecondary,
          tabs: [
            Tab(text: t.tr('ranks', fallback: 'Rankings Globais')),
            Tab(text: t.tr('stats', fallback: 'Estatísticas & Mapa 24h')),
            Tab(text: t.tr('calendar', fallback: 'Calendário Mensal')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Global Rankings & Podium
          Column(
            children: [
              // Period Selector Bar & Scope Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: context.appSurface,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(t.tr('today', fallback: 'Hoje')),
                      selected: _selectedPeriod == 'day',
                      selectedColor: context.appPrimary,
                      backgroundColor: context.appCard,
                      labelStyle: TextStyle(
                          color: _selectedPeriod == 'day' ? Colors.white : context.appTextMuted),
                      onSelected: (_) {
                        setState(() => _selectedPeriod = 'day');
                        _loadRanks();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(t.tr('this_week', fallback: 'Esta Semana')),
                      selected: _selectedPeriod == 'week',
                      selectedColor: context.appPrimary,
                      backgroundColor: context.appCard,
                      labelStyle: TextStyle(
                          color: _selectedPeriod == 'week' ? Colors.white : context.appTextMuted),
                      onSelected: (_) {
                        setState(() => _selectedPeriod = 'week');
                        _loadRanks();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(t.tr('this_month', fallback: 'Este Mês')),
                      selected: _selectedPeriod == 'month',
                      selectedColor: context.appPrimary,
                      backgroundColor: context.appCard,
                      labelStyle: TextStyle(
                          color: _selectedPeriod == 'month'
                              ? Colors.white
                              : context.appTextMuted),
                      onSelected: (_) {
                        setState(() => _selectedPeriod = 'month');
                        _loadRanks();
                      },
                    ),
                    const Spacer(),
                    _ScopeToggle(
                      scope: _rankScope,
                      categoryName: ref.watch(authStateProvider).user?.categoryName ?? '',
                      onChanged: (scope) {
                        setState(() => _rankScope = scope);
                        _loadRanks();
                      },
                    ),
                    const SizedBox(width: 12),
                    if (_myRank != null && _myRank! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.appPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.appPrimary),
                        ),
                        child: Text(
                          '${t.tr("my_position", fallback: "Minha Posição")}: #$_myRank',
                          style: TextStyle(
                            color: context.appPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingRanks
                    ? const Center(child: CircularProgressIndicator())
                    : _ranks.isEmpty
                        ? Center(
                            child: Text(t.tr('no_ranks', fallback: 'Nenhum ranking disponível no momento.'),
                                style: TextStyle(color: context.appTextSecondary)),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(32),
                            children: [
                              if (_ranks.length >= 3)
                                SizedBox(
                                  height: 290,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _buildPodiumItem(
                                        member: _ranks[1],
                                        badgeImage: 'assets/images/ic_silver.png',
                                        height: 110,
                                        color: const Color(0xFFC0C0C0),
                                      ),
                                      const SizedBox(width: 24),
                                      _buildPodiumItem(
                                        member: _ranks[0],
                                        badgeImage: 'assets/images/ic_gold.png',
                                        height: 140,
                                        color: const Color(0xFFFFD700),
                                      ),
                                      const SizedBox(width: 24),
                                      _buildPodiumItem(
                                        member: _ranks[2],
                                        badgeImage: 'assets/images/ic_bronze.png',
                                        height: 90,
                                        color: const Color(0xFFCD7F32),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 32),

                              Text(t.tr('ranking', fallback: 'Top Estudantes'), style: AppTextStyles.titleMedium),
                              const SizedBox(height: 12),

                              ..._ranks.skip(3).map((rank) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: context.appCard,
                                  child: ListTile(
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '#${rank.rank}',
                                            style: TextStyle(
                                              color: context.appTextMuted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StudiconAvatar(
                                          studiconId: rank.studiconId,
                                          size: 36,
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                       rank.userName,
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                       style: TextStyle(
                                         color: context.appTextPrimary,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                    subtitle: Text(rank.categoryName,
                                        style: TextStyle(
                                            color: context.appTextSecondary,
                                            fontSize: 12)),
                                    trailing: Text(
                                      _formatMs(rank.studyMs),
                                      style: TextStyle(
                                        color: context.appPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
              ),
            ],
          ),

          // Tab 2: Statistics & fl_chart Graphs
          _isLoadingStats
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 380,
                        child: Row(
                          children: [
                            // Per-subject series with period navigation
                            _buildSubjectSeriesCard(context, t),
                            const SizedBox(width: 24),

                            // Subject Distribution Pie Chart
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: context.appCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.appBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.tr('subject_distribution', fallback: 'Distribuição por Matéria'),
                                      style: AppTextStyles.titleMedium,
                                    ),
                                    const SizedBox(height: 24),
                                    Expanded(
                                      child: pieSections.isEmpty
                                          ? Center(
                                              child: Text(
                                                t.tr('no_data', fallback: 'Nenhum dado registrado esta semana.'),
                                                style: TextStyle(
                                                    color: context.appTextSecondary),
                                              ),
                                            )
                                          : PieChart(
                                              PieChartData(
                                                sectionsSpace: 4,
                                                centerSpaceRadius: 50,
                                                sections: pieSections,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Time of day: average start/end, regularity and the
                      // start-against-end scatter.
                      if (_isLoadingTimeOfDay)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 900;
                            final avg = AvgTimesCard(
                              stats: TimeOfDayStats.fromSessions(_sessions),
                            );
                            final scatter = SessionScatterCard(
                              points: scatterPoints(_sessions),
                            );
                            if (!wide) {
                              return Column(
                                children: [
                                  avg,
                                  const SizedBox(height: 24),
                                  scatter,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: avg),
                                const SizedBox(width: 24),
                                Expanded(child: scatter),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 24),

                      // 24h Heatmap Component
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.appCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.appBorder),
                        ),
                        child: HeatmapGrid(hourlyLogs: _hourlyLogs),
                      ),
                    ],
                  ),
                ),

          // Tab 3: Monthly Study Calendar
          SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appBorder),
              ),
              child: StudyCalendar(
                dailyStudyTimeMs: _calendarStudyMs,
                month: _calendarMonth,
                onMonthChanged: (month) {
                  setState(() => _calendarMonth = month);
                  _loadCalendarMonth();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeToggle extends ConsumerWidget {
  final _RankScope scope;
  final String categoryName;
  final ValueChanged<_RankScope> onChanged;

  const _ScopeToggle({
    required this.scope,
    required this.categoryName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final catLabel = categoryName.trim().isNotEmpty
        ? categoryName.trim()
        : t.tr('my_category', fallback: 'Minha Categoria');

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context,
            isSelected: scope == _RankScope.category,
            icon: Icons.school_rounded,
            label: catLabel,
            onTap: () => onChanged(_RankScope.category),
          ),
          const SizedBox(width: 2),
          _buildOption(context,
            isSelected: scope == _RankScope.region,
            icon: Icons.public_rounded,
            label: t.tr('region_scope', fallback: 'Região'),
            onTap: () => onChanged(_RankScope.region),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, {
    required bool isSelected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.appPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

