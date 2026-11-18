import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/api/api_client.dart';
import 'package:desky/data/repositories/rank_repository.dart';

class _StubApiClient extends ApiClient {
  _StubApiClient(this.response) : super(customDio: Dio());

  final Map<String, dynamic> response;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
    String? baseUrl,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: response,
      statusCode: 200,
    );
  }
}

/// Resposta com um unico dia e uma sessao cujo `st` e a string ISO crua da API.
Map<String, dynamic> _oneDayIso({
  required String dt,
  required String st,
  required int minutes,
}) {
  return {
    's': true,
    'ls': [
      {
        'dt': dt,
        'sm': minutes * 60000,
        'ls': [
          {'sb': 'Matemática', 'sm': minutes * 60000, 'st': st},
        ],
      },
    ],
  };
}

/// Resposta com um unico dia e uma unica sessao.
Map<String, dynamic> _oneDay({
  required String dt,
  required DateTime start,
  required int minutes,
}) {
  return {
    's': true,
    'ls': [
      {
        'dt': dt,
        'sm': minutes * 60000,
        'ls': [
          {'sb': 'Matemática', 'sm': minutes * 60000, 'st': start.toIso8601String()},
        ],
      },
    ],
  };
}

Future<Map<String, List<int>>> _run(
  Map<String, dynamic> response, {
  required String startDate,
  required String endDate,
}) {
  return RankRepository(apiClient: _StubApiClient(response))
      .fetchHourlyStudyMinutes(
    userId: 1,
    startDate: startDate,
    endDate: endDate,
  );
}

int _total(List<int> buckets) => buckets.reduce((a, b) => a + b);

