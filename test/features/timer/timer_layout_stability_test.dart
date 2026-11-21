import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/constants/api_constants.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/features/timer/widgets/timer_display.dart';

class _OfflineSettingsNotifier extends SettingsNotifier {
  _OfflineSettingsNotifier() : super(SettingsRepository());

  @override
  Future<void> init() async {}
}

/// Answers the study endpoints locally: a real repository would issue HTTP
/// requests that never settle under the test binding, hanging the run.
class _OfflineTimerRepository extends TimerRepository {
  int startCalls = 0;

  @override
  Future<bool> startStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime startAt,
    int? taskId,
  }) async {
    startCalls++;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> stopStudy({
    required String subjectTitle,
    required int subjectId,
    required DateTime stopAt,
    required int studyMs,
    required DateTime startAt,
  }) async {
    return null;
  }

  @override
  Future<bool> recordRest({
    required DateTime startAt,
    required DateTime stopAt,
    required int restMs,
    String deviceModel = ApiConstants.defaultDeviceModel,
  }) async {
    return true;
  }
}

/// Keeps this geometry test offline while exercising the real mode/subject
/// transitions on TimerNotifier.
class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: _OfflineTimerRepository(),
          subjectRepository: SubjectRepository(),
        );

  @override
  Future<void> loadSubjects() async {}

  @override
  Future<void> reconcileWithServer() async {}

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class _LoadedTranslationNotifier extends AppTranslationNotifier {
  _LoadedTranslationNotifier(super.ref, AppTranslation translation) {
    state = translation;
  }

  // Impede o _init da classe base de trocar o idioma em segundo plano.
  @override
  Future<void> loadLanguage(String code) async {}
}

