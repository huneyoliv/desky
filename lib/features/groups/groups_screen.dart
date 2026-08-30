import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/category_model.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_repository.dart';
import '../auth/auth_notifier.dart';
import '../settings/settings_notifier.dart';
import 'group_detail_screen.dart';

final groupRepoProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  List<GroupModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  List<GroupModel> _exploreGroups = [];
  bool _isLoadingExplore = false;
  int _selectedCategoryIndex = 0;
  final String _selectedOrderType = 'promotedAt';

  List<Map<String, dynamic>> _getCategories(List<CategoryModel> countryCategories, AppTranslation t) {
    return [
      {'id': 0, 'name': t.tr('all', fallback: 'Todos')},
      ...countryCategories.map((c) => {
            'id': c.id,
            'name': c.shortTitle.isNotEmpty ? c.shortTitle : c.title,
          }),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).refreshUserGroups();
    });
    _loadExploreGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExploreGroups() async {
    setState(() {
      _isLoadingExplore = true;
    });

    try {
      final repo = ref.read(groupRepoProvider);
      final countryCats = ref.read(settingsNotifierProvider).countryCategories;
      final t = ref.read(appTranslationProvider);
      final categories = _getCategories(countryCats, t);
      final safeIndex = _selectedCategoryIndex < categories.length ? _selectedCategoryIndex : 0;
      final catId = categories[safeIndex]['id'] as int;
      final results = await repo.fetchExploreGroups(
        categoryId: catId,
        orderType: _selectedOrderType,
      );
      if (mounted) {
        setState(() {
          _exploreGroups = results;
          _isLoadingExplore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _exploreGroups = [];
          _isLoadingExplore = false;
        });
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _searchResults = [];
      });
      _loadExploreGroups();
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final repo = ref.read(groupRepoProvider);
      final countryCats = ref.read(settingsNotifierProvider).countryCategories;
      final t = ref.read(appTranslationProvider);
      final categories = _getCategories(countryCats, t);
      final safeIndex = _selectedCategoryIndex < categories.length ? _selectedCategoryIndex : 0;
      final catId = categories[safeIndex]['id'] as int;
      final results = await repo.searchGroups(query, categoryId: catId);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _handleJoinGroup(GroupModel group, AppTranslation t) async {
    final repo = ref.read(groupRepoProvider);
    final user = ref.read(authStateProvider).user;

    String? password;
    if (group.isPrivate) {
      final passController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(t.tr('join_private_group', fallback: 'Grupo Privado'), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('enter_group_password', fallback: 'Este grupo requer senha para entrada:'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: t.tr('password', fallback: 'Senha do Grupo'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.tr('cancel', fallback: 'Cancelar'), style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(t.tr('join', fallback: 'Entrar'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      password = passController.text.trim();
    }

    final success = await repo.joinGroup(
      group.id,
      nickname: user?.nickname ?? 'Estudante',
      studiconId: user?.avatarStudiconId,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.tr("joined_group_success", fallback: "Você entrou no grupo")} ${group.name}!'),
          backgroundColor: AppColors.success,
        ),
      );
      await ref.read(authStateProvider.notifier).refreshUserGroups();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupDetailScreen(group: group),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('join_group_error', fallback: 'Não foi possível entrar no grupo. Verifique a senha ou a capacidade.')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildGroupCard(GroupModel group, AppTranslation t, {bool isMyGroup = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (group.isCamStudy ? AppColors.accent : AppColors.primary).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            group.isCamStudy ? Icons.videocam_rounded : Icons.group_work_rounded,
            color: group.isCamStudy ? AppColors.accent : AppColors.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (group.isPrivate) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock_rounded, size: 16, color: AppColors.warning),
            ],
            if (group.isCamStudy) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.tr('live_study', fallback: 'LIVE STUDY').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${group.category} • ${group.membersCount}/${group.maxCapacity} ${t.tr("members", fallback: "membros")} • ${t.tr("goal", fallback: "Meta")}: ${group.dailyGoalHours}h/${t.tr("today", fallback: "dia")}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (group.notice != null && group.notice!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  group.notice!.trim(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            if (isMyGroup) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GroupDetailScreen(group: group),
                ),
              );
              if (mounted) {
                ref.read(authStateProvider.notifier).refreshUserGroups();
              }
            } else {
              await _handleJoinGroup(group, t);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isMyGroup ? AppColors.surface : AppColors.primary,
            side: isMyGroup ? const BorderSide(color: AppColors.border) : null,
          ),
          child: Text(
            isMyGroup
                ? t.tr('open', fallback: 'Abrir')
                : t.tr('join', fallback: 'Entrar'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myGroups = ref.watch(authStateProvider).user?.userGroups ?? [];
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.tr('groups', fallback: 'Grupos de Estudo'), style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t.tr('refresh', fallback: 'Atualizar'),
            onPressed: () {
              ref.read(authStateProvider.notifier).refreshUserGroups();
              if (_tabController.index == 1) {
                if (_hasSearched) {
                  _performSearch();
                } else {
                  _loadExploreGroups();
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: t.tr('my_groups', fallback: 'Meus Grupos')),
            Tab(text: t.tr('explore', fallback: 'Explorar Grupos')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: My Groups
          myGroups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.group_off_rounded,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          t.tr('no_groups', fallback: 'Você não participa de nenhum grupo de estudos no momento.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(authStateProvider.notifier).refreshUserGroups();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: myGroups.length,
                    itemBuilder: (context, index) {
                      return _buildGroupCard(myGroups[index], t, isMyGroup: true);
                    },
                  ),
                ),

          // Tab 2: Browse & Search
          RefreshIndicator(
            onRefresh: () async {
              if (_hasSearched) {
                await _performSearch();
              } else {
                await _loadExploreGroups();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: t.tr('search', fallback: 'Buscar grupos por nome ou palavra-chave...'),
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppColors.textMuted),
                                    onPressed: () {
                                      _searchController.clear();
                                      _performSearch();
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.search, size: 18, color: Colors.white),
                        label: Text(t.tr('search', fallback: 'Buscar'), style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Builder(
                      builder: (context) {
                        final countryCats = ref.watch(settingsNotifierProvider).countryCategories;
                        final categories = _getCategories(countryCats, t);
                        final safeIndex = _selectedCategoryIndex < categories.length ? _selectedCategoryIndex : 0;
                        return Row(
                          children: List.generate(categories.length, (index) {
                            final cat = categories[index];
                            final isSelected = safeIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat['name'] as String),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.card,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedCategoryIndex = index;
                                    });
                                    if (_hasSearched) {
                                      _performSearch();
                                    } else {
                                      _loadExploreGroups();
                                    }
                                  }
                                },
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Groups List
                  Expanded(
                    child: (_isSearching || _isLoadingExplore)
                        ? const Center(child: CircularProgressIndicator())
                        : _hasSearched
                            ? _searchResults.isEmpty
                                ? Center(
                                    child: Text(
                                      t.tr('no_results', fallback: 'Nenhum grupo encontrado para sua busca.'),
                                      style: const TextStyle(color: AppColors.textSecondary),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final isMine = myGroups.any((g) => g.id == _searchResults[index].id);
                                      return _buildGroupCard(_searchResults[index], t, isMyGroup: isMine);
                                    },
                                  )
                            : _exploreGroups.isEmpty
                                ? Center(
                                    child: Text(
                                      t.tr('no_groups_found', fallback: 'Nenhum grupo disponível para explorar no momento.'),
                                      style: const TextStyle(color: AppColors.textSecondary),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _exploreGroups.length,
                                    itemBuilder: (context, index) {
                                      final isMine = myGroups.any((g) => g.id == _exploreGroups[index].id);
                                      return _buildGroupCard(_exploreGroups[index], t, isMyGroup: isMine);
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
