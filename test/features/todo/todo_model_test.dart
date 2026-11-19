import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/data/models/todo_model.dart';
import 'package:desky/data/repositories/todo_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodoModel', () {
    test('ida e volta por JSON preserva os campos', () {
      final created = DateTime(2026, 11, 18, 10, 30);
      final todo = TodoModel(
        id: 42,
        title: 'Ler capítulo 3',
        note: 'página 40',
        day: '2026-11-18',
        startMinute: 8 * 60 + 15,
        createdAt: created,
      );

      final restored = TodoModel.fromJson(todo.toJson());

      expect(restored.id, equals(42));
      expect(restored.title, equals('Ler capítulo 3'));
      expect(restored.note, equals('página 40'));
      expect(restored.day, equals('2026-11-18'));
      expect(restored.startMinute, equals(8 * 60 + 15));
      expect(restored.done, isFalse);
      expect(restored.createdAt, equals(created));
    });

    test('timeLabel formata a hora do dia', () {
      final base = TodoModel(
        id: 1,
        title: 'x',
        day: '2026-11-18',
        createdAt: DateTime(2026, 11, 18),
      );

      expect(base.copyWith(startMinute: 0).timeLabel, equals('00:00'));
      expect(base.copyWith(startMinute: 9 * 60 + 5).timeLabel, equals('09:05'));
      expect(base.copyWith(startMinute: 23 * 60 + 59).timeLabel, equals('23:59'));
      expect(base.timeLabel, isEmpty, reason: 'sem horario nao mostra nada');
    });

    test('hasTime reflete o campo', () {
      final base = TodoModel(
        id: 1,
        title: 'x',
        day: '2026-11-18',
        createdAt: DateTime(2026, 11, 18),
      );

      expect(base.hasTime, isFalse);
      expect(base.copyWith(startMinute: 600).hasTime, isTrue);
      expect(base.copyWith(startMinute: 600, clearStartMinute: true).hasTime, isFalse);
    });

    test('JSON corrompido nao quebra', () {
      final todo = TodoModel.fromJson({
        'id': 'lixo',
        'title': null,
        'day': 123,
      });

      expect(todo.id, equals(0));
      // safeString converte numeros para texto, entao '123' e o esperado.
      expect(todo.title, isEmpty);
      expect(todo.day, equals('123'));
      expect(todo.done, isFalse);
    });
  });

  group('TodoRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('comeca vazio', () async {
      expect(await TodoRepository().load(), isEmpty);
    });

    test('salva e recarrega a lista', () async {
      final repo = TodoRepository();
      final todos = [
        TodoModel(
          id: 1,
          title: 'A',
          day: '2026-11-18',
          startMinute: 600,
          createdAt: DateTime(2026, 11, 18, 9),
        ),
        TodoModel(
          id: 2,
          title: 'B',
          day: '2026-11-19',
          createdAt: DateTime(2026, 11, 18, 10),
        ),
      ];

      await repo.save(todos);
      final loaded = await repo.load();

      expect(loaded, hasLength(2));
      expect(loaded.first.title, equals('A'));
      expect(loaded.last.title, equals('B'));
    });

    test('ordena por dia e depois por horario, sem horario por ultimo', () async {
      final repo = TodoRepository();
      await repo.save([
        TodoModel(id: 1, title: 'sem hora', day: '2026-11-18',
            createdAt: DateTime(2026, 11, 18, 8)),
        TodoModel(id: 2, title: 'tarde', day: '2026-11-18', startMinute: 900,
            createdAt: DateTime(2026, 11, 18, 8)),
        TodoModel(id: 3, title: 'cedo', day: '2026-11-18', startMinute: 480,
            createdAt: DateTime(2026, 11, 18, 8)),
        TodoModel(id: 4, title: 'outro dia', day: '2026-11-17',
            createdAt: DateTime(2026, 11, 17, 8)),
      ]);

      final loaded = await repo.load();

      expect(loaded.map((t) => t.title).toList(),
          equals(['outro dia', 'cedo', 'tarde', 'sem hora']));
    });

    test('descarta linha sem titulo ou sem dia', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TodoRepository.storageKey, '''
[
  {"id":1,"title":"","day":"2026-11-18","createdAt":"2026-11-18T10:00:00.000"},
  {"id":2,"title":"ok","day":"","createdAt":"2026-11-18T10:00:00.000"},
  {"id":3,"title":"valido","day":"2026-11-18","createdAt":"2026-11-18T10:00:00.000"}
]
''');

      final loaded = await TodoRepository().load();

      expect(loaded, hasLength(1));
      expect(loaded.single.title, equals('valido'));
    });

    test('JSON invalido devolve lista vazia em vez de lancar', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TodoRepository.storageKey, 'isto nao e json');
      expect(await TodoRepository().load(), isEmpty);
    });
  });
}