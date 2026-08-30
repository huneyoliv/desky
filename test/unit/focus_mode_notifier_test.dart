import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/timer/focus_mode_notifier.dart';

void main() {
  group('FocusModeNotifier Tests', () {
    late FocusModeNotifier notifier;

    setUp(() {
      notifier = FocusModeNotifier();
    });

    test('initial state has all focus modes disabled', () {
      expect(notifier.state.isStrictFocus, isFalse);
      expect(notifier.state.isMiniPlayer, isFalse);
      expect(notifier.state.isFullscreen, isFalse);
    });

    test('toggleStrictFocus toggles isStrictFocus', () async {
      await notifier.toggleStrictFocus();
      expect(notifier.state.isStrictFocus, isTrue);

      await notifier.toggleStrictFocus();
      expect(notifier.state.isStrictFocus, isFalse);
    });

    test('toggleMiniPlayer activates mini player and strict focus', () async {
      await notifier.toggleMiniPlayer();
      expect(notifier.state.isMiniPlayer, isTrue);
      expect(notifier.state.isStrictFocus, isTrue);

      await notifier.toggleMiniPlayer();
      expect(notifier.state.isMiniPlayer, isFalse);
    });

    test('exitFocusModes resets all focus states to false', () async {
      await notifier.toggleStrictFocus();
      await notifier.toggleMiniPlayer();
      expect(notifier.state.isMiniPlayer, isTrue);

      await notifier.exitFocusModes();
      expect(notifier.state.isStrictFocus, isFalse);
      expect(notifier.state.isMiniPlayer, isFalse);
      expect(notifier.state.isFullscreen, isFalse);
    });
  });
}
