import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/group_model.dart';
import '../auth/auth_notifier.dart';

/// The user's own order of "My groups", set by drag and drop and saved on
/// this device. Groups not in the saved order (newly joined) keep the API's
/// order after the arranged ones.
class GroupOrderNotifier extends StateNotifier<List<int>> {
  GroupOrderNotifier({SharedPreferences? prefs})
      : _prefs = prefs,
        super(const []) {
    _load();
  }

  static const String storageKey = 'my_groups_order';
  final SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async => _prefs ?? await SharedPreferences.getInstance();

  Future<void> _load() async {
    try {
      final saved = (await _p()).getStringList(storageKey);
      if (saved != null && mounted) state = [for (final s in saved) int.tryParse(s)].whereType<int>().toList();
    } catch (_) {}
  }

  /// Moves the group at [oldIndex] of [current] to [newIndex] (indices as
  /// given by `ReorderableListView.onReorder`) and saves the new order.
  Future<void> move(List<GroupModel> current, int oldIndex, int newIndex) async {
    final ids = [for (final g in current) g.id];
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), id);
    state = ids;
    try {
      await (await _p()).setStringList(storageKey, [for (final i in ids) '$i']);
    } catch (_) {}
  }
}

/// Applies [order] to [groups]: arranged ones first, the rest as they came.
List<GroupModel> applyGroupOrder(List<GroupModel> groups, List<int> order) {
  if (order.isEmpty) return groups;
  final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
  final indexed = [for (var i = 0; i < groups.length; i++) (i, groups[i])];
  indexed.sort((a, b) {
    final ra = rank[a.$2.id], rb = rank[b.$2.id];
    if (ra != null && rb != null) return ra.compareTo(rb);
    if (ra != null) return -1;
    if (rb != null) return 1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

final groupOrderProvider = StateNotifierProvider<GroupOrderNotifier, List<int>>((ref) => GroupOrderNotifier());

/// "My groups" in the user's order, used by the group list and the timer.
final orderedMyGroupsProvider = Provider<List<GroupModel>>((ref) {
  final groups = ref.watch(authStateProvider.select((s) => s.user?.userGroups)) ?? const <GroupModel>[];
  return applyGroupOrder(groups, ref.watch(groupOrderProvider));
});
