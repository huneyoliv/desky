import 'package:desky/core/window/window_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const primary = Rect.fromLTWH(0, 0, 1920, 1040);
  const left = Rect.fromLTWH(-2560, 0, 2560, 1400); // second monitor on the left

  test('reopens on the monitor and spot it was closed on', () {
    final r = resolveWindowPlacement(
      storedPosition: const Offset(-2400, 120),
      size: const Size(1800, 1100),
      displays: [primary, left],
    );
    expect(r.display, left);
    expect(r.position, const Offset(-2400, 120));
  });

  test('a monitor that is gone falls back to centring on the primary', () {
    final r = resolveWindowPlacement(
      storedPosition: const Offset(-2400, 120),
      size: const Size(1800, 1100),
      displays: [primary],
    );
    expect(r.display, isNull);
    expect(r.position, isNull);
  });

  test('a window hanging off its monitor is pulled back inside it', () {
    final r = resolveWindowPlacement(
      storedPosition: const Offset(1500, 100),
      size: const Size(1280, 800),
      displays: [primary, left],
    );
    expect(r.display, primary);
    expect(r.position!.dx, 1920 - 1280);
  });

  test('size is limited by the monitor it reopens on, not the primary', () {
    final r = resolveWindowPlacement(
      storedPosition: const Offset(-2400, 120),
      size: const Size(2400, 1300),
      displays: [primary, left],
    );
    final state = resolveWindowState(
      storedSize: const Size(2400, 1300),
      storedMaximized: false,
      visibleArea: r.display!.size,
    );
    expect(state.size, const Size(2400, 1300));
  });

  test('invalid stored size cannot push the default window off screen', () {
    const display = Rect.fromLTWH(0, 0, 1280, 800);
    final placement = resolveWindowPlacement(
      storedPosition: const Offset(1000, 700),
      size: const Size(1, 1),
      displays: [display],
    );
    final restored = resolveWindowState(
      storedSize: const Size(1, 1),
      storedMaximized: false,
      visibleArea: placement.display?.size,
    );
    expect(restored.size, kDefaultWindowSize);
    expect(placement.position, Offset.zero);
  });

  test('no saved position keeps the old behaviour', () {
    final r = resolveWindowPlacement(storedPosition: null, size: kDefaultWindowSize, displays: [primary]);
    expect(r.position, isNull);
  });
}
