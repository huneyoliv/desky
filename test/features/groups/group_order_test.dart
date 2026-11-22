import 'package:desky/data/models/group_model.dart';
import 'package:desky/features/groups/group_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GroupModel g(int id) => GroupModel(
      id: id,
      name: 'G$id',
      category: 'UPSC',
      dailyGoalHours: 6,
      membersCount: 1,
      maxCapacity: 50,
      isPrivate: false,
      leaderName: 'L',
    );

void main() {
  test('saved order first, newly joined groups after, missing ones ignored', () {
    final ordered = applyGroupOrder([g(1), g(2), g(3), g(4)], [3, 99, 1]);
    expect(ordered.map((e) => e.id), [3, 1, 2, 4]);
    expect(applyGroupOrder([g(1), g(2)], const []).map((e) => e.id), [1, 2]);
  });

  test('dragging moves a group and the order survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final groups = [g(1), g(2), g(3)];
    final n = GroupOrderNotifier(prefs: prefs);
    await n.move(groups, 2, 0); // drag G3 to the top
    expect(n.state, [3, 1, 2]);
    await n.move(applyGroupOrder(groups, n.state), 0, 3); // and to the bottom
    expect(n.state, [1, 2, 3]);

    final again = GroupOrderNotifier(prefs: prefs);
    await Future<void>.delayed(Duration.zero);
    expect(again.state, [1, 2, 3]);
  });
}
