import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/package_helper.dart';
import '../../features/updates/widgets/update_button.dart';

class AppTitleBar extends ConsumerStatefulWidget {
  final String title;
  final bool showUpdateButton;

  const AppTitleBar({
    super.key,
    this.title = 'Desky',
    this.showUpdateButton = true,
  });

  @override
  ConsumerState<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends ConsumerState<AppTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (mounted && _isMaximized != isMax) {
        setState(() {
          _isMaximized = isMax;
        });
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    _checkMaximized();
  }

  @override
  void onWindowUnmaximize() {
    _checkMaximized();
  }

  @override
  void onWindowRestore() {
    _checkMaximized();
  }

  @override
  void onWindowDocked() {
    _checkMaximized();
  }

  @override
  void onWindowUndocked() {
    _checkMaximized();
  }

  @override
  void onWindowEnterFullScreen() {
    _checkMaximized();
  }

  @override
  void onWindowLeaveFullScreen() {
    _checkMaximized();
  }

  Future<void> _toggleMaximize() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
      await _checkMaximized();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Container(
      height: 32,
      color: AppColors.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: const SizedBox(
                height: 32,
              ),
            ),
          ),
          if (widget.showUpdateButton && !PackageHelper.isStoreOrMsix)
            const UpdateButton(
              height: 22,
              padding: EdgeInsets.only(right: 8),
            ),
          _TitleBarButton(
            tooltip: t.tr('minimize', fallback: 'Minimizar'),
            onTap: () => windowManager.minimize(),
            child: const _MinimizeIcon(color: Colors.white70),
          ),
          _TitleBarButton(
            tooltip: _isMaximized
                ? t.tr('restore', fallback: 'Restaurar')
                : t.tr('maximize', fallback: 'Maximizar'),
            onTap: _toggleMaximize,
            child: _MaximizeRestoreIcon(
              isMaximized: _isMaximized,
              color: Colors.white70,
            ),
          ),
          _TitleBarButton(
            tooltip: t.tr('close', fallback: 'Fechar'),
            hoverColor: const Color(0xFFE81123),
            onTap: () => windowManager.close(),
            child: const _CloseIcon(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final Color? hoverColor;

  const _TitleBarButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.hoverColor,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveHoverColor = widget.hoverColor ?? Colors.white.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? effectiveHoverColor : Colors.transparent,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _MinimizeIcon extends StatelessWidget {
  final Color color;

  const _MinimizeIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 1,
      color: color,
    );
  }
}

class _MaximizeRestoreIcon extends StatelessWidget {
  final bool isMaximized;
  final Color color;

  const _MaximizeRestoreIcon({
    required this.isMaximized,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(10, 10),
      painter: _MaximizeRestorePainter(
        isMaximized: isMaximized,
        color: color,
      ),
    );
  }
}

class _MaximizeRestorePainter extends CustomPainter {
  final bool isMaximized;
  final Color color;

  _MaximizeRestorePainter({
    required this.isMaximized,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (!isMaximized) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } else {
      final path = Path();
      path.moveTo(2, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height - 2);
      canvas.drawPath(path, paint);

      canvas.drawRect(Rect.fromLTWH(0, 2, size.width - 2, size.height - 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MaximizeRestorePainter oldDelegate) {
    return oldDelegate.isMaximized != isMaximized || oldDelegate.color != color;
  }
}

class _CloseIcon extends StatelessWidget {
  final Color color;

  const _CloseIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.close,
      size: 14,
      color: color,
    );
  }
}
