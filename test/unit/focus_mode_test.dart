import 'package:desky/features/timer/focus_mode_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Focus Mode Desktop Tests', () {
    test('FocusModeNotifier initial state has all modes disabled', () {
      final notifier = FocusModeNotifier();

      expect(notifier.state.isStrictFocus, false);
      expect(notifier.state.isMiniPlayer, false);
      expect(notifier.state.isFullscreen, false);
    });

    test('toggleStrictFocus toggles strict focus mode state', () async {
      final notifier = FocusModeNotifier();

      await notifier.toggleStrictFocus();
      expect(notifier.state.isStrictFocus, true);

      await notifier.toggleStrictFocus();
      expect(notifier.state.isStrictFocus, false);
    });

    test('toggleMiniPlayer enables mini player and strict focus', () async {
      final notifier = FocusModeNotifier();

      await notifier.toggleMiniPlayer();
      expect(notifier.state.isMiniPlayer, true);
      expect(notifier.state.isStrictFocus, true);

      await notifier.toggleMiniPlayer();
      expect(notifier.state.isMiniPlayer, false);
    });

    test('exitFocusModes restores default desktop state', () async {
      final notifier = FocusModeNotifier();

      await notifier.toggleStrictFocus();
      await notifier.toggleFullscreen();
      expect(notifier.state.isStrictFocus, true);
      expect(notifier.state.isFullscreen, true);

      await notifier.exitFocusModes();
      expect(notifier.state.isStrictFocus, false);
      expect(notifier.state.isMiniPlayer, false);
      expect(notifier.state.isFullscreen, false);
    });
  });
}