void main() {
  group('fetchHourlyStudyMinutes', () {
    test('sessao dentro de uma hora ocupa so aquele bloco', () async {
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 20, 5), minutes: 30),
        startDate: '2026-11-07',
        endDate: '2026-11-07',
      );

      expect(byDay['2026-11-07']![20], equals(30));
      expect(_total(byDay['2026-11-07']!), equals(30));
    });

    test('sessao cruzando a virada da hora divide os minutos', () async {
      // 90 min a partir de 21:12 -> 48 min na hora 21 e 42 na hora 22.
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 21, 12), minutes: 90),
        startDate: '2026-11-07',
        endDate: '2026-11-07',
      );

      expect(byDay['2026-11-07']![21], equals(48));
      expect(byDay['2026-11-07']![22], equals(42));
      expect(_total(byDay['2026-11-07']!), equals(90));
    });

    test('sessao cruzando a meia-noite continua no dia seguinte', () async {
      // 30 min a partir de 23:50 -> 10 min na hora 23 do dia 7,
      // 20 min na hora 0 do dia 8. Nada e descartado.
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 23, 50), minutes: 30),
        startDate: '2026-11-06',
        endDate: '2026-11-08',
      );

      expect(byDay['2026-11-07']![23], equals(10));
      expect(byDay['2026-11-07']![0], equals(0));
      expect(byDay.containsKey('2026-11-08'), isTrue);
      expect(byDay['2026-11-08']![0], equals(20));
      // Os 30 minutos sobrevivem inteiros.
      expect(_total(byDay['2026-11-07']!) + _total(byDay['2026-11-08']!), equals(30));
    });

    test('virada longa atravessa mais de um dia', () async {
      // 26 h a partir de 22:00 do dia 7: passa pelos dias 8 e 9.
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 22, 0), minutes: 26 * 60),
        startDate: '2026-11-07',
        endDate: '2026-11-10',
      );

      expect(byDay['2026-11-07']![22], equals(60));
      expect(byDay['2026-11-07']![23], equals(60));
      // 24 h completas termina as 22:00 do dia 8; o resto vai para o dia 8.
      expect(_total(byDay['2026-11-07']!), equals(120));
      expect(_total(byDay['2026-11-08']!), equals(1440));
      expect(_total(byDay['2026-11-09']!), equals(0));
      final total = byDay.values.map(_total).reduce((a, b) => a + b);
      expect(total, equals(26 * 60));
    });

    test('sessao de 0 min nao altera nenhum bloco', () async {
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 10, 0), minutes: 0),
        startDate: '2026-11-07',
        endDate: '2026-11-07',
      );

      expect(_total(byDay['2026-11-07']!), equals(0));
    });

    test('sessao com duracao negativa e ignorada', () async {
      final response = {
        's': true,
        'ls': [
          {
            'dt': '2026-11-07',
            'sm': -60000,
            'ls': [
              {
                'sb': 'X',
                'sm': -60000,
                'st': DateTime(2026, 11, 7, 10, 0).toIso8601String(),
              },
            ],
          },
        ],
      };

      final byDay = await _run(
        response,
        startDate: '2026-11-07',
        endDate: '2026-11-07',
      );

      expect(_total(byDay['2026-11-07']!), equals(0));
    });

    test('sessao antes do dayResetHour fica no dia civil de dt', () async {
      // 03:00 nao e deslocado para o dia anterior: a regra e o dia civil, nao o
      // "dia de estudo" com reset as 5h do StudyDateHelper.
      final byDay = await _run(
        _oneDay(dt: '2026-11-08', start: DateTime(2026, 11, 8, 3, 0), minutes: 45),
        startDate: '2026-11-07',
        endDate: '2026-11-08',
      );

      expect(byDay['2026-11-08']![3], equals(45));
      expect(_total(byDay['2026-11-07']!), equals(0));
    });

    test('sessao as 04:59 ainda pertence ao dia civil de dt', () async {
      // 2 min a partir de 04:59: so 1 min cabe na hora 4, o outro vai para a
      // hora 5 do mesmo dia (nao ha deslocamento de dia pelo reset das 5h).
      final byDay = await _run(
        _oneDay(dt: '2026-11-08', start: DateTime(2026, 11, 8, 4, 59), minutes: 2),
        startDate: '2026-11-08',
        endDate: '2026-11-08',
      );

      expect(byDay['2026-11-08']![4], equals(1));
      expect(byDay['2026-11-08']![5], equals(1));
      expect(_total(byDay['2026-11-08']!), equals(2));
    });

    test('dt manda no dia quando diverge do dia civil de st', () async {
      // A API agrupa a sessao no dia 7, mas o inicio e 03:00 do dia 8.
      // A linha continua sendo a de dt; apenas a hora vem de st.
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 8, 3, 0), minutes: 20),
        startDate: '2026-11-07',
        endDate: '2026-11-08',
      );

      expect(byDay['2026-11-07']![3], equals(20));
      expect(_total(byDay['2026-11-08']!), equals(0));
    });

    test('minutos fora do intervalo pedido sao descartados', () async {
      // Sessao de 23:50 no ultimo dia do intervalo: a parte do dia seguinte
      // ficaria fora da janela e nao inventa uma linha nova.
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 23, 50), minutes: 30),
        startDate: '2026-11-07',
        endDate: '2026-11-07',
      );

      expect(byDay.keys.toList(), equals(['2026-11-07']));
      expect(byDay['2026-11-07']![23], equals(10));
    });

    test('st em UTC e convertido para o fuso do dispositivo', () async {
      // A API devolve `st` sempre com +00:00. O mapa precisa usar a hora LOCAL
      // (toLocal), nao a hora de parede gravada na string.
      const iso = '2026-08-11T01:01:54+00:00';
      final local = DateTime.parse(iso).toLocal();
      final wallHour = DateTime.parse(iso).toUtc().hour;

      final byDay = await _run(
        _oneDayIso(dt: '2026-08-10', st: iso, minutes: 1),
        startDate: '2026-08-09',
        endDate: '2026-08-11',
      );

      expect(byDay['2026-08-10']![local.hour], equals(1),
          reason: 'o minuto pertence a hora local de inicio');
      expect(byDay.values.map(_total).reduce((a, b) => a + b), equals(1));

      if (local.hour != wallHour) {
        expect(byDay['2026-08-10']![wallHour], equals(0),
            reason: 'nao pode usar a hora de parede da string em UTC');
      }
    });

    test('st com offset positivo diferente do dispositivo tambem e convertido',
        () async {
      // Offset de +05:30 (nao inteiro) para exercitar minutos tambem.
      const iso = '2026-11-07T23:50:00+05:30';
      final local = DateTime.parse(iso).toLocal();
      final wallHour = DateTime.parse(iso).toUtc().hour;

      final byDay = await _run(
        _oneDayIso(dt: '2026-11-07', st: iso, minutes: 1),
        startDate: '2026-11-06',
        endDate: '2026-11-08',
      );

      expect(byDay['2026-11-07']![local.hour], equals(1));
      expect(byDay.values.map(_total).reduce((a, b) => a + b), equals(1));
      if (local.hour != wallHour) {
        expect(byDay['2026-11-07']![wallHour], equals(0));
      }
    });

    test('sessao com st em UTC nao perde minutos', () async {
      const iso = '2026-11-07T23:50:00+00:00';
      final local = DateTime.parse(iso).toLocal();

      final byDay = await _run(
        _oneDayIso(dt: '2026-11-07', st: iso, minutes: 30),
        startDate: '2026-11-06',
        endDate: '2026-11-09',
      );

      expect(byDay.values.map(_total).reduce((a, b) => a + b), equals(30));
      expect(byDay['2026-11-07']![local.hour], greaterThan(0));
    });

    test('dias sem sessao ficam zerados e com 24 blocos', () async {
      final byDay = await _run(
        _oneDay(dt: '2026-11-07', start: DateTime(2026, 11, 7, 20, 0), minutes: 10),
        startDate: '2026-11-06',
        endDate: '2026-11-08',
      );

      expect(
        byDay.keys.toList()..sort(),
        equals(['2026-11-06', '2026-11-07', '2026-11-08']),
      );
      for (final buckets in byDay.values) {
        expect(buckets.length, equals(24));
      }
      expect(_total(byDay['2026-11-06']!), equals(0));
      expect(_total(byDay['2026-11-08']!), equals(0));
    });
  });
}