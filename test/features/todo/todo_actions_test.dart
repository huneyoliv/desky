import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/planner/planner_screen.dart'
    show plannerRepositoryProvider;
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/todo/todo_screen.dart';

const _subjects = [
  SubjectModel(id: 9, title: 'Física', colorInt: 4292557552),
  SubjectModel(id: 10, title: 'Matemática', colorInt: 4292557552),
];

class _TestTimerNotifier extends TimerNotifier {
  _TestTimerNotifier({
    required super.timerRepository,
    required super.subjectRepository,
  });

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class _FakeTimerRepository extends TimerRepository {
  final List<int?> taskIds = [];

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
    int? taskId,
  }) async {
    taskIds.add(taskId);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> fetchDailyLog(DateTime date) async => null;
}

class _FakeSubjectRepository extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({
    String language = 'pt',
    String timezone = 'UTC',
    int version = 1,
  }) async {
    return const SubjectFetchResult(subjects: _subjects, todayTotalMs: 0);
  }
}

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository({List<TodoItemModel> items = const []})
      : items = List.of(items);

  List<TodoItemModel> items;
  final List<int?> createdSubjectIds = [];
  final List<int?> editedSubjectIds = [];
  final List<bool> updateSubjectFlags = [];
  final List<bool> deleteScopes = [];
  bool failDelete = false;

  @override
  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = 5,
  }) async =>
      items;

  @override
  Future<TodoItemModel?> createTodo({
    required String title,
    required String dateYmd,
    required Duration gmtOffset,
    int resetHour = 5,
    int? subjectId,
    RecurrenceRuleModel? recurrenceRule,
  }) async {
    createdSubjectIds.add(subjectId);
    final created = TodoItemModel(
      id: 100,
      subjectId: subjectId,
      subjectTitle: '',
      subjectColorInt: 0,
      title: title,
      isCompleted: false,
      dateYmd: dateYmd,
    );
    items = [...items, created];
    return created;
  }

  @override
  Future<bool> editTodo(
    TodoItemModel todo,
    String newTitle, {
    required Duration gmtOffset,
    int resetHour = 5,
    RecurrenceRuleModel? recurrenceRule,
    bool applyToAll = false,
    int? subjectId,
    bool updateSubject = false,
  }) async {
    editedSubjectIds.add(subjectId);
    updateSubjectFlags.add(updateSubject);
    return true;
  }

  @override
  Future<bool> deleteTodo(int todoId, {bool deleteAllSeries = false}) async {
    deleteScopes.add(deleteAllSeries);
    if (failDelete) return false;
    items = items.where((todo) => todo.id != todoId).toList();
    return true;
  }
}

TodoItemModel _todo({
  int id = 1,
  int? subjectId,
  bool recurring = false,
  bool completed = false,
}) {
  return TodoItemModel(
    id: id,
    subjectId: subjectId,
    subjectTitle: 'Geral',
    subjectColorInt: 0,
    title: 'Tarefa de teste',
    isCompleted: completed,
    dateYmd: '2026-11-20',
    recurrenceRule: recurring ? const RecurrenceRuleModel() : null,
  );
}

Future<(_FakePlannerRepository, TimerNotifier, _FakeTimerRepository)> _pump(
  WidgetTester tester, {
  _FakePlannerRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = repository ?? _FakePlannerRepository();
  final timerRepo = _FakeTimerRepository();
  final timer = _TestTimerNotifier(
    timerRepository: timerRepo,
    subjectRepository: _FakeSubjectRepository(),
  );
  addTearDown(timer.dispose);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const TodoScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Timer home')),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        plannerRepositoryProvider.overrideWithValue(repo),
        timerNotifierProvider.overrideWith((ref) => timer),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return (repo, timer, timerRepo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('criar envia somente a matéria escolhida explicitamente',
      (tester) async {
    final (repo, _, _) = await _pump(tester);

    await tester.tap(find.text('Adicionar tarefa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Física').last);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Nova com matéria');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.createdSubjectIds, equals([9]));
  });

  testWidgets('renomear sem matéria não cria vínculo e ID ausente é preservado',
      (tester) async {
    final (repo, _, _) = await _pump(
      tester,
      repository: _FakePlannerRepository(items: [_todo(subjectId: null)]),
    );

    await tester.tap(find.text('Tarefa de teste'));
    await tester.pump();
    expect(find.text('Sem matéria'), findsWidgets);
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.editedSubjectIds, equals([null]));
    expect(repo.updateSubjectFlags, equals([true]));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      repository: _FakePlannerRepository(items: [_todo(subjectId: 999)]),
    );
    await tester.tap(find.text('Tarefa de teste'));
    await tester.pump();
    expect(find.text('Matéria 999'), findsOneWidget);
  });

  testWidgets('recorrência oferece excluir somente esta ocorrência',
      (tester) async {
    final (repo, timer, _) = await _pump(
      tester,
      repository: _FakePlannerRepository(items: [_todo(recurring: true)]),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(find.text('Excluir todas as tarefas da série'), findsNothing);
    expect(find.text('Excluir apenas esta tarefa'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.deleteScopes, equals([false]));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    timer.dispose();
  });

  testWidgets('falha ao excluir mantém o item e mostra erro', (tester) async {
    final repo = _FakePlannerRepository(items: [_todo(id: 2)])
      ..failDelete = true;
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.deleteScopes, equals([false]));
    expect(find.textContaining('Não foi possível salvar no servidor'),
        findsWidgets);
    expect(repo.items.map((todo) => todo.id), contains(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    timer.dispose();
  });

  testWidgets('iniciar pela tarefa seleciona matéria, envia id e navega',
      (tester) async {
    final (repo, timer, timerRepo) = await _pump(
      tester,
      repository: _FakePlannerRepository(items: [_todo(subjectId: 9)]),
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(timerRepo.taskIds, equals([1]));
    expect(timer.state.currentSubject?.id, 9);
    expect(timer.state.isRunning, isTrue);
    expect(find.text('Timer home'), findsOneWidget);
    expect(repo.items, isNotEmpty);
  });
}
