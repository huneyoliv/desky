import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:desky/shared/widgets/classic_zoom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Ctrl +, Ctrl -, Ctrl 0 and Ctrl + wheel zoom and persist', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs: prefs);
    late SettingsNotifier notifier;
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [settingsNotifierProvider.overrideWith((ref) => notifier = SettingsNotifier(repo))],
      child: const MaterialApp(home: ClassicZoom(child: SizedBox.expand(key: ValueKey('content')))),
    ));
    await tester.pump();
    Size content() => tester.getSize(find.byKey(const ValueKey('content')));
    expect(content(), const Size(1000, 800));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(notifier.state.classicUiScale, 1.1);
    // Laid out smaller, painted bigger: everything looks 110 %.
    expect(content().width, closeTo(1000 / 1.1, 0.5));
    expect(find.text('110%'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(notifier.state.classicUiScale, 0.9);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await tester.pump();
    expect(notifier.state.classicUiScale, 1.0);

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(notifier.state.classicUiScale, 1.0);
    expect(await repo.getClassicUiScale(), 1.0);

    // Without Ctrl the wheel does not zoom.
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await tester.pump(const Duration(seconds: 2));
    expect(notifier.state.classicUiScale, 1.0);
  });
}
