import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translation.dart';
import '../../../core/theme/app_colors.dart';
import '../update_notifier.dart';
import 'update_dialog.dart';

import '../../../core/utils/package_helper.dart';

class UpdateButton extends ConsumerStatefulWidget {
  final double height;
  final EdgeInsetsGeometry padding;

  const UpdateButton({
    super.key,
    this.height = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  @override
  ConsumerState<UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends ConsumerState<UpdateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PackageHelper.isStoreOrMsix) {
      return const SizedBox.shrink();
    }

    final updateState = ref.watch(updateNotifierProvider);
    final t = ref.watch(appTranslationProvider);

    if (updateState.hasUpdate && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!updateState.hasUpdate && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    if (!updateState.hasUpdate && !updateState.isChecking) {
      return const SizedBox.shrink();
    }

    final label = t.tr('update_available', fallback: 'Atualização Disponível');
    final versionStr = updateState.latestRelease?.cleanVersion;
    final tooltipMsg = versionStr != null ? '$label ($versionStr)' : label;

    return Padding(
      padding: widget.padding,
      child: Tooltip(
        message: tooltipMsg,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (updateState.latestRelease != null) {
                UpdateDialog.show(context, updateState.latestRelease!);
              } else {
                ref.read(updateNotifierProvider.notifier).checkForUpdates();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: _isHovered
                    ? AppColors.success.withValues(alpha: 0.28)
                    : AppColors.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isHovered
                      ? AppColors.success
                      : AppColors.success.withValues(alpha: 0.65),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: updateState.hasUpdate ? _scaleAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: Icon(
                      updateState.hasUpdate
                          ? Icons.download_rounded
                          : Icons.sync_rounded,
                      color: AppColors.success,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

