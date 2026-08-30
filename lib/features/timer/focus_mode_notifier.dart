import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class FocusModeState {
  final bool isStrictFocus;
  final bool isMiniPlayer;
  final bool isFullscreen;

  const FocusModeState({
    this.isStrictFocus = false,
    this.isMiniPlayer = false,
    this.isFullscreen = false,
  });

  FocusModeState copyWith({
    bool? isStrictFocus,
    bool? isMiniPlayer,
    bool? isFullscreen,
  }) {
    return FocusModeState(
      isStrictFocus: isStrictFocus ?? this.isStrictFocus,
      isMiniPlayer: isMiniPlayer ?? this.isMiniPlayer,
      isFullscreen: isFullscreen ?? this.isFullscreen,
    );
  }
}

class FocusModeNotifier extends StateNotifier<FocusModeState> {
  FocusModeNotifier() : super(const FocusModeState());

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

  Future<void> toggleMiniPlayer() async {
    final next = !state.isMiniPlayer;
    state = state.copyWith(
      isMiniPlayer: next,
      isStrictFocus: next ? true : state.isStrictFocus,
    );

    try {
      if (next) {
        await windowManager.setSize(const Size(360, 240));
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setResizable(false);
      } else {
        await windowManager.setSize(const Size(1280, 800));
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        await windowManager.center();
      }
    } catch (_) {}
  }

  Future<void> exitFocusModes() async {
    state = const FocusModeState();
    try {
      await windowManager.setFullScreen(false);
      await windowManager.setSize(const Size(1280, 800));
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
    } catch (_) {}
  }
}

final focusModeProvider =
    StateNotifierProvider<FocusModeNotifier, FocusModeState>((ref) {
  return FocusModeNotifier();
});
