import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/utils/study_day_helper.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/planner/planner_screen.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/settings_state.dart';
import 'package:desky/data/models/country_model.dart';
import 'package:desky/features/timer/timer_notifier.dart';

const _subjects = [
  SubjectModel(id: 9, title: 'Física', colorInt: 4292557552),
  SubjectModel(id: 10, title: 'Matemática', colorInt: 4292557552),
];

class FakePlannerRepository extends PlannerRepository {
  final List<DDayModel> mockDDays;
  final List<TodoItemModel> mockTodos;

  /// Copia mutavel de [mockTodos]: as acoes de criar/excluir mexem nesta lista.
  List<TodoItemModel> items;

  FakePlannerRepository({
    this.mockDDays = const [],
    this.mockTodos = const [],
  }) : items = List.of(mockTodos);

  @override
  Future<List<DDayModel>> fetchDDays() async {
    if (failLoad) throw StateError('load failed');
    return mockDDays;
  }

  @override
  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async {
    if (failLoad) throw StateError('load failed');
    requestedDates.add(dateYmd);
    resetHours.add(resetHour);
    gmtOffsets.add(gmtOffset);
    return items;
  }

  final List<String> createdTitles = [];
  final List<DateTime> createdDates = [];
  final List<int> deletedIds = [];
  bool createReturnsNull = false;
  bool deleteReturnsFalse = false;

  // Gravacoes feitas pelas acoes de tarefa, na ordem em que aconteceram.
  final List<String> requestedDates = [];
  final List<int> resetHours = [];
  final List<int> toggledIds = [];
  final List<Duration> gmtOffsets = [];
  bool failLoad = false;
  bool failToggle = false;

  final List<int?> createdSubjectIds = [];
  final List<int?> editedSubjectIds = [];
  final List<bool> updateSubjectFlags = [];
  final List<bool> deleteScopes = [];
  bool failCreate = false;
  bool failEdit = false;
  bool failDelete = false;

  @override
  Future<TodoItemModel?> createTodo({
    required String title,
    required String dateYmd,
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
    int? subjectId,
    RecurrenceRuleModel? recurrenceRule,
  }) async {
    createdSubjectIds.add(subjectId);
    if (failCreate) return null;
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
    int resetHour = StudyDayHelper.defaultResetHour,
    RecurrenceRuleModel? recurrenceRule,
    bool applyToAll = false,
    int? subjectId,
    bool updateSubject = false,
  }) async {
    editedSubjectIds.add(subjectId);
    updateSubjectFlags.add(updateSubject);
    return !failEdit;
  }

  @override
  Future<bool> deleteTodo(int todoId, {bool deleteAllSeries = false}) async {
    deleteScopes.add(deleteAllSeries);
    if (failDelete) return false;
    items = items.where((todo) => todo.id != todoId).toList();
    return true;
  }

  @override
  Future<DDayModel?> createDDay({
    required String title,
    required DateTime targetDate,
    required int colorInt,
  }) async {
    createdTitles.add(title);
    createdDates.add(targetDate);
    if (createReturnsNull) return null;
    return DDayModel(
      id: 777,
      title: title,
      targetDate: targetDate,
      colorInt: colorInt,
    );
  }

  @override
  Future<bool> deleteDDay(int ddayId) async {
    deletedIds.add(ddayId);
    return !deleteReturnsFalse;
  }

  @override
  Future<bool> toggleTodo(
    TodoItemModel todo, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async {
    toggledIds.add(todo.id);
    if (failToggle) return false;
    items = items
        .map(
          (current) => current.id == todo.id
              ? current.copyWith(isCompleted: !current.isCompleted)
              : current,
        )
        .toList();
    return true;
  }
}

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
  bool startAccepted = true;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
    int? taskId,
  }) async {
    taskIds.add(taskId);
    return startAccepted;
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

/// Desmonta a arvore e encerra o notifier antes do fim do teste.
///
/// O [TimerNotifier] agenda um [Timer.periodic] de 10s no construtor. O
/// flutter_test verifica timers pendentes assim que o teste termina, antes dos
/// tearDowns, entao precisamos cancelar aqui dentro.
Future<void> _disposeTimer(WidgetTester tester, TimerNotifier timer) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  timer.dispose();
}

Future<(FakePlannerRepository, TimerNotifier, _FakeTimerRepository)> _pump(
  WidgetTester tester, {
  FakePlannerRepository? repository,
  SettingsNotifier? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = repository ?? FakePlannerRepository();
  final timerRepo = _FakeTimerRepository();
  final timer = _TestTimerNotifier(
    timerRepository: timerRepo,
    subjectRepository: _FakeSubjectRepository(),
  );
  addTearDown(timer.dispose);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PlannerScreen()),
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
        if (settings != null)
          settingsNotifierProvider.overrideWith((ref) => settings),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return (repo, timer, timerRepo);
}

class _DaySettingsNotifier extends SettingsNotifier {
  _DaySettingsNotifier(super.repository);

  @override
  Future<void> init() async {}
}

void main() {
  testWidgets('PlannerScreen renders D-Days and To-Do list items',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ddays = [
      DDayModel(
        id: 1,
        title: 'Vestibular',
        targetDate: DateTime.now().add(const Duration(days: 20)),
        colorInt: 4294948685,
      ),
    ];

    final todos = <TodoItemModel>[
      const TodoItemModel(
        id: 101,
        title: 'Resolver 30 questões de Matemática',
        subjectTitle: 'Matemática',
        subjectColorInt: 4292557552,
        dateYmd: '2026-08-17',
        isCompleted: false,
      ),
    ];

    final repo = FakePlannerRepository(mockDDays: ddays, mockTodos: todos);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const PlannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Vestibular'), findsOneWidget);
    expect(find.text('Calendário'), findsOneWidget);
    expect(find.text('Resolver 30 questões de Matemática'), findsOneWidget);
  });

  testWidgets('o painel esquerdo preenche a altura da aba, sem faixa vazia',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const PlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tabView = tester.getRect(find.byType(TabBarView));

    // O painel lateral tem largura fixa; sem crossAxisAlignment.stretch ele ficava
    // centralizado na vertical e sobrava uma faixa vazia acima dos D-Days e abaixo
    // do calendario.
    Rect? sidebar;
    for (final element in find
        .ancestor(
            of: find.byType(CalendarDatePicker),
            matching: find.byType(Container))
        .evaluate()) {
      final box = element.renderObject as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.width > 300 && rect.width < 420) sidebar = rect;
    }

    expect(sidebar, isNotNull, reason: 'o painel lateral precisa existir');
    expect(sidebar!.top, closeTo(tabView.top, 1.0));
    expect(sidebar.height, closeTo(tabView.height, 1.0));
    expect(sidebar.bottom, closeTo(tabView.bottom, 1.0));
  });

  testWidgets('tapping Adicionar actually creates the D-Day', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakePlannerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const PlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The old dialog only called pop(), so nothing was ever sent.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'Prova Final',
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(ElevatedButton, 'Adicionar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.createdTitles, equals(['Prova Final']));
    expect(repo.createdDates, hasLength(1));
    expect(repo.createdDates.first.year, greaterThanOrEqualTo(2020));
  });

  testWidgets('a refused D-Day creation is reported, not faked',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakePlannerRepository()..createReturnsNull = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const PlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'Vai falhar',
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(ElevatedButton, 'Adicionar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.createdTitles, equals(['Vai falhar']));
    expect(
      find.text('Não foi possível criar o D-Day'),
      findsOneWidget,
      reason: 'a falha precisa ser visível ao usuário',
    );
  });

  testWidgets('long-press deletes a D-Day after confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakePlannerRepository(
      mockDDays: [
        DDayModel(
          id: 42,
          title: 'Vestibular',
          targetDate: DateTime.now().add(const Duration(days: 30)),
          colorInt: 4294948685,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const PlannerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Vestibular'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, equals([42]));
  });

  testWidgets('criar tarefa envia somente a materia escolhida explicitamente',
      (tester) async {
    final (repo, timer, _) = await _pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Física').last);
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Nova com matéria',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Adicionar'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.createdSubjectIds, equals([9]));
    await _disposeTimer(tester, timer);
  });

  testWidgets('editar sem materia nao cria vinculo e ID ausente e preservado',
      (tester) async {
    final (repo, timer, _) = await _pump(
      tester,
      repository: FakePlannerRepository(mockTodos: [_todo(subjectId: null)]),
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    expect(find.text('Sem matéria'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Salvar'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.editedSubjectIds, equals([null]));
    expect(repo.updateSubjectFlags, equals([true]));

    await tester.pumpWidget(const SizedBox.shrink());
    final (_, secondTimer, _) = await _pump(
      tester,
      repository: FakePlannerRepository(mockTodos: [_todo(subjectId: 999)]),
    );
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    // A materia 999 nao veio na lista atual: mesmo assim precisa aparecer
    // selecionada, senao a edicao trocaria a associacao sem avisar.
    expect(find.text('Matéria 999'), findsOneWidget);
    await _disposeTimer(tester, secondTimer);
    timer.dispose();
  });

  testWidgets('tarefa recorrente avisa que so esta ocorrencia sera excluida',
      (tester) async {
    final (repo, timer, _) = await _pump(
      tester,
      repository: FakePlannerRepository(mockTodos: [_todo(recurring: true)]),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    // A serie foi reexposta depois da prova live; a ocorrencia continua
    // selecionada por padrao para evitar uma delecao ampliada acidental.
    expect(find.text('Excluir todas as tarefas da série'), findsOneWidget);
    expect(
      find.textContaining('Apenas esta ocorrência será excluída'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Excluir'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.deleteScopes, equals([false]));
    await _disposeTimer(tester, timer);
  });

  testWidgets('tarefa recorrente permite excluir a serie apos validacao live',
      (tester) async {
    final (repo, timer, _) = await _pump(
      tester,
      repository: FakePlannerRepository(mockTodos: [_todo(recurring: true)]),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.text('Excluir todas as tarefas da série'));
    await tester.pump();
    expect(
      find.textContaining('Esta ação não pode ser desfeita'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Excluir'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.deleteScopes, equals([true]));
    await _disposeTimer(tester, timer);
  });

  testWidgets('falha ao excluir mantem o item e mostra erro', (tester) async {
    final repo = FakePlannerRepository(mockTodos: [_todo(id: 2)])
      ..failDelete = true;
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Excluir'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.deleteScopes, equals([false]));
    expect(find.textContaining('Não foi possível salvar'), findsWidgets);
    expect(repo.items.map((todo) => todo.id), contains(2));
    await _disposeTimer(tester, timer);
  });

  testWidgets('iniciar pela tarefa seleciona materia, envia id e navega',
      (tester) async {
    final (repo, timer, timerRepo) = await _pump(
      tester,
      repository: FakePlannerRepository(mockTodos: [_todo(subjectId: 9)]),
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(timerRepo.taskIds, equals([1]));
    expect(timer.state.currentSubject?.id, 9);
    expect(timer.state.isRunning, isTrue);
    expect(find.text('Timer home'), findsOneWidget);
    expect(repo.items, isNotEmpty);
    await _disposeTimer(tester, timer);
  });

  testWidgets('iniciar tarefa sem materia avisa em vez de abrir sessao',
      (tester) async {
    final (_, timer, timerRepo) = await _pump(
      tester,
      repository: FakePlannerRepository(mockTodos: [_todo()]),
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(timerRepo.taskIds, isEmpty);
    expect(timer.state.isRunning, isFalse);
    expect(
      find.text('Não foi possível iniciar estudo para esta tarefa.'),
      findsOneWidget,
    );
    await _disposeTimer(tester, timer);
  });

  testWidgets('falha ao concluir reverte checkbox e mostra erro',
      (tester) async {
    final repo = FakePlannerRepository(mockTodos: [_todo()])..failToggle = true;
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.textContaining('Não foi possível salvar'), findsWidgets);
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.tap(find.text('Dispensar'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);
    await _disposeTimer(tester, timer);
  });

  testWidgets('falha de carga mostra erro e permite tentar novamente',
      (tester) async {
    final repo = FakePlannerRepository()..failLoad = true;
    final (_, timer, _) = await _pump(tester, repository: repo);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    repo.failLoad = false;
    repo.items = [_todo()];
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tarefa de teste'), findsOneWidget);
    await _disposeTimer(tester, timer);
  });

  testWidgets('inicio recusado nao ativa timer nem navega', (tester) async {
    final repo = FakePlannerRepository(mockTodos: [_todo(subjectId: 9)]);
    final (_, timer, timerRepo) = await _pump(tester, repository: repo);
    timerRepo.startAccepted = false;

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(timerRepo.taskIds, equals([1]));
    expect(timer.state.isRunning, isFalse);
    expect(find.text('Timer home'), findsNothing);
    expect(find.text('Não foi possível iniciar estudo para esta tarefa.'),
        findsOneWidget);
    await _disposeTimer(tester, timer);
  });

  testWidgets('falha ao criar mantem dialogo, texto e erro visiveis',
      (tester) async {
    final repo = FakePlannerRepository()..failCreate = true;
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Não perder este texto',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Adicionar'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Não perder este texto'), findsOneWidget);
    expect(find.textContaining('Não foi possível salvar'), findsWidgets);
    await _disposeTimer(tester, timer);
  });

  testWidgets('falha ao editar mantem dialogo e edicao visiveis',
      (tester) async {
    final repo = FakePlannerRepository(mockTodos: [_todo()])..failEdit = true;
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Edição recusada',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Salvar'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Edição recusada'), findsOneWidget);
    expect(find.textContaining('Não foi possível salvar'), findsWidgets);
    await _disposeTimer(tester, timer);
  });

  testWidgets('setas e atalho Hoje restauram o dia de estudo atual',
      (tester) async {
    final repo = FakePlannerRepository();
    final (_, timer, _) = await _pump(tester, repository: repo);
    final initialDay = repo.requestedDates.single;

    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.requestedDates.last, isNot(initialDay));
    await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.requestedDates.last, initialDay);

    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('planner-today-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.requestedDates.last, initialDay);
    await _disposeTimer(tester, timer);
  });

  testWidgets('seletor de data do cabecalho recarrega o dia escolhido',
      (tester) async {
    final repo = FakePlannerRepository();
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byKey(const ValueKey('planner-date-picker-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.requestedDates.last.endsWith('-15'), isTrue);
    await _disposeTimer(tester, timer);
  });

  testWidgets('contador acompanha concluidas e estado vazio e explicito',
      (tester) async {
    final repo = FakePlannerRepository(
      mockTodos: [_todo(id: 1, completed: true), _todo(id: 2)],
    );
    final (_, timer, _) = await _pump(tester, repository: repo);
    expect(find.textContaining('1 / 2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await _disposeTimer(tester, timer);

    final empty = FakePlannerRepository();
    final (_, secondTimer, _) = await _pump(tester, repository: empty);
    expect(find.textContaining('Nenhuma tarefa'), findsOneWidget);
    expect(find.textContaining('0 / 0'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await _disposeTimer(tester, secondTimer);
  });

  testWidgets('tarefa concluida desabilita inicio com tooltip', (tester) async {
    final repo = FakePlannerRepository(
      mockTodos: [_todo(subjectId: 9, completed: true)],
    );
    final (_, timer, timerRepo) = await _pump(tester, repository: repo);

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(button.tooltip, isNotNull);
    expect(timerRepo.taskIds, isEmpty);
    await _disposeTimer(tester, timer);
  });

  testWidgets('toggle success updates the completed counter', (tester) async {
    final repo = FakePlannerRepository(
      mockTodos: [_todo(id: 1, completed: true), _todo(id: 2)],
    );
    final (_, timer, _) = await _pump(tester, repository: repo);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.toggledIds, equals([2]));
    expect(find.textContaining('2 / 2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await _disposeTimer(tester, timer);
  });

  testWidgets('planner uses the effective country day rule', (tester) async {
    const country = CountryModel(
      id: 144,
      name: 'SRI LANKA',
      code: 'LK',
      timezone: 'Asia/Colombo',
      continent: 'Asia',
      gmtOffset: 5.5,
    );
    final settings = _DaySettingsNotifier(SettingsRepository())
      ..state = const SettingsState(
        selectedCountry: country,
        dayResetHour: 7,
      );
    final repo = FakePlannerRepository();
    final (_, timer, _) = await _pump(
      tester,
      repository: repo,
      settings: settings,
    );

    expect(repo.resetHours.single, 7);
    expect(repo.gmtOffsets.single, const Duration(hours: 5, minutes: 30));
    await _disposeTimer(tester, timer);
  });
}
