import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
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
  Future<List<TodoItemModel>> fetchTodos(String dateYmd) async => mockTodos;

  @override
  Future<bool> toggleTodo(TodoItemModel todo) async => true;
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
}
