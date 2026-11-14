import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/ranks/stats_derivations.dart';

const int _min = 60000;

void main() {
  group('sumBetween', () {
    test('soma apenas os dias do intervalo, inclusive as pontas', () {
      final byDay = {
        '2026-11-06': 10 * _min,
        '2026-11-07': 20 * _min,
        '2026-11-08': 30 * _min,
        '2026-11-09': 40 * _min,
      };

      final total = StatsDerivations.sumBetween(
        byDay,
        DateTime(2026, 11, 7),
        DateTime(2026, 11, 8),
      );

      expect(total, equals(50 * _min));
    });

    test('ignora chaves invalidas em vez de quebrar', () {
      final byDay = {'lixo': 99 * _min, '2026-11-07': 5 * _min};

      expect(
        StatsDerivations.sumBetween(byDay, DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
        equals(5 * _min),
      );
    });

    test('mapa vazio soma zero', () {
      expect(
        StatsDerivations.sumBetween({}, DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
        equals(0),
      );
    });
  });

  group('comparePeriods', () {
    test('compara hoje/ontem, semana passada e mes passado', () {
      // Quarta-feira, 2026-11-11.
      final now = DateTime(2026, 11, 11, 15, 30);
      final byDay = {
        '2026-11-11': 60 * _min, // hoje
        '2026-11-10': 30 * _min, // ontem
        '2026-11-09': 90 * _min, // segunda desta semana
        '2026-11-04': 45 * _min, // semana passada
        '2026-11-02': 15 * _min, // semana passada
        '2026-10-20': 120 * _min, // mes passado
      };

      final result = StatsDerivations.comparePeriods(byDay, now: now);
      final byKey = {for (final c in result) c.key: c};

      // Hoje: 60 vs 30 -> dobrou.
      expect(byKey['today']!.currentMs, equals(60 * _min));
      expect(byKey['today']!.previousMs, equals(30 * _min));
      expect(byKey['today']!.growth, equals(1.0));
      expect(byKey['today']!.deltaMs, equals(30 * _min));

      // Semana: segunda 09/11 (90) + ontem 10/11 (30) + hoje 11/11 (60) = 180
      // contra 45 + 15 = 60 na semana passada.
      expect(byKey['week']!.currentMs, equals(180 * _min));
      expect(byKey['week']!.previousMs, equals(60 * _min));

      // Mes: novembro tem 11,10,9,4,2 = 240; outubro tem 120.
      expect(byKey['month']!.currentMs, equals(240 * _min));
      expect(byKey['month']!.previousMs, equals(120 * _min));
    });

    test('sem periodo anterior o crescimento fica indefinido', () {
      final byDay = {'2026-11-11': 60 * _min};
      final result = StatsDerivations.comparePeriods(
        byDay,
        now: DateTime(2026, 11, 11),
      );
      final today = result.firstWhere((c) => c.key == 'today');

      expect(today.previousMs, equals(0));
      expect(today.growth, isNull);
      expect(today.hasPrevious, isFalse);
      expect(today.hasAnyData, isTrue);
    });

    test('mapa vazio devolve tres comparacoes sem dado', () {
      final result = StatsDerivations.comparePeriods({}, now: DateTime(2026, 11, 11));

      expect(result, hasLength(3));
      expect(result.every((c) => !c.hasAnyData), isTrue);
    });
  });

  group('maxima', () {
    test('encontra o melhor dia, a melhor semana e o melhor mes', () {
      final byDay = {
        '2026-11-02': 30 * _min, // semana de 02/11
        '2026-11-03': 30 * _min, // semana de 02/11 -> 60 na semana
        '2026-11-09': 40 * _min, // semana de 09/11 -> 40
        '2026-11-10': 200 * _min, // melhor dia, semana de 09/11 -> 240
        '2026-10-31': 90 * _min, // outubro
      };

      final maxima = StatsDerivations.maxima(byDay);

      expect(maxima.bestDayKey, equals('2026-11-10'));
      expect(maxima.bestDayMs, equals(200 * _min));
      expect(maxima.bestWeekKey, equals('2026-11-09'));
      expect(maxima.bestWeekMs, equals(240 * _min));
      expect(maxima.bestMonthKey, equals('2026-11'));
      expect(maxima.bestMonthMs, equals(300 * _min));
      expect(maxima.dayCount, equals(5));
    });

    test('ignora dias zerados ao contar dias com dado', () {
      final byDay = {'2026-11-09': 0, '2026-11-10': 15 * _min};

      final maxima = StatsDerivations.maxima(byDay);

      expect(maxima.dayCount, equals(1));
      expect(maxima.bestDayKey, equals('2026-11-10'));
    });

    test('mapa vazio nao tem dado', () {
      final maxima = StatsDerivations.maxima({});

      expect(maxima.hasData, isFalse);
      expect(maxima.bestDayKey, isNull);
      expect(maxima.dayCount, equals(0));
    });
  });

  group('cumulativeBySubject', () {
    test('acumula por materia e agrupa o excedente em Outros', () {
      final byDay = {
        '2026-11-09': {'A': 10 * _min, 'B': 5 * _min, 'C': 1 * _min},
        '2026-11-10': {'A': 10 * _min, 'D': 4 * _min},
      };

      // topSubjects=2 mantem A e B; C e D viram Outros.
      final series =
          StatsDerivations.cumulativeBySubject(byDay, topSubjects: 2);

      expect(series.days, equals(['2026-11-09', '2026-11-10']));
      expect(series.subjects, containsAll(['A', 'B', StatsDerivations.otherSubjectsKey]));
      expect(series.totals['A'], equals([10 * _min, 20 * _min]));
      expect(series.totals['B'], equals([5 * _min, 5 * _min]));
      expect(
        series.totals[StatsDerivations.otherSubjectsKey],
        equals([1 * _min, 5 * _min]),
      );
      expect(series.hasData, isTrue);
    });

    test('materia desconhecida cai no bucket de Outros', () {
      final byDay = {
        '2026-11-09': {
          StatsDerivations.unknownSubjectKey: 7 * _min,
          'A': 30 * _min,
        },
      };

      final series = StatsDerivations.cumulativeBySubject(byDay);

      expect(
        series.totals[StatsDerivations.otherSubjectsKey],
        equals([7 * _min]),
      );
      expect(series.totals.containsKey(StatsDerivations.unknownSubjectKey), isFalse);
    });

    test('mapa vazio devolve serie vazia sem quebrar', () {
      final series = StatsDerivations.cumulativeBySubject({});

      expect(series.hasData, isFalse);
      expect(series.days, isEmpty);
      expect(series.subjects, isEmpty);
    });
  });

  group('calendario trimestral', () {
    test('cobre os tres meses do trimestre com dias zerados', () {
      final byDay = {'2026-11-11': 30 * _min};

      final quarter = StatsDerivations.quarterDays(byDay, month: DateTime(2026, 11));

      // Outubro (31) + novembro (30) + dezembro (31).
      expect(quarter.length, equals(92));
      expect(quarter['2026-10-01'], equals(0));
      expect(quarter['2026-11-11'], equals(30 * _min));
      expect(quarter['2026-12-31'], equals(0));
      expect(StatsDerivations.quarterPeak(quarter), equals(30 * _min));
    });

    test('trimestre comeca em janeiro, abril, julho e outubro', () {
      expect(
        StatsDerivations.quarterDays({}, month: DateTime(2026, 2)).keys.first,
        equals('2026-01-01'),
      );
      expect(
        StatsDerivations.quarterDays({}, month: DateTime(2026, 5)).keys.first,
        equals('2026-04-01'),
      );
      expect(
        StatsDerivations.quarterDays({}, month: DateTime(2026, 8)).keys.first,
        equals('2026-07-01'),
      );
      expect(
        StatsDerivations.quarterDays({}, month: DateTime(2026, 11)).keys.first,
        equals('2026-10-01'),
      );
    });
  });
}