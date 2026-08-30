import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_translation.dart';
import '../../data/models/notification_model.dart';
import 'notifications_notifier.dart';
import 'notifications_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(appTranslationProvider);
    final state = ref.watch(notificationsNotifierProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, tr, state, notifier),
          Expanded(
            child: state.isLoading && state.notifications.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : state.errorMessage != null && state.notifications.isEmpty
                    ? _buildErrorState(context, tr, state.errorMessage!, notifier)
                    : state.notifications.isEmpty
                        ? _buildEmptyState(context, tr)
                        : _buildNotificationsList(context, tr, state.notifications, notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppTranslation tr,
    NotificationsState state,
    NotificationsNotifier notifier,
  ) {
    final hasRead = state.notifications.any((n) => n.isRead);
    final hasUnread = state.unreadCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr.tr('notifications', fallback: 'Notificações'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (state.unreadCount > 0)
                  Text(
                    '${state.unreadCount} ${tr.tr('unread', fallback: 'não lidas')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasUnread)
            TextButton.icon(
              onPressed: () => notifier.markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.primary),
              label: Text(
                tr.tr('mark_all_read', fallback: 'Lidas'),
                style: const TextStyle(color: AppColors.primary, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          if (hasRead) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: tr.tr('clear_read', fallback: 'Limpar lidas'),
              onPressed: () => notifier.deleteAllRead(),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.textMuted),
              hoverColor: AppColors.error.withValues(alpha: 0.1),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr.tr('refresh', fallback: 'Atualizar'),
            onPressed: () => notifier.loadNotifications(),
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppTranslation tr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr.tr('no_notifications_title', fallback: 'Nenhuma notificação'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr.tr('no_notifications_subtitle', fallback: 'Você está em dia com todas as atualizações.'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppTranslation tr,
    String error,
    NotificationsNotifier notifier,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            error,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => notifier.loadNotifications(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(tr.tr('retry', fallback: 'Tentar novamente')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    AppTranslation tr,
    List<NotificationModel> notifications,
    NotificationsNotifier notifier,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aWeekAgo = today.subtract(const Duration(days: 7));

    final todayItems = <NotificationModel>[];
    final thisWeekItems = <NotificationModel>[];
    final earlierItems = <NotificationModel>[];

    for (final item in notifications) {
      final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      if (itemDate.isAtSameMomentAs(today)) {
        todayItems.add(item);
      } else if (itemDate.isAfter(aWeekAgo)) {
        thisWeekItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        if (todayItems.isNotEmpty) ...[
          _buildSectionHeader(tr.tr('today', fallback: 'Hoje')),
          ...todayItems.map((n) => _buildNotificationCard(n, notifier, tr)),
          const SizedBox(height: 16),
        ],
        if (thisWeekItems.isNotEmpty) ...[
          _buildSectionHeader(tr.tr('this_week', fallback: 'Esta semana')),
          ...thisWeekItems.map((n) => _buildNotificationCard(n, notifier, tr)),
          const SizedBox(height: 16),
        ],
        if (earlierItems.isNotEmpty) ...[
          _buildSectionHeader(tr.tr('earlier', fallback: 'Anteriores')),
          ...earlierItems.map((n) => _buildNotificationCard(n, notifier, tr)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationModel notification,
    NotificationsNotifier notifier,
    AppTranslation tr,
  ) {
    final iconData = _getNotificationIcon(notification.type);
    final iconColor = _getNotificationColor(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notification.isRead ? AppColors.surface : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? AppColors.border.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!notification.isRead) {
            notifier.markAsRead(notification.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(notification.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textMuted),
                onPressed: () => notifier.deleteNotification(notification.id),
                tooltip: tr.tr('delete', fallback: 'Excluir'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('SHAKE') || upper.contains('WAKE') || upper.contains('NUDGE')) {
      return Icons.vibration_rounded;
    }
    if (upper.contains('WARNING') || upper.contains('EXPEL') || upper.contains('OUT')) {
      return Icons.warning_amber_rounded;
    }
    if (upper.contains('JOIN') || upper.contains('APPROVED') || upper.contains('INVITE')) {
      return Icons.group_add_rounded;
    }
    if (upper.contains('GROUP') || upper.contains('MEMBER') || upper.contains('SOCIAL')) {
      return Icons.groups_outlined;
    }
    if (upper.contains('CHAT') || upper.contains('MESSAGE')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (upper.contains('ALARM') || upper.contains('TIMER') || upper.contains('STUDY')) {
      return Icons.alarm_rounded;
    }
    if (upper.contains('ACHIEVEMENT') || upper.contains('RANK') || upper.contains('GOAL')) {
      return Icons.emoji_events_outlined;
    }
    if (upper.contains('SYSTEM') || upper.contains('NOTICE') || upper.contains('ANNOUNCEMENT')) {
      return Icons.campaign_outlined;
    }
    return Icons.info_outline_rounded;
  }

  Color _getNotificationColor(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('SHAKE') || upper.contains('WAKE') || upper.contains('NUDGE')) {
      return AppColors.accent;
    }
    if (upper.contains('WARNING') || upper.contains('OUT') || upper.contains('EXPEL')) {
      return AppColors.error;
    }
    if (upper.contains('JOIN') || upper.contains('APPROVED')) {
      return AppColors.studying;
    }
    if (upper.contains('GROUP') || upper.contains('INVITE') || upper.contains('CHAT') || upper.contains('MEMBER') || upper.contains('SOCIAL')) {
      return AppColors.info;
    }
    if (upper.contains('ALARM') || upper.contains('TIMER') || upper.contains('STUDY')) {
      return AppColors.primary;
    }
    if (upper.contains('ACHIEVEMENT') || upper.contains('RANK') || upper.contains('GOAL')) {
      return AppColors.warning;
    }
    if (upper.contains('SYSTEM') || upper.contains('NOTICE') || upper.contains('ANNOUNCEMENT')) {
      return AppColors.primary;
    }
    return AppColors.primary;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Agora' : '${diff.inMinutes}m atrás';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h atrás';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }
}
