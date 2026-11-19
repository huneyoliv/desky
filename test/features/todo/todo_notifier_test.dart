import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/data/repositories/todo_repository.dart';
import 'package:desky/features/todo/todo_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TodoRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = TodoRepository();
  });

  Future<TodoNotifier> buildNotifier({int resetHour = 5}) async {
    final notifier = TodoNotifier(repository: repository, dayResetHour: resetHour);
    addTearDown(notifier.dispose);
    // Give the initial load a chance to settle.
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  group('TodoNotifier', () {
    test('comeca carregando e vazio', () async {
      final notifier = await buildNotifier();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.todos, isEmpty);
      expect(notifier.forDay(), isEmpty);
    });

    test('adiciona uma tarefa e persiste', () async {
      final notifier = await buildNotifier();

      final created = await notifier.add(title: '  Estudar  ', note: 'cap 2');

      expect(created, isNotNull);
      expect(created!.title, equals('Estudar'), reason: 'titulo vai aparado');
      expect(notifier.forDay(), hasLength(1));

      final reloaded = await repository.load();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.title, equals('Estudar'));
    });

    test('titulo vazio ou so espacos nao cria tarefa', () async {
      final notifier = await buildNotifier();

      expect(await notifier.add(title: '   '), isNull);
      expect(notifier.forDay(), isEmpty);
    });

    test('marca e desmarca como concluida, gravando e limpando completedAt',
        () async {
      final notifier = await buildNotifier();
      final todo = await notifier.add(title: 'Tarefa');

      await notifier.toggleDone(todo!.id);
      var stored = await repository.load();
      expect(stored.single.done, isTrue);
      expect(stored.single.completedAt, isNotNull);

      await notifier.toggleDone(todo.id);
      stored = await repository.load();
      expect(stored.single.done, isFalse);
      expect(stored.single.completedAt, isNull);
    });

    test('remove uma tarefa', () async {
      final notifier = await buildNotifier();
      final todo = await notifier.add(title: 'Some');

      await notifier.remove(todo!.id);

      expect(notifier.forDay(), isEmpty);
      expect(await repository.load(), isEmpty);
    });

    test('edita titulo, nota e horario', () async {
      final notifier = await buildNotifier();
      final todo = await notifier.add(title: 'Antes');

      await notifier.update(
        id: todo!.id,
        title: 'Depois',
        note: 'nota nova',
        startMinute: 600,
      );

      final stored = (await repository.load()).single;
      expect(stored.title, equals('Depois'));
      expect(stored.note, equals('nota nova'));
      expect(stored.startMinute, equals(600));

      // Limpar o horario devolve a tarefa para "sem horario".
      await notifier.update(id: todo.id, clearStartMinute: true);
      expect((await repository.load()).single.startMinute, isNull);
    });

    test('titulo vazio no update nao apaga o titulo atual', () async {
      final notifier = await buildNotifier();
      final todo = await notifier.add(title: 'Mantem');

      await notifier.update(id: todo!.id, title: '   ');

      expect((await repository.load()).single.title, equals('Mantem'));
    });

    test('move a tarefa para outro dia', () async {
      final notifier = await buildNotifier();
      final todo = await notifier.add(title: 'Mover', day: '2026-11-18');

      await notifier.moveToDay(todo!.id, '2026-11-20');

      expect(notifier.forDay('2026-11-18'), isEmpty);
      expect(notifier.forDay('2026-11-20'), hasLength(1));
    });

    test('separa tarefas por dia', () async {
      final notifier = await buildNotifier();
      await notifier.add(title: 'dia 1', day: '2026-11-18');
      await notifier.add(title: 'dia 2', day: '2026-11-19');

      expect(notifier.forDay('2026-11-18'), hasLength(1));
      expect(notifier.forDay('2026-11-19'), hasLength(1));
    });

    test('tarefas abertas aparecem antes das concluidas', () async {
      final notifier = await buildNotifier();
      final a = await notifier.add(title: 'concluida', day: '2026-11-18');
      await notifier.add(title: 'aberta', day: '2026-11-18');
      await notifier.toggleDone(a!.id);

      final list = notifier.forDay('2026-11-18');

      expect(list.first.title, equals('aberta'));
      expect(list.last.title, equals('concluida'));
    });

    test('progresso conta total e concluidas do dia ativo', () async {
      final notifier = await buildNotifier();
      final a = await notifier.add(title: 'um');
      await notifier.add(title: 'dois');
      await notifier.toggleDone(a!.id);

      final progress = notifier.progressForActiveDay();

      expect(progress.total, equals(2));
      expect(progress.done, equals(1));
    });

    test('selecionar um dia muda o dia ativo', () async {
      final notifier = await buildNotifier();
      final today = notifier.todayKey;

      expect(notifier.activeDay, equals(today));

      notifier.selectDay('2026-11-20');
      expect(notifier.activeDay, equals('2026-11-20'));

      notifier.selectDay(null);
      expect(notifier.activeDay, equals(today));
    });

    test('sem dia informado a tarefa cai no dia ativo', () async {
      final notifier = await buildNotifier();
      notifier.selectDay('2026-11-21');

      final todo = await notifier.add(title: 'no dia escolhido');

      expect(todo!.day, equals('2026-11-21'));
    });
  });
}