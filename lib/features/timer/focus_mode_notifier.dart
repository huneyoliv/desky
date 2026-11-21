import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/window/window_state.dart';

class FocusModeState {
  final bool isStrictFocus;
  final bool isMiniPlayer;
  final bool isFullscreen;

  /// Mini player shows the Today/Week focus row under the timer.
  final bool miniExpanded;

  const FocusModeState({
    this.isStrictFocus = false,
    this.isMiniPlayer = false,
    this.isFullscreen = false,
    this.miniExpanded = false,
  });

  FocusModeState copyWith({
    bool? isStrictFocus,
    bool? isMiniPlayer,
    bool? isFullscreen,
    bool? miniExpanded,
  }) {
    return FocusModeState(
      isStrictFocus: isStrictFocus ?? this.isStrictFocus,
      isMiniPlayer: isMiniPlayer ?? this.isMiniPlayer,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      miniExpanded: miniExpanded ?? this.miniExpanded,
    );
  }
}

/// Sizes of the floating mini player (TickTick-style).
const Size kMiniCompactSize = Size(320, 116);
const Size kMiniExpandedSize = Size(320, 184);

class FocusModeNotifier extends StateNotifier<FocusModeState> {
  FocusModeNotifier() : super(const FocusModeState());

  /// Window bounds and flags from before the mini player, restored on exit.
  Rect? _savedBounds;
  bool _savedMaximized = false;
  bool _savedStrict = false;
  bool _busy = false;

  Future<void> toggleStrictFocus() async {
    final next = !state.isStrictFocus;
    state = state.copyWith(isStrictFocus: next);
  }

  Future<void> toggleFullscreen() async {
    final next = !state.isFullscreen;
    state = state.copyWith(isFullscreen: next);
    try {
      await windowManager.setFullScreen(next);
    } catch (_) {}
  }

  Future<void> toggleMiniPlayer() => state.isMiniPlayer ? _exitMini() : _enterMini();

  Future<void> toggleMiniExpanded() async {
    final next = !state.miniExpanded;
    state = state.copyWith(miniExpanded: next);
    try {
      final b = await windowManager.getBounds();
      final size = next ? kMiniExpandedSize : kMiniCompactSize;
      // Grow downwards, but stay on screen when the window sits low.
      var top = b.top;
      final display = await _displayFor(b);
      if (display != null && top + size.height > display.bottom) top = display.bottom - size.height;
      await windowManager.setBounds(Rect.fromLTWH(b.left, top, size.width, size.height));
    } catch (_) {}
  }

  Future<void> _enterMini() async {
    if (_busy) return;
    _busy = true;
    try {
      try {
        _savedMaximized = await windowManager.isMaximized();
        if (_savedMaximized) await windowManager.unmaximize();
        if (await windowManager.isFullScreen()) await windowManager.setFullScreen(false);
        _savedBounds = await windowManager.getBounds();
      } catch (_) {}
      // Mini player implies strict focus, as before; the previous value comes
      // back on exit.
      _savedStrict = state.isStrictFocus;
      state = state.copyWith(isMiniPlayer: true, isStrictFocus: true, isFullscreen: false);
      try {
        final size = state.miniExpanded ? kMiniExpandedSize : kMiniCompactSize;
        await windowManager.setMinimumSize(const Size(200, 60));
        await windowManager.setResizable(false);
        await windowManager.setAlwaysOnTop(true);
        if (Platform.isMacOS) await windowManager.setBackgroundColor(Colors.transparent);
        // Top-right of the screen the app is on, like TickTick's widget.
        final display = _savedBounds == null ? null : await _displayFor(_savedBounds!);
        final origin = display == null
            ? null
            : Offset(display.right - size.width - 24, display.top + 80);
        await windowManager.setBounds(origin == null
            ? Rect.fromLTWH(_savedBounds?.left ?? 100, _savedBounds?.top ?? 100, size.width, size.height)
            : origin & size);
      } catch (_) {}
    } finally {
      _busy = false;
    }
  }

