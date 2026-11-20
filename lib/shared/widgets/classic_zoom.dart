import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_palette.dart';
import '../../features/settings/settings_notifier.dart';

/// Zooms everything inside it, like a browser: Ctrl + / Ctrl - / Ctrl 0 and
/// Ctrl + mouse wheel. The scale is saved in settings.
///
/// The child is laid out at `size / scale` and painted scaled up, so text
/// stays sharp and hit testing follows the transform. While Ctrl is held,
/// lists stop reacting to the wheel so the wheel only zooms.
class ClassicZoom extends ConsumerStatefulWidget {
  const ClassicZoom({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ClassicZoom> createState() => _ClassicZoomState();
}

/// Base scale from the window size, before the user's zoom: a big landscape
/// window gets roomier, tablet-like sizing; a small or tall 9:16 window stays
/// at 1.0 so nothing is cut off.
double autoScale(Size size) {
  final basis = size.width * 0.6 < size.height ? size.width * 0.6 : size.height;
  return (basis / 760).clamp(1.0, 1.4);
}

class _ClassicZoomState extends ConsumerState<ClassicZoom> {
  static const double _step = 0.1;
  bool _ctrlHeld = false;
  bool _showBadge = false;
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _badgeTimer?.cancel();
    super.dispose();
  }

  void _zoom(double? delta) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final current = ref.read(settingsNotifierProvider).classicUiScale;
    notifier.setClassicUiScale(delta == null ? 1.0 : current + delta);
    _badgeTimer?.cancel();
    setState(() => _showBadge = true);
    _badgeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showBadge = false);
    });
  }

  bool _onKey(KeyEvent event) {
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl != _ctrlHeld && mounted) setState(() => _ctrlHeld = ctrl);
    if (event is KeyUpEvent || !ctrl) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoom(_step);
      return true;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      _zoom(-_step);
      return true;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _zoom(null);
      return true;
    }
    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !HardwareKeyboard.instance.isControlPressed) return;
    if (event.scrollDelta.dy == 0) return;
    _zoom(event.scrollDelta.dy < 0 ? _step : -_step);
  }

  @override
  Widget build(BuildContext context) {
    final userScale = ref.watch(settingsNotifierProvider.select((s) => s.classicUiScale));
    final palette = context.palette;
    Widget child = widget.child;
    if (_ctrlHeld) {
      child = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(physics: const NeverScrollableScrollPhysics()),
        child: child,
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _onPointerSignal,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, c) {
              final scale = userScale * autoScale(Size(c.maxWidth, c.maxHeight));
              if ((scale - 1.0).abs() < 0.001) return child;
              final size = Size(c.maxWidth / scale, c.maxHeight / scale);
              return ClipRect(
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: size.width,
                    maxWidth: size.width,
                    minHeight: size.height,
                    maxHeight: size.height,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: size),
                      child: child,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_showBadge)
            Positioned(
              top: 10,
              right: 12,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('classic-zoom-badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text('${(userScale * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: palette.textPrimary)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
