import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/group_model.dart';
import 'package:desky/data/repositories/group_admin_repository.dart';
import 'package:desky/features/groups/group_leader_panel.dart';

class _FakeAdminRepository extends GroupAdminRepository {
  _FakeAdminRepository({required this.updateSucceeds});

  final bool updateSucceeds;
  final List<String> updated = [];

  @override
  Future<List<Map<String, dynamic>>> fetchBannedList(int groupId) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchJoinRequests(int groupId) async => [];

  @override
  Future<bool> updateGroupName(int groupId, String name) async {
    updated.add('name');
    return updateSucceeds;
  }

  @override
  Future<bool> updateGroupCapacity(int groupId, int capacity) async {
    updated.add('capacity');
    return updateSucceeds;
  }

  @override
  Future<bool> updateGroupGoal(int groupId, int goalHours) async {
    updated.add('goal');
    return updateSucceeds;
  }

  @override
  Future<bool> updateNotice(int groupId, String notice) async {
    updated.add('notice');
    return updateSucceeds;
  }

  @override
  Future<bool> updateGroupPassword(int groupId, String password) async {
    updated.add('password');
    return updateSucceeds;
  }
}

const _group = GroupModel(
  id: 42,
  name: 'Grupo Teste',
  category: 'Geral',
  dailyGoalHours: 8,
  membersCount: 3,
  maxCapacity: 50,
  isPrivate: false,
  leaderName: 'Líder',
);

Future<void> _pumpPanel(WidgetTester tester, GroupAdminRepository repository) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
        groupAdminRepoProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(body: GroupLeaderPanel(group: _group, members: const [])),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _saveWithNewName(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Nome do Grupo'), 'Novo Nome');
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar Alterações'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('reports failure instead of success when a setting update fails', (tester) async {
    final repository = _FakeAdminRepository(updateSucceeds: false);
    await _pumpPanel(tester, repository);

    await _saveWithNewName(tester);

    expect(repository.updated, contains('name'));
    expect(find.textContaining('Falha ao salvar'), findsOneWidget);
    expect(find.textContaining('Configurações atualizadas com sucesso'), findsNothing);
  });

  testWidgets('reports success when every attempted update succeeds', (tester) async {
    final repository = _FakeAdminRepository(updateSucceeds: true);
    await _pumpPanel(tester, repository);

    await _saveWithNewName(tester);

    expect(repository.updated, contains('name'));
    expect(find.textContaining('Configurações atualizadas com sucesso'), findsOneWidget);
    expect(find.textContaining('Falha ao salvar'), findsNothing);
  });
}