/// The Timer screen doubles as an OBS window-capture overlay: the window is
/// cropped once and elements must not move afterwards. These tests measure the
/// rendered geometry, because "it looks stable" is not evidence.
Future<ProviderContainer> _pumpTimer(
  WidgetTester tester, {
  _OfflineTimerNotifier? notifier,
  Size physicalSize = const Size(1280, 800),
  String languageCode = 'pt',
}) async {
  SharedPreferences.setMockInitialValues({});
  final normalizedLanguage = AppTranslation.normalizeCode(languageCode);
  final decoded = json.decode(
    File('assets/translations/$normalizedLanguage.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final translation = AppTranslation(
    languageCode: normalizedLanguage,
    translations: decoded.map((key, value) => MapEntry(key, '$value')),
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final container = ProviderContainer(
    overrides: [
      settingsNotifierProvider.overrideWith(
        (ref) => _OfflineSettingsNotifier(),
      ),
      // Sempre substitui o notifier: sem um fake explicito tambem usamos o
      // double offline, evitando GETs autenticados e logs com dados da conta.
      timerNotifierProvider.overrideWith(
        (ref) => notifier ?? _OfflineTimerNotifier(),
      ),
      appTranslationProvider.overrideWith(
        (ref) => _LoadedTranslationNotifier(ref, translation),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    testWidgets(
        'o cabecalho ocupa a largura toda, entao nao e centralizado '
        'pelo conteudo', (tester) async {
      final container = await _pumpTimer(tester);

      // O cabecalho e o primeiro Container com a cor de superficie; com
      // `width: double.infinity` ele preenche a janela. Sem isso ele encolhia
      // ate o conteudo e era centralizado pela Column, deslocando-se quando o
      // nome da materia mudava de tamanho.
      final header = find.byKey(TimerScreen.headerKey);

      expect(header, findsOneWidget);
      final size = tester.getSize(header);
      expect(size.width, closeTo(1280, 1),
          reason: 'o cabecalho precisa ocupar a largura inteira da janela');
      container.dispose();
    });

    testWidgets('o seletor Timer/Pomodoro fica no centro em qualquer largura',
        (tester) async {
      for (final size in const [
        Size(1280, 800),
        Size(960, 540),
        Size(640, 480),
      ]) {
        final container = await _pumpTimer(
          tester,
          notifier: _OfflineTimerNotifier(),
          physicalSize: size,
        );
        try {
          final header = tester.getRect(find.byKey(TimerScreen.headerKey));
          final switcher = tester.getRect(
            find.byKey(TimerScreen.modeSwitcherKey),
          );

          expect(
            switcher.center.dx,
            closeTo(header.center.dx, 0.5),
            reason: 'o seletor ficou descentralizado em ${size.width}px',
          );
          expect(switcher.left, greaterThanOrEqualTo(0));
          expect(switcher.right, lessThanOrEqualTo(size.width));
        } finally {
          container.dispose();
        }
      }
    });

    testWidgets('o relogio fica centrado na horizontal', (tester) async {
      final container = await _pumpTimer(tester);

      final rect = tester.getRect(find.byType(TimerDisplay));
      final screenCenter = 1280 / 2;

      expect(rect.center.dx, closeTo(screenCenter, 1.0));
      container.dispose();
    });

    testWidgets('o relogio nao se move entre dois frames', (tester) async {
      final container = await _pumpTimer(tester);
      final before = tester.getRect(find.byType(TimerDisplay));

      await tester.pump(const Duration(seconds: 2));
      final after = tester.getRect(find.byType(TimerDisplay));

      expect(after.left, closeTo(before.left, 0.5));
      expect(after.top, closeTo(before.top, 0.5));
      expect(after.width, closeTo(before.width, 0.5));
      container.dispose();
    });

    testWidgets('materia e modo preservam geometria do cabecalho e do timer',
        (tester) async {
      final notifier = _OfflineTimerNotifier();
      final container = await _pumpTimer(tester, notifier: notifier);

      notifier.selectSubject(const SubjectModel(
        id: 1,
        title: 'Sociology',
        colorInt: 4292557552,
      ));
      await tester.pump();

      final header = tester.getRect(find.byKey(TimerScreen.headerKey));
      final clock = tester.getRect(find.byType(TimerDisplay));
      final startButton = tester.getSize(
        find.widgetWithText(ElevatedButton, 'INICIAR'),
      );

      notifier.selectSubject(const SubjectModel(
        id: 2,
        title: 'GS4',
        colorInt: 4292557552,
      ));
      await tester.pump();

      expect(tester.getRect(find.byKey(TimerScreen.headerKey)), equals(header));
      expect(tester.getRect(find.byType(TimerDisplay)), equals(clock));

      notifier.setTimerMode(TimerMode.pomodoro);
      await tester.pump();

      expect(tester.getRect(find.byKey(TimerScreen.headerKey)), equals(header));
      expect(tester.getRect(find.byType(TimerDisplay)), equals(clock));
      expect(
        tester.getSize(find.widgetWithText(ElevatedButton, 'INICIAR FOCO')),
        equals(startButton),
      );

      notifier.setTimerMode(TimerMode.stopwatch);
      await tester.pump();

      expect(tester.getRect(find.byType(TimerDisplay)), equals(clock));
      expect(
        tester.getSize(find.widgetWithText(ElevatedButton, 'INICIAR')),
        equals(startButton),
      );
      container.dispose();
    });

    testWidgets('botao de 296 px acomoda os rotulos nos 11 idiomas',
        (tester) async {
      const languages = [
        'pt',
        'en',
        'es',
        'ko',
        'ja',
        'zh-CN',
        'zh-TW',
        'fr',
        'de',
        'it',
        'ru',
      ];
      final failures = <String>[];

      for (final language in languages) {
        for (final mode in [TimerMode.stopwatch, TimerMode.pomodoro]) {
          final notifier = _OfflineTimerNotifier();
          late final ProviderContainer container;
          try {
            container = await _pumpTimer(
              tester,
              notifier: notifier,
              languageCode: language,
            );
            notifier.selectSubject(const SubjectModel(
              id: 1,
              title: 'Sociology',
              colorInt: 4292557552,
            ));
            notifier.setTimerMode(mode);
            await tester.pump();
            await tester.pump();

            final button = find.byType(ElevatedButton);
            final buttonRect = tester.getRect(button);
            final label = tester.widget<Text>(
              find.descendant(
                of: button,
                matching: find.byType(Text),
              ),
            );
            final labelRect = tester.getRect(find.byWidget(label));
            debugPrint(
              'BUTTON $language $mode state=${notifier.state.mode} '
              'text=${label.data} '
              'button=${buttonRect.width} label=${labelRect.width}',
            );
            expect(buttonRect.width, closeTo(296, 0.01));
            expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
            expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
            expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
            expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
          } catch (error) {
            failures.add('$language/$mode: $error');
          } finally {
            notifier.dispose();
            container.dispose();
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets(
        'o texto do Pomodoro fica centrado no banner, com e sem o botao Pular',
        (tester) async {
      final notifier = _OfflineTimerNotifier();
      final container = await _pumpTimer(tester, notifier: notifier);

      notifier.selectSubject(const SubjectModel(
        id: 1,
        title: 'Sociology',
        colorInt: 4292557552,
      ));
      notifier.setTimerMode(TimerMode.pomodoro);
      await tester.pump();

      final banner = find.byKey(TimerScreen.pomodoroBannerKey);
      final status = find.byKey(TimerScreen.pomodoroStatusKey);
      expect(banner, findsOneWidget);
      expect(status, findsOneWidget);

      double centreOffset() => tester.getRect(status).center.dx -
          tester.getRect(banner).center.dx;

      // Nenhum botao "Pular" ainda: so o de configuracoes a direita.
      expect(centreOffset(), closeTo(0, 1.0),
          reason: 'o rotulo precisa ficar no centro do banner, nao a esquerda');
      final before = tester.getRect(status);

      await notifier.startStudy();
      await tester.pump();

      expect(find.widgetWithText(TextButton, 'Pular'), findsOneWidget);
      expect(centreOffset(), closeTo(0, 1.0),
          reason: 'o botao a direita nao pode empurrar o rotulo para a esquerda');
      expect(tester.getRect(status).center.dx, closeTo(before.center.dx, 0.5),
          reason: 'o rotulo nao se move quando o botao Pular aparece');

      notifier.dispose();
      container.dispose();
    });
  });
}
