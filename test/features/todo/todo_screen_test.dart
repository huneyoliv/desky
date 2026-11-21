import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/planner/planner_screen.dart'
    show plannerRepositoryProvider;
import 'package:desky/features/todo/todo_screen.dart';

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: TimerRepository(),
          subjectRepository: SubjectRepository(),
        ) {
    state = const TimerState(
      subjects: [
        SubjectModel(id: 1, title: 'Matemática', colorInt: 4292557552)
      ],
    );
  }

  @override
  Future<void> loadSubjects() async {}

  @override
  Future<void> reconcileWithServer() async {}
}

/// Records the calls the screen makes, so the contract with the API layer is
/// asserted rather than reimplemented.
class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository({this.items = const []});

  List<TodoItemModel> items;
  int fetchCalls = 0;
  final List<String> fetchedDays = [];
  int createCalls = 0;
  int toggleCalls = 0;
  int deleteCalls = 0;
  String? createdTitle;
  bool failCreate = false;

  @override
  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = 5,
  }) async {
    fetchCalls++;
    fetchedDays.add(dateYmd);
    return items;
  }

  @override
  Future<TodoItemModel?> createTodo({
    required String title,
    required String dateYmd,
    required Duration gmtOffset,
    int resetHour = 5,
    int? subjectId,
    dynamic recurrenceRule,
  }) async {
    createCalls++;
    createdTitle = title;
    if (failCreate) return null;
    final created = TodoItemModel(
      id: 99,
      subjectId: null,
      subjectTitle: '',
      subjectColorInt: 0,
      title: title,
      isCompleted: false,
      dateYmd: dateYmd,
      parentId: null,
      recurrenceRule: null,
      startAtRaw: '',
      startAt: null,
    );
    items = [...items, created];
    return created;
  }

  @override
  Future<bool> toggleTodo(
    TodoItemModel todo, {
    required Duration gmtOffset,
    int resetHour = 5,
  }) async {
    toggleCalls++;
    return true;
  }

  @override
  Future<bool> deleteTodo(int todoId, {bool deleteAllSeries = false}) async {
    deleteCalls++;
    items = items.where((t) => t.id != todoId).toList();
    return true;
  }
}

TodoItemModel _todo(int id, String title, {bool done = false}) {
  return TodoItemModel(
    id: id,
    subjectId: null,
    subjectTitle: '',
    subjectColorInt: 0,
    title: title,
    isCompleted: done,
    dateYmd: '2026-11-18',
    parentId: null,
    recurrenceRule: null,
    startAtRaw: '',
    startAt: null,
  );
}

Future<_FakePlannerRepository> _pump(
  WidgetTester tester, {
  List<TodoItemModel> items = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = _FakePlannerRepository(items: items);

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
        timerNotifierProvider.overrideWith((ref) => _OfflineTimerNotifier()),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: const MaterialApp(home: TodoScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return repo;
}

void main() {
  group('TodoScreen', () {
    testWidgets('carrega o dia ativo pela API ao abrir', (tester) async {
      final repo = await _pump(tester);

      expect(repo.fetchCalls, greaterThanOrEqualTo(1));
      expect(repo.fetchedDays, isNotEmpty);
      // Com o idioma pt a chave resolve para 'A fazer'.
      expect(find.text('A fazer'), findsOneWidget);
    });

    testWidgets('lista as tarefas devolvidas pela API', (tester) async {
      await _pump(tester, items: [
        _todo(1, 'Ler capítulo 3'),
        _todo(2, 'Revisar anotações', done: true),
      ]);

      expect(find.text('Ler capítulo 3'), findsOneWidget);
      expect(find.text('Revisar anotações'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('mostra estado vazio claro sem tarefas', (tester) async {
      await _pump(tester);

      expect(find.text('Nenhuma tarefa para este dia'), findsOneWidget);
      expect(find.textContaining('criar a primeira'), findsOneWidget);
    });

    testWidgets('marcar o checkbox chama o toggle da API', (tester) async {
      final repo = await _pump(tester, items: [_todo(1, 'Tarefa')]);
      final before = repo.toggleCalls;

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(repo.toggleCalls, equals(before + 1));
    });

    testWidgets('navegar para o dia anterior busca aquele dia', (tester) async {
      final repo = await _pump(tester);
      final firstDay = repo.fetchedDays.last;

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.fetchedDays.last, isNot(equals(firstDay)));
      expect(repo.fetchedDays.last.compareTo(firstDay), lessThan(0),
          reason: 'o dia anterior precisa ser menor');
    });

    testWidgets('navegar para o dia seguinte avanca a data', (tester) async {
      final repo = await _pump(tester);
      final firstDay = repo.fetchedDays.last;

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.fetchedDays.last.compareTo(firstDay), greaterThan(0));
    });

    testWidgets('criar tarefa envia o titulo para a API', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(find.text('Adicionar tarefa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'Estudar matemática');
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.createCalls, equals(1));
      expect(repo.createdTitle, equals('Estudar matemática'));
    });

    testWidgets('falha ao criar mostra erro e nao fecha em silencio',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _FakePlannerRepository()..failCreate = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plannerRepositoryProvider.overrideWithValue(repo),
            appTranslationProvider.overrideWith(
              (ref) => AppTranslationNotifier(ref)
                ..state = const AppTranslation(languageCode: 'pt'),
            ),
          ],
          child: const MaterialApp(home: TodoScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Adicionar tarefa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'vai falhar');
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // O erro do dialogo e especifico, para nao casar com o aviso da tela.
      expect(find.text('Não foi possível salvar. Tente novamente.'),
          findsOneWidget);
    });

    testWidgets('excluir chama a API', (tester) async {
      final repo = await _pump(tester, items: [_todo(7, 'Apagar')]);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.deleteCalls, equals(1));
    });
  });
}
