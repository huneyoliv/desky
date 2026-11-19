import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/features/timer/widgets/timer_display.dart';

/// The Timer screen doubles as an OBS window-capture overlay: the window is
/// cropped once and elements must not move afterwards. These tests measure the
/// rendered geometry, because "it looks stable" is not evidence.
Future<void> _pumpTimer(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});

  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: InkRipple.splashFactory,
        ),
        home: const TimerScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('TimerDisplay', () {
    testWidgets('largura e altura nao mudam com o tempo decorrido',
        (tester) async {
      Future<Size> measure(int ms) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: false,
              ),
            home: Scaffold(body: Center(child: TimerDisplay(elapsedMs: ms))),
          ),
        );
        await tester.pump();
        return tester.getSize(find.byType(TimerDisplay));
      }

      final zero = await measure(0);
      final oneHour = await measure(3723000);
      final tenHours = await measure(36000000);

      expect(oneHour.width, closeTo(zero.width, 0.5),
          reason: 'o relogio usa hh:mm:ss fixo e figuras tabulares');
      expect(tenHours.width, closeTo(zero.width, 0.5));
      expect(oneHour.height, closeTo(zero.height, 0.5));
    });

    testWidgets('sempre mostra hh:mm:ss', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
          ),
          home: const Scaffold(body: Center(child: TimerDisplay(elapsedMs: 0))),
        ),
      );
      await tester.pump();

      expect(find.text('00:00:00'), findsOneWidget);
    });
  });

  group('Timer screen', () {
    testWidgets('o cabecalho ocupa a largura toda, entao nao e centralizado '
        'pelo conteudo', (tester) async {
      await _pumpTimer(tester);

      // O cabecalho e o primeiro Container com a cor de superficie; com
      // `width: double.infinity` ele preenche a janela. Sem isso ele encolhia
      // ate o conteudo e era centralizado pela Column, deslocando-se quando o
      // nome da materia mudava de tamanho.
      final header = find.byKey(TimerScreen.headerKey);

      expect(header, findsOneWidget);
      final size = tester.getSize(header);
      expect(size.width, closeTo(1280, 1),
          reason: 'o cabecalho precisa ocupar a largura inteira da janela');
    });

    testWidgets('o relogio fica centrado na horizontal', (tester) async {
      await _pumpTimer(tester);

      final rect = tester.getRect(find.byType(TimerDisplay));
      final screenCenter = 1280 / 2;

      expect(rect.center.dx, closeTo(screenCenter, 1.0));
    });

    testWidgets('o relogio nao se move entre dois frames', (tester) async {
      await _pumpTimer(tester);
      final before = tester.getRect(find.byType(TimerDisplay));

      await tester.pump(const Duration(seconds: 2));
      final after = tester.getRect(find.byType(TimerDisplay));

      expect(after.left, closeTo(before.left, 0.5));
      expect(after.top, closeTo(before.top, 0.5));
      expect(after.width, closeTo(before.width, 0.5));
    });
  });
}