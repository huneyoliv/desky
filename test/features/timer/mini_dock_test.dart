import 'package:desky/features/timer/focus_mode_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Rect.fromLTWH(0, 0, 1920, 1040);
  const size = Size(320, 116);

  test('dropping on the left or right edge docks; the middle does not', () {
    expect(MiniDock.sideFor(const Offset(4, 300) & size, screen, [screen]), MiniDockSide.left);
    expect(MiniDock.sideFor(const Offset(1920 - 320 - 6, 300) & size, screen, [screen]), MiniDockSide.right);
    expect(MiniDock.sideFor(const Offset(800, 300) & size, screen, [screen]), MiniDockSide.none);
  });

  test('an edge shared with a second monitor never docks', () {
    const right = Rect.fromLTWH(1920, 0, 1920, 1080);
    expect(MiniDock.sideFor(const Offset(1920 - 320, 300) & size, screen, [screen, right]), MiniDockSide.none);
    expect(MiniDock.sideFor(const Offset(0, 300) & size, screen, [screen, right]), MiniDockSide.left);
  });

  test('hidden leaves only the handle on screen, shown sits flush', () {
    final b = const Offset(0, 300) & size;
    expect(MiniDock.positionFor(MiniDockSide.left, b, screen, hidden: true).dx, -320 + MiniDock.handleWidth);
    expect(MiniDock.positionFor(MiniDockSide.left, b, screen, hidden: false).dx, 0);
    final r = const Offset(1600, 300) & size;
    expect(MiniDock.positionFor(MiniDockSide.right, r, screen, hidden: true).dx, 1920 - MiniDock.handleWidth);
    expect(MiniDock.positionFor(MiniDockSide.right, r, screen, hidden: false).dx, 1600);
  });

  test('a hidden window (off screen) still resolves to its display', () {
    const right = Rect.fromLTWH(1920, 0, 1920, 1080);
    final hidden = Offset(-310, 300) & size;
    expect(MiniDock.displayAreaFor(hidden, [screen, right]), screen);
  });

  test('vertical position is kept on screen', () {
    final low = const Offset(0, 1000) & size;
    expect(MiniDock.positionFor(MiniDockSide.left, low, screen, hidden: false).dy, 1040 - 116);
  });
}
