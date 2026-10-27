import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_translation.dart';
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
    final t = ref.watch(appTranslationProvider);

    return Material(
      color: context.appCard,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        height: 480,
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: context.appPrimary, size: 20),
                const SizedBox(width: 8),
                Text(t.tr('notifications_center', fallback: 'Central de Notificações'), style: AppTextStyles.titleMedium),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: context.appTextMuted),
                  onPressed: _loadNotifications,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.appPrimary))
                : _notifications.isEmpty
                    ? Center(
                        child: Text(
                          t.tr('no_recent_notifications', fallback: 'Nenhuma notificação recente.'),
                          style: TextStyle(color: context.appTextSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: context.appBorder),
                        itemBuilder: (context, index) {
                          final notice = _notifications[index];
                          final df = DateFormat('dd/MM HH:mm');

                          return ListTile(
                            dense: true,
                            tileColor: notice.isRead ? Colors.transparent : context.appPrimary.withValues(alpha: 0.05),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: context.appSurface,
                              child: Icon(
                                notice.type == 'shake'
                                    ? Icons.vibration
                                    : notice.type == 'warning'
                                        ? Icons.warning_amber_rounded
                                        : Icons.notifications_none,
                                size: 16,
                                color: notice.type == 'warning' ? AppColors.error : context.appPrimary,
                              ),
                            ),
                            title: Text(
                              notice.title,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontWeight: notice.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${notice.message}\n${df.format(notice.createdAt)}',
                              style: TextStyle(color: context.appTextMuted, fontSize: 11),
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
