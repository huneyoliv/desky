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
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: AppColors.primaryLight, size: 22),
              const SizedBox(width: 10),
              Text(
                t.tr('notifications', fallback: 'Notificações'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
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
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          t.tr('no_notifications', fallback: 'Nenhuma notificação no momento'),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: notice.type == 'shake'
                                  ? AppColors.warning.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2),
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
                                        : AppColors.primary,
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notice.message,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    df.format(notice.createdAt),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
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
