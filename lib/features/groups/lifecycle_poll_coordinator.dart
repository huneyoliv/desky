import 'package:flutter/widgets.dart';

/// Pauses and resumes the group-screen poll timers with the app lifecycle.
///
/// Polling stops when the window is `hidden` (minimized or fully occluded) or
/// the app is `paused`/`detached` (mobile background), and resumes on `resumed`
/// with an immediate refresh. `inactive` (plain window focus loss) keeps
/// polling because the window is still visible, so alt-tab does not turn the
/// member list stale.
class LifecyclePollCoordinator with WidgetsBindingObserver {
  LifecyclePollCoordinator({
    required this.onResume,
    required this.onBackground,
  });

  /// Called on `resumed`: refresh immediately and restart the timers.
  final VoidCallback onResume;

  /// Called on `hidden`/`paused`/`detached`: stop the timers.
  final VoidCallback onBackground;

  bool _attached = false;

  /// Whether the observer is currently registered. Exposed so the attach /
  /// detach contract can be asserted without reaching into bindings.
  bool get isAttached => _attached;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResume();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        onBackground();
      case AppLifecycleState.inactive:
        break; // window still visible; keep polling
    }
  }
}