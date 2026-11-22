import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/group_member_model.dart';
import 'package:desky/data/repositories/group_repository.dart';
import 'package:desky/features/groups/group_detail_screen.dart';
import 'package:desky/features/groups/widgets/member_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo extends GroupRepository {
  int shakes = 0;
  final member = GroupMemberModel.fromJson({'ud': 10, 'n': 'Colega', 'sm': 3600000, 'sd': 5});

  @override
  Future<List<GroupMemberModel>> fetchGroupRanks(int groupId,
          {String period = 'week', int countryId = 23, int categoryId = 0, DateTime? referenceDate}) async =>
      [GroupMemberModel.fromJson({'ud': 7, 'n': 'Top', 'sm': 9000000, 'sd': 5}), member];

  @override
  Future<bool> shakeMember({required int groupId, required int targetUserId, String from = ''}) async {
    shakes++;
    return true;
  }
}

void main() {
  testWidgets('member card shows weekly rank and sends a nudge', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(repo),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'en'),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: MemberSheet(groupId: 1, member: repo.member))),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Colega'), findsOneWidget);
    expect(find.text('1:00:00'), findsWidgets);
    expect(find.text('#2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('member-nudge')));
    await tester.pump();
    expect(repo.shakes, 1);
    // A sent nudge disables the button so it is not sent twice.
    await tester.tap(find.byKey(const ValueKey('member-nudge')));
    await tester.pump();
    expect(repo.shakes, 1);
  });
}