  Future<void> _exitMini() async {
    if (_busy) return;
    _busy = true;
    try {
      state = state.copyWith(isMiniPlayer: false, isStrictFocus: _savedStrict);
      try {
        await windowManager.setOpacity(1);
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        await windowManager.setMinimumSize(kMinimumUsableWindowSize);
        await windowManager.setBounds(_savedBounds ?? (Offset.zero & kDefaultWindowSize));
        if (_savedBounds == null) await windowManager.center();
        if (_savedMaximized) await windowManager.maximize();
      } catch (_) {}
    } finally {
      _busy = false;
    }
  }

  Future<void> exitFocusModes() async {
    if (state.isMiniPlayer) await _exitMini();
    final wasFullscreen = state.isFullscreen;
    state = const FocusModeState();
    if (wasFullscreen) {
      try {
        await windowManager.setFullScreen(false);
      } catch (_) {}
    }
  }

  /// Visible area of the display that holds most of [bounds].
  static Future<Rect?> _displayFor(Rect bounds) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      return MiniDock.displayAreaFor(bounds, [for (final d in displays) _visibleRect(d)]);
    } catch (_) {
      return null;
    }
  }

  static Rect _visibleRect(Display d) {
    final pos = d.visiblePosition ?? Offset.zero;
    final size = d.visibleSize ?? d.size;
    return pos & size;
  }

  static Future<List<Rect>> displayAreas() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      return [for (final d in displays) _visibleRect(d)];
    } catch (_) {
      return const [];
    }
  }
}

enum MiniDockSide { none, left, right }

/// Pure geometry for docking the mini player to a screen edge, kept apart
/// from the window calls so it can be tested.
class MiniDock {
  MiniDock._();

  /// How close to an edge counts as "dropped on the edge".
  static const double snapDistance = 16;

  /// Width left on screen while hidden: the grab handle.
  static const double handleWidth = 10;

  static Rect? displayAreaFor(Rect bounds, List<Rect> displays) {
    if (displays.isEmpty) return null;
    Rect best = displays.first;
    var bestArea = -1.0;
    for (final d in displays) {
      final i = d.intersect(bounds);
      final area = i.width > 0 && i.height > 0 ? i.width * i.height : 0.0;
      if (area > bestArea) {
        bestArea = area;
        best = d;
      }
    }
    if (bestArea <= 0) {
      // Fully off-screen (e.g. already hidden): nearest display by centre.
      best = displays.reduce((a, b) =>
          (a.center - bounds.center).distance <= (b.center - bounds.center).distance ? a : b);
    }
    return best;
  }

  /// Which edge the window was dropped on. An edge shared with another
  /// monitor does not dock: hiding there would put it on the other screen.
  static MiniDockSide sideFor(Rect bounds, Rect display, List<Rect> displays) {
    bool neighbour(double x) =>
        displays.any((d) => d != display && d.contains(Offset(x, bounds.center.dy)));
    if (bounds.left <= display.left + snapDistance && !neighbour(display.left - 20)) return MiniDockSide.left;
    if (bounds.right >= display.right - snapDistance && !neighbour(display.right + 20)) return MiniDockSide.right;
    return MiniDockSide.none;
  }

  /// Window position when shown against [side] or tucked away behind it.
  static Offset positionFor(MiniDockSide side, Rect bounds, Rect display, {required bool hidden}) {
    final y = bounds.top.clamp(display.top, display.bottom - bounds.height).toDouble();
    switch (side) {
      case MiniDockSide.left:
        return Offset(hidden ? display.left - bounds.width + handleWidth : display.left, y);
      case MiniDockSide.right:
        return Offset(hidden ? display.right - handleWidth : display.right - bounds.width, y);
      case MiniDockSide.none:
        return bounds.topLeft;
    }
  }
}

final focusModeProvider =
    StateNotifierProvider<FocusModeNotifier, FocusModeState>((ref) {
  return FocusModeNotifier();
});
