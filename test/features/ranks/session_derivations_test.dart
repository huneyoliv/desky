import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/ranks/session_derivations.dart';

const int _min = 60000;

Map<String, dynamic> _stats(List<Map<String, dynamic>> days) => {
      's': true,
      'ls': days,
    };

Map<String, dynamic> _day(String dt, List<Map<String, dynamic>> sessions) => {
      'dt': dt,
      'sm': sessions.fold<int>(0, (a, s) => a + (s['sm'] as int)),
      'ls': sessions,
    };

Map<String, dynamic> _session(DateTime start, int minutes) => {
      'sb': 'Matemática',
      'sm': minutes * _min,
      'st': start.toIso8601String(),
    };

void main() {
  group('StudySessionParser', () {
    test('le dt, st e sm de cada sessao', () {
      final data = _stats([
        _day('2026-11-09', [
          _session(DateTime(2026, 11, 9, 9, 30), 45),
          _session(DateTime(2026, 11, 9, 14, 10), 20),
        ]),
      ]);

      final sessions = StudySessionParser.parse(data);

      expect(sessions, hasLength(2));
      expect(sessions.first.day, equals('2026-11-09'));
      expect(sessions.first.startMinute, equals(9 * 60 + 30));
      expect(sessions.first.durationMs, equals(45 * _min));
      expect(sessions.first.endMinute, equals(9 * 60 + 30 + 45));
      expect(sessions.last.startMinute, equals(14 * 60 + 10));
    });

    test('ordena por dia e depois por horario de inicio', () {
      final data = _stats([
        _day('2026-11-10', [_session(DateTime(2026, 11, 10, 8, 0), 10)]),
        _day('2026-11-09', [
          _session(DateTime(2026, 11, 9, 20, 0), 10),
          _session(DateTime(2026, 11, 9, 7, 0), 10),
        ]),
      ]);

      final sessions = StudySessionParser.parse(data);

      expect(sessions.map((s) => s.day).toList(),
          equals(['2026-11-09', '2026-11-09', '2026-11-10']));
      expect(sessions[0].startMinute, equals(7 * 60));
      expect(sessions[1].startMinute, equals(20 * 60));
    });

    test('descarta sessao sem st valido, com sm zero ou negativo', () {
      final data = _stats([
        _day('2026-11-09', [
          {'sb': 'X', 'sm': 30 * _min, 'st': 'nao-e-data'},
          _session(DateTime(2026, 11, 9, 10, 0), 0),
          {'sb': 'X', 'sm': -5 * _min, 'st': DateTime(2026, 11, 9, 11, 0).toIso8601String()},
          _session(DateTime(2026, 11, 9, 12, 0), 5),
        ]),
      ]);

      final sessions = StudySessionParser.parse(data);

      expect(sessions, hasLength(1));
      expect(sessions.single.startMinute, equals(12 * 60));
    });

    test('payload vazio ou malformado devolve lista vazia', () {
      expect(StudySessionParser.parse({}), isEmpty);
      expect(StudySessionParser.parse({'ls': 'nao-e-lista'}), isEmpty);
      expect(StudySessionParser.parse({'ls': [1, 2, 3]}), isEmpty);
    });

    test('st em UTC e convertido para o fuso do dispositivo', () {
      final iso = '2026-11-09T23:50:00+00:00';
      final local = DateTime.parse(iso).toLocal();
      final data = _stats([
        _day('2026-11-09', [
          {'sb': 'X', 'sm': 3 * _min, 'st': iso},
        ]),
      ]);

      final sessions = StudySessionParser.parse(data);

      expect(sessions.single.startMinute, equals(local.hour * 60 + local.minute));
    });
  });

  group('TimeOfDayStats', () {
    test('calcula medias de inicio e fim', () {
      final sessions = [
        const StudySession(day: '2026-11-09', startMinute: 8 * 60, durationMs: 60 * _min),
        const StudySession(day: '2026-11-10', startMinute: 10 * 60, durationMs: 30 * _min),
      ];

      final stats = TimeOfDayStats.fromSessions(sessions);

      expect(stats.sessionCount, equals(2));
      expect(stats.avgStartMinute, equals(9 * 60));
      expect(stats.avgEndMinute, equals(9 * 60 + 45));
      expect(stats.earliestStartMinute, equals(8 * 60));
      expect(stats.latestStartMinute, equals(10 * 60));
      expect(stats.hasData, isTrue);
    });

    test('desvio padrao zero quando todas as sessoes comecam no mesmo minuto', () {
      final sessions = [
        const StudySession(day: '2026-11-09', startMinute: 600, durationMs: 10 * _min),
        const StudySession(day: '2026-11-10', startMinute: 600, durationMs: 10 * _min),
      ];

      final stats = TimeOfDayStats.fromSessions(sessions);

      expect(stats.startStdDevMinutes, equals(0));
      expect(regularityLabel(stats.startStdDevMinutes), equals('muito regular'));
    });

    test('desvio padrao cresce com a dispersao', () {
      final sessions = [
        const StudySession(day: '2026-11-09', startMinute: 6 * 60, durationMs: 10 * _min),
        const StudySession(day: '2026-11-10', startMinute: 18 * 60, durationMs: 10 * _min),
      ];

      final stats = TimeOfDayStats.fromSessions(sessions);

      // Media 12h, desvio 6h = 360 min.
      expect(stats.startStdDevMinutes, equals(360));
      expect(regularityLabel(stats.startStdDevMinutes), equals('muito irregular'));
    });

    test('sessao que atravessa a meia-noite nao volta o fim para zero', () {
      final sessions = [
        const StudySession(day: '2026-11-09', startMinute: 23 * 60 + 50, durationMs: 30 * _min),
      ];

      final stats = TimeOfDayStats.fromSessions(sessions);

      expect(stats.avgStartMinute, equals(23 * 60 + 50));
      expect(stats.avgEndMinute, equals(24 * 60 + 20));
    });

    test('lista vazia devolve estatistica sem dado', () {
      final stats = TimeOfDayStats.fromSessions(const []);

      expect(stats.hasData, isFalse);
      expect(stats.sessionCount, equals(0));
      expect(stats.avgStartMinute, isNull);
      expect(stats.avgEndMinute, isNull);
      expect(stats.startStdDevMinutes, isNull);
    });
  });

  group('scatterPoints', () {
    test('gera um ponto por sessao com inicio e fim', () {
      final sessions = [
        const StudySession(day: '2026-11-09', startMinute: 540, durationMs: 60 * _min),
        const StudySession(day: '2026-11-10', startMinute: 600, durationMs: 30 * _min),
      ];

      final points = scatterPoints(sessions);

      expect(points, hasLength(2));
      expect(points.first.startMinute, equals(540));
      expect(points.first.endMinute, equals(600));
      expect(points.last.endMinute, equals(630));
    });

    test('lista vazia gera nenhum ponto', () {
      expect(scatterPoints(const []), isEmpty);
    });
  });

  group('formatMinuteOfDay', () {
    test('formata minutos do dia em HH:mm', () {
      expect(formatMinuteOfDay(0), equals('00:00'));
      expect(formatMinuteOfDay(9 * 60 + 5), equals('09:05'));
      expect(formatMinuteOfDay(23 * 60 + 59), equals('23:59'));
    });

    test('tolera valor depois da meia-noite', () {
      expect(formatMinuteOfDay(24 * 60 + 20), equals('24:20'));
    });
  });
}