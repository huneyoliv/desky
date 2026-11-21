import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_screen.dart';
import 'package:desky/features/timer/widgets/timer_display.dart';

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
}
