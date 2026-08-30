import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/notification_repository.dart';
import 'notification_panel_dialog.dart';

class NotificationBell extends ConsumerStatefulWidget {
  final double size;

  const NotificationBell({
    super.key,
    this.size = 38,
  });

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  Timer? _pollingTimer;
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 4),
    ]).animate(CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut));

    _fetchUnread();

    // Auto-poll notifications every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchUnread();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _wobbleController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnread() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final count = await repo.fetchUnreadCount();
      if (mounted) {
        setState(() => _unreadCount = count);
        if (count > 0 && !_wobbleController.isAnimating) {
          _wobbleController.repeat();
        } else if (count == 0 && _wobbleController.isAnimating) {
          _wobbleController.stop();
          _wobbleController.reset();
        }
      }
    } catch (_) {}
  }

  void _openNotifications() {
    setState(() {
      _unreadCount = 0;
      _wobbleController.stop();
      _wobbleController.reset();
    });
    NotificationPanelDialog.show(context).then((_) {
      _fetchUnread();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _openNotifications,
            customBorder: const CircleBorder(),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: _unreadCount > 0
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _wobbleAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _wobbleAnimation.value * math.pi,
                      child: child,
                    );
                  },
                  child: Icon(
                    Icons.notifications_outlined,
                    color: _unreadCount > 0 ? AppColors.primaryLight : Colors.white70,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
