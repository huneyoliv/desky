import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/notification_repository.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/features/timer/widgets/timer_display.dart';
import 'package:desky/shared/widgets/app_shell.dart';
import 'package:desky/shared/widgets/app_title_bar.dart';

class _OfflineTimerNotifier extends TimerNotifier {
  _OfflineTimerNotifier()
      : super(
          timerRepository: TimerRepository(),
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

void main() {
  testWidgets('timer remains usable at half-screen and minimum sizes',
      (tester) async {
    for (final size in const [Size(960, 540), Size(640, 480)]) {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final notifier = _OfflineTimerNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timerNotifierProvider.overrideWith((ref) => notifier),
            appTranslationProvider.overrideWith(
              (ref) => AppTranslationNotifier(ref)
                ..state = const AppTranslation(languageCode: 'pt'),
            ),
          ],
          child: const MaterialApp(home: TimerScreen()),
        ),
      );
      await tester.pump();
      notifier.selectSubject(const SubjectModel(
        id: 1,
        title: 'Sociology',
        colorInt: 4292557552,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'overflow in $size');
      expect(
        tester.getSize(find.byKey(TimerScreen.headerKey)).width,
        closeTo(size.width, 1),
      );
      final clock = tester.getRect(find.byType(TimerDisplay));
      expect(clock.left, greaterThanOrEqualTo(0));
      expect(clock.right, lessThanOrEqualTo(size.width));
      expect(clock.top, greaterThanOrEqualTo(0));
      expect(clock.bottom, lessThanOrEqualTo(size.height));
      notifier.dispose();
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('full shell survives live resize without losing timer state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = _OfflineTimerNotifier();
    const subject = SubjectModel(
      id: 1,
      title: 'Sociology',
      colorInt: 4292557552,
    );

    tester.view.physicalSize = const Size(1280, 800);
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
          unreadNotificationCountProvider.overrideWith((ref) => 0),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)
              ..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: const MaterialApp(
          home: Material(
            child: Column(
              children: [
                AppTitleBar(title: 'Desky', showUpdateButton: false),
                Expanded(
                  child: AppShell(
                    currentRoute: '/home',
                    child: TimerScreen(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    notifier.selectSubject(subject);
    notifier.setTimerMode(TimerMode.pomodoro);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );

    void expectInsideViewport(Finder finder, String label, Size size) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$label left at $size');
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$label top at $size');
      expect(
        rect.right,
        lessThanOrEqualTo(size.width),
        reason: '$label right at $size: $rect',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(size.height),
        reason: '$label bottom at $size: $rect',
      );
    }

    // Only the viewport changes: the same ProviderContainer, AppShell and
    // TimerNotifier stay mounted throughout the sequence.
    for (final size in const [
      Size(1280, 800),
      Size(960, 540),
      Size(640, 480),
      Size(1280, 800),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull, reason: 'layout failed at $size');
      expect(tester.getSize(find.byType(AppTitleBar)).height, 32);
      expectInsideViewport(find.byType(AppTitleBar), 'title bar', size);
      expectInsideViewport(find.byIcon(Icons.close), 'close button', size);
      expectInsideViewport(
        find.byKey(TimerScreen.headerKey),
        'timer header',
        size,
      );
      expectInsideViewport(
        find.byKey(TimerScreen.modeSwitcherKey),
        'mode switcher',
        size,
      );
      expectInsideViewport(find.byType(TimerDisplay), 'timer display', size);

      final action = find.byType(ElevatedButton);
      expect(action, findsOneWidget);
      expectInsideViewport(action, 'primary action', size);
      expect(tester.widget<ElevatedButton>(action).onPressed, isNotNull);
      expect(tester.hitTestOnBinding(tester.getCenter(action)).path, isNotEmpty);

      expect(identical(container.read(timerNotifierProvider.notifier), notifier), isTrue);
      expect(notifier.state.currentSubject, same(subject));
      expect(notifier.state.mode, TimerMode.pomodoro);
      expect(notifier.state.isRunning, isFalse);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    notifier.dispose();
  });
}
