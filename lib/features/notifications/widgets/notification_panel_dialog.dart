import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_translation.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notification_repository.dart';

class NotificationPanelDialog extends ConsumerStatefulWidget {
  const NotificationPanelDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const NotificationPanelDialog(),
    );
  }

  @override
  ConsumerState<NotificationPanelDialog> createState() => _NotificationPanelDialogState();
}

class _NotificationPanelDialogState extends ConsumerState<NotificationPanelDialog> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    setState(() => _isLoading = true);
    final repo = ref.read(notificationRepositoryProvider);

    repo.markAllAsRead();

    final list = await repo.fetchNotifications();
    if (mounted) {
      setState(() {
        _notifications = list.map((n) => n.copyWith(isRead: true)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(NotificationModel notice) async {
    setState(() {
      _notifications = _notifications.where((n) => n.id != notice.id).toList();
    });

    final repo = ref.read(notificationRepositoryProvider);
    await repo.deleteNotification(notice.id);
  }

  Future<void> _clearAll() async {
    setState(() {
      _notifications = [];
    });

    final repo = ref.read(notificationRepositoryProvider);
    await repo.deleteAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final t = ref.watch(appTranslationProvider);

    return AlertDialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.appBorder),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: context.appPrimary, size: 22),
              const SizedBox(width: 10),
              Text(
                t.tr('notifications', fallback: 'Notificações'),
                style: TextStyle(color: context.appTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              if (_notifications.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 20),
                  tooltip: t.tr('delete', fallback: 'Limpar todas'),
                  onPressed: _clearAll,
                ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: context.appTextMuted, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 480,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: context.appPrimary))
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: context.appTextMuted),
                        const SizedBox(height: 12),
                        Text(
                          t.tr('no_notifications', fallback: 'Nenhuma notificação no momento'),
                          style: TextStyle(color: context.appTextSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notice = _notifications[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.appSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.appBorder.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: notice.type == 'shake'
                                  ? AppColors.warning.withValues(alpha: 0.2)
                                  : context.appPrimary.withValues(alpha: 0.2),
                              child: Icon(
                                notice.type == 'shake'
                                    ? Icons.vibration
                                    : notice.type == 'warning'
                                        ? Icons.warning_amber_rounded
                                        : Icons.notifications,
                                color: notice.type == 'shake'
                                    ? AppColors.warning
                                    : notice.type == 'warning'
                                        ? AppColors.error
                                        : context.appPrimary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notice.title,
                                    style: TextStyle(
                                      color: context.appTextPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notice.message,
                                    style: TextStyle(
                                      color: context.appTextSecondary,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    df.format(notice.createdAt),
                                    style: TextStyle(color: context.appTextMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: context.appTextMuted, size: 18),
                              tooltip: t.tr('delete', fallback: 'Excluir'),
                              onPressed: () => _deleteNotification(notice),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
