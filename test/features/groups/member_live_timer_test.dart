import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/groups/widgets/member_live_timer.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool isStudying,
  required bool isPaused,
  required DateTime? sessionStartedAt,
  required DateTime Function() now,
  String staticLabel = 'Estudando (1h30)',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MemberLiveTimer(
          isStudying: isStudying,
          isPaused: isPaused,
          sessionStartedAt: sessionStartedAt,
          activePrefix: 'Estudando',
          staticLabel: staticLabel,
          style: const TextStyle(fontSize: 12),
          nowProvider: now,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('formatElapsed', () {
    test('formata abaixo de uma hora como mm:ss', () {
      expect(formatElapsed(Duration.zero), equals('00:00'));
      expect(formatElapsed(const Duration(seconds: 5)), equals('00:05'));
      expect(formatElapsed(const Duration(minutes: 3, seconds: 7)), equals('03:07'));
      expect(formatElapsed(const Duration(minutes: 59, seconds: 59)), equals('59:59'));
    });

    test('a partir de uma hora usa h:mm:ss', () {
      expect(formatElapsed(const Duration(hours: 1)), equals('1:00:00'));
      expect(formatElapsed(const Duration(hours: 2, minutes: 5, seconds: 9)),
          equals('2:05:09'));
    });

    test('duracao negativa nunca mostra tempo negativo', () {
      expect(formatElapsed(const Duration(seconds: -10)), equals('00:00'));
    });
  });

  group('MemberLiveTimer', () {
    testWidgets('estudando e sem pausa: conta a partir de dl.st', (tester) async {
      final start = DateTime(2026, 11, 18, 10, 0, 0);
      await _pump(
        tester,
        isStudying: true,
        isPaused: false,
        sessionStartedAt: start,
        now: () => start.add(const Duration(minutes: 2, seconds: 30)),
      );

      expect(find.text('Estudando (02:30)'), findsOneWidget);
      expect(find.text('Estudando (1h30)'), findsNothing);
    });

    testWidgets('pausado: mostra o valor estatico e nao conta', (tester) async {
      final start = DateTime(2026, 11, 18, 10, 0, 0);
      await _pump(
        tester,
        isStudying: true,
        isPaused: true,
        sessionStartedAt: start,
        now: () => start.add(const Duration(minutes: 5)),
      );

      expect(find.text('Estudando (1h30)'), findsOneWidget);
    });

    testWidgets('nao estudando: mostra o valor estatico', (tester) async {
      await _pump(
        tester,
        isStudying: false,
        isPaused: false,
        sessionStartedAt: DateTime(2026, 11, 18, 10, 0, 0),
        now: () => DateTime(2026, 11, 18, 10, 5),
      );

      expect(find.text('Estudando (1h30)'), findsOneWidget);
    });

    testWidgets('st invalido/ausente: mostra o valor estatico', (tester) async {
      await _pump(
        tester,
        isStudying: true,
        isPaused: false,
        sessionStartedAt: null,
        now: () => DateTime(2026, 11, 18, 10, 5),
      );

      expect(find.text('Estudando (1h30)'), findsOneWidget);
    });

    testWidgets('o texto anda a cada segundo sem pedir nada a ninguem',
        (tester) async {
      var fakeNow = DateTime(2026, 11, 18, 10, 0, 0);
      final start = fakeNow;

      await _pump(
        tester,
        isStudying: true,
        isPaused: false,
        sessionStartedAt: start,
        now: () => fakeNow,
      );
      expect(find.text('Estudando (00:00)'), findsOneWidget);

      // Avanca o relogio injetado e deixa o timer disparar.
      fakeNow = start.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Estudando (00:01)'), findsOneWidget);

      fakeNow = start.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Estudando (00:03)'), findsOneWidget);
    });

    testWidgets('passar de estudando para pausado para o contador',
        (tester) async {
      final start = DateTime(2026, 11, 18, 10, 0, 0);
      var fakeNow = start.add(const Duration(seconds: 10));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberLiveTimer(
              isStudying: true,
              isPaused: false,
              sessionStartedAt: start,
              activePrefix: 'Estudando',
              staticLabel: 'Estudando (1h30)',
              style: const TextStyle(fontSize: 12),
              nowProvider: () => fakeNow,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Estudando (00:10)'), findsOneWidget);

      // O widget passa a receber isPaused = true no proximo poll.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberLiveTimer(
              isStudying: true,
              isPaused: true,
              sessionStartedAt: start,
              activePrefix: 'Estudando',
              staticLabel: 'Estudando (1h30)',
              style: const TextStyle(fontSize: 12),
              nowProvider: () => fakeNow,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Estudando (1h30)'), findsOneWidget);
    });

    testWidgets('desmontar cancela o ticker', (tester) async {
      final start = DateTime(2026, 11, 18, 10, 0, 0);
      await _pump(
        tester,
        isStudying: true,
        isPaused: false,
        sessionStartedAt: start,
        now: () => start,
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      // Se o ticker continuasse vivo, este pump falharia por setState pos-dispose.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(MemberLiveTimer), findsNothing);
    });
  });
}