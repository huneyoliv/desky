import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/utils/study_day_helper.dart';
import 'package:desky/data/models/dday_model.dart';
import 'package:desky/data/models/todo_item_model.dart';
import 'package:desky/data/repositories/planner_repository.dart';
import 'package:desky/features/planner/planner_screen.dart';

class FakePlannerRepository extends PlannerRepository {
  final List<DDayModel> mockDDays;
  final List<TodoItemModel> mockTodos;

  FakePlannerRepository({
    this.mockDDays = const [],
    this.mockTodos = const [],
  });

  @override
  Future<List<DDayModel>> fetchDDays() async => mockDDays;

  @override
  Future<List<TodoItemModel>> fetchTodos(
    String dateYmd, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async =>
      mockTodos;

  @override
  Future<bool> toggleTodo(
    TodoItemModel todo, {
    required Duration gmtOffset,
    int resetHour = StudyDayHelper.defaultResetHour,
  }) async =>
      true;
}

void main() {
  testWidgets('PlannerScreen renders D-Days and To-Do list items', (tester) async {
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
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
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
    expect(find.text('Resolver 30 questões de Matemática'), findsOneWidget);
  });

  testWidgets('o painel esquerdo preenche a altura da aba, sem faixa vazia', (tester) async {
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
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
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
        .ancestor(of: find.byType(CalendarDatePicker), matching: find.byType(Container))
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
}
