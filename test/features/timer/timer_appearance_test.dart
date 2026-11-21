import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/theme/timer_appearance.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/settings/widgets/study_preferences_dialog.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/features/timer/widgets/timer_display.dart';

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: TimerRepository(),
          subjectRepository: SubjectRepository(),
        ) {
    state = const TimerState(
      subjects: [SubjectModel(id: 1, title: 'Sociology', colorInt: 4292557552)],
    );
  }

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

Future<_OfflineTimerNotifier> _pumpTimer(
  WidgetTester tester,
  Map<String, Object> preferences,
) async {
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  final notifier = _OfflineTimerNotifier();
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timerNotifierProvider.overrideWith((ref) => notifier),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false, splashFactory: InkRipple.splashFactory),
        home: const TimerScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gradient and bundled font are applied to the timer',
      (tester) async {
    final notifier = await _pumpTimer(tester, {
      SettingsRepository.keyTimerBackground: timerBackgroundAurora,
      SettingsRepository.keyTimerFont: timerFontPretendard,
    });

    expect(
      find.byKey(const ValueKey('timer-background-aurora')),
      findsOneWidget,
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(TimerDisplay),
        matching: find.byType(Text),
      ),
    );
    expect(text.style?.fontFamily, 'Pretendard');
    expect(tester.takeException(), isNull);
    notifier.dispose();
  });

  testWidgets('missing custom image falls back without breaking the timer',
      (tester) async {
    final notifier = await _pumpTimer(tester, {
      SettingsRepository.keyTimerBackground: timerBackgroundCustomImage,
      SettingsRepository.keyTimerBackgroundImagePath:
          'C:\\does-not-exist\\study.png',
    });

    expect(
      find.byKey(const ValueKey('timer-background-custom_image')),
      findsOneWidget,
    );
    expect(find.byType(TimerDisplay), findsOneWidget);
    expect(tester.takeException(), isNull);
    notifier.dispose();
  });

  testWidgets('valid local image renders behind the timer', (tester) async {
    await tester.runAsync(() async {
      final directory = Directory('build/test_timer_appearance_image');
      _OfflineTimerNotifier? notifier;
      try {
        await directory.create(recursive: true);
        final image = File('${directory.path}/valid.png');
        await image.writeAsBytes(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ));
        notifier = await _pumpTimer(tester, {
          SettingsRepository.keyTimerBackground: timerBackgroundCustomImage,
          SettingsRepository.keyTimerBackgroundImagePath: image.path,
        });
        await tester.pump(const Duration(seconds: 1));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TimerScreen)),
        );
        expect(container.read(settingsNotifierProvider).timerBackground,
            timerBackgroundCustomImage);
        expect(
          container.read(settingsNotifierProvider).timerBackgroundImagePath,
          image.path,
        );
        await tester.pump();
        final background = tester.widget<Stack>(
          find.byKey(const ValueKey('timer-background-custom_image')),
        );
        expect(background.children.whereType<Image>(), hasLength(1));
        expect(
          find.byKey(const ValueKey('timer-background-custom_image')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        notifier?.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        PaintingBinding.instance.imageCache.clear();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    });
  });

  testWidgets('preference dropdowns persist gradient and font',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(960, 650);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: StudyPreferencesDialog()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final background = find.byType(DropdownButton<String>).first;
    await tester.ensureVisible(background);
    await tester.tap(background);
    await tester.pump();
    await tester.tap(find.text('Aurora').last);
    await tester.pump();

    final font = find.byType(DropdownButton<String>).last;
    await tester.ensureVisible(font);
    await tester.tap(font);
    await tester.pump();
    await tester.tap(find.text('Pretendard').last);
    await tester.pump();

    expect(prefs.getString(SettingsRepository.keyTimerBackground),
        timerBackgroundAurora);
    expect(prefs.getString(SettingsRepository.keyTimerFont),
        timerFontPretendard);
  });
}
