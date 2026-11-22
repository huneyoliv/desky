import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Keeps the window capturable by OBS when the user "minimizes" it.
///
/// A truly minimized window stops being drawn: Windows gives it no surface and
/// Flutter stops producing frames, so an OBS Window Capture freezes or goes
/// black. In overlay mode the Windows runner (see `flutter_window.cpp`) turns
/// every minimize request (title bar button, taskbar click, Alt+Space menu)
/// into "send to the back of the z-order": the window gets out of the way but
/// keeps rendering, and OBS keeps capturing it.
class OverlayWindowChannel {
  OverlayWindowChannel._();

  static const MethodChannel channel = MethodChannel('dev.desky/window');

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// Tells the native runner whether minimize requests become "send to back".
  static Future<void> setOverlayMode(bool enabled) async {
    if (!isSupported) return;
    try {
      await channel.invokeMethod<void>('setOverlayMode', enabled);
    } catch (_) {}
  }

  /// Called by the title bar's minimize button.
  static Future<void> minimize({required bool overlayMode}) async {
    if (overlayMode && isSupported) {
      try {
        await channel.invokeMethod<void>('sendToBack');
        return;
      } catch (_) {
        // Older runner without the channel: fall back to a real minimize.
      }
    }
    await windowManager.minimize();
  }
}
