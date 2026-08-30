import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({super.key});

  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final repo = ref.read(notificationRepositoryProvider);
    final list = await repo.fetchNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel notice) async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAsRead(notice.id);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        height: 480,
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Central de Notificações', style: AppTextStyles.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
                  onPressed: _loadNotifications,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma notificação recente.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final notice = _notifications[index];
                          final df = DateFormat('dd/MM HH:mm');

                          return ListTile(
                            dense: true,
                            tileColor: notice.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.05),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surface,
                              child: Icon(
                                notice.type == 'shake'
                                    ? Icons.vibration
                                    : notice.type == 'warning'
                                        ? Icons.warning_amber_rounded
                                        : Icons.notifications_none,
                                size: 16,
                                color: notice.type == 'warning' ? AppColors.error : AppColors.primary,
                              ),
                            ),
                            title: Text(
                              notice.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: notice.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${notice.message}\n${df.format(notice.createdAt)}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            onTap: () => _markRead(notice),
                          );
                        },
                      ),
          ),
        ],
      ),
      ),
    );
  }
}
