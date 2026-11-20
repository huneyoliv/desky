import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import '../../data/repositories/notification_repository.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/settings/settings_notifier.dart';
import '../../features/settings/widgets/app_settings_dialog.dart';
import '../../features/timer/offline_sync_notifier.dart';
import '../../features/settings/widgets/theme_selection_dialog.dart';
import '../../features/timer/timer_notifier.dart';
import '../../features/timer/widgets/manual_study_log_dialog.dart';

/// One tab of the Classic YPT top bar.
class ClassicTab {
  const ClassicTab(this.route, this.keyName, this.fallback, this.icon);
  final String route;
  final String keyName;
  final String fallback;
  final IconData icon;
}

/// Top navigation of the Classic YPT look, replacing the sidebar:
/// Timer · To-Do · Calendar · Groups · Statistics · Weekly planner, and a
/// grid button on the right that opens every other feature.
class ClassicTabBar extends ConsumerWidget {
  const ClassicTabBar({super.key, required this.currentRoute});

  final String currentRoute;

  static const tabs = [
    ClassicTab('/home', 'classic_tab_timer', 'Timer', Icons.timer_outlined),
    ClassicTab('/todo', 'classic_tab_todo', 'To-Do', Icons.check_box_outlined),
    ClassicTab('/calendar', 'classic_tab_calendar', 'Calendar', Icons.calendar_today_outlined),
    ClassicTab('/groups', 'classic_tab_groups', 'Groups', Icons.people_outline),
    ClassicTab('/statistics', 'classic_tab_statistics', 'Statistics', Icons.bar_chart_rounded),
    ClassicTab('/weekly', 'classic_tab_weekly_planner', 'Weekly planner', Icons.menu_book_outlined),
    ClassicTab('/notifications', 'classic_notice', 'Notice', Icons.notifications_none_rounded),
  ];

  /// Which tab owns [route]; detail pages (e.g. /groups/12) light up their tab.
  static String? tabFor(String route) {
    for (final tab in tabs) {
      if (route == tab.route || route.startsWith('${tab.route}/')) return tab.route;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final active = tabFor(currentRoute);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: _TabButton(
                key: ValueKey('classic-tab-${tab.route}'),
                label: t.tr(tab.keyName, fallback: tab.fallback),
                icon: tab.icon,
                selected: tab.route == active,
                badge: tab.route == '/notifications' && active != '/notifications' ? unread : 0,
                onTap: () => context.go(tab.route),
              ),
            ),
          const SizedBox(width: 4),
          const _SyncIndicator(),
          IconButton(
            key: const ValueKey('classic-more-button'),
            tooltip: t.tr('classic_more', fallback: 'All features'),
            icon: Icon(Icons.grid_view_rounded, size: 18, color: palette.textSecondary),
            onPressed: () => ClassicFeatureMenu.show(context),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  /// Unread count shown as a ping on the tab (0 hides it).
  final int badge;

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.textPrimary : palette.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: selected ? palette.card : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: const Color(0xFFFF3B30),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grid menu: Main features / Extra features / Decorate / More.
class ClassicFeatureMenu extends ConsumerWidget {
  const ClassicFeatureMenu({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => const Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(top: 76, right: 12),
          child: ClassicFeatureMenu(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;

    void go(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    void open(Future<void> Function(BuildContext) dialog) {
      final root = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      dialog(root);
    }

    _MenuItem item(String key, String fallback, IconData icon, VoidCallback onTap) =>
        _MenuItem(label: t.tr(key, fallback: fallback), icon: icon, onTap: onTap);

    final sections = <(String, List<_MenuItem>)>[
      (
        t.tr('classic_menu_main', fallback: 'Main features'),
        [
          item('classic_tab_statistics', 'Statistics', Icons.bar_chart_rounded, () => go('/statistics')),
          item('ranking', 'Rankings', Icons.star_border_rounded, () => go('/ranks')),
          item('timer_options_pomodoro', 'Pomodoro', Icons.timer_outlined, () {
            ref.read(timerNotifierProvider.notifier).setTimerMode(TimerMode.pomodoro);
            go('/home');
          }),
          item('classic_edit_log', 'Edit log', Icons.edit_outlined, () => open(ManualStudyLogDialog.show)),
          item(
            'classic_offline_mode',
            ref.read(settingsNotifierProvider).offlineMode ? 'Go online' : 'Offline mode',
            Icons.cloud_off_outlined,
            () {
              Navigator.of(context).pop();
              final n = ref.read(settingsNotifierProvider.notifier);
              n.toggleOfflineMode(!ref.read(settingsNotifierProvider).offlineMode);
            },
          ),
        ],
      ),
      (
        t.tr('classic_menu_extra', fallback: 'Extra features'),
        [
          item('classic_books', 'Books', Icons.menu_book_outlined, () => go('/smartbook')),
          item('classic_timetable', 'Timetable', Icons.grid_on_rounded, () => go('/weekly')),
          item('flashcard', 'Flashcards', Icons.style_outlined, () => go('/flashcards')),
          item('challenge', 'Mission', Icons.emoji_events_outlined, () => go('/challenges')),
        ],
      ),
      (
        t.tr('classic_menu_decorate', fallback: 'Decorate'),
        [
          item('classic_theme', 'Theme', Icons.palette_outlined, () => open(ThemeSelectionDialog.show)),
          item('studicon', 'Studicon', Icons.face_outlined, () => go('/store')),
          item('classic_planner', 'Planner', Icons.event_note_outlined, () => go('/planner')),
        ],
      ),
      (
        t.tr('classic_menu_more', fallback: 'More'),
        [
          item('profile', 'Profile', Icons.person_outline, () => go('/profile')),
          item('settings', 'Settings', Icons.settings_outlined, () => open(AppSettingsDialog.show)),
          item('logout', 'Log out', Icons.logout_rounded, () {
            Navigator.of(context).pop();
            ref.read(authStateProvider.notifier).logout();
          }),
        ],
      ),
    ];

    return Material(
      color: palette.card,
      elevation: 12,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final (title, items) in sections)
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 12, color: palette.textMuted)),
                    const SizedBox(height: 4),
                    ...items,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: palette.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: palette.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline / unsynced indicator in the tab bar. Hidden when online with
/// nothing waiting; otherwise a cloud chip that syncs or toggles offline mode.
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final offline = ref.watch(settingsNotifierProvider.select((s) => s.offlineMode));
    final sync = ref.watch(offlineSyncNotifierProvider);
    if (!offline && !sync.hasPending) return const SizedBox.shrink();

    final label = offline
        ? t.tr('classic_offline', fallback: 'Offline')
        : '${sync.pendingCount} ${t.tr('classic_unsynced', fallback: 'to sync')}';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: PopupMenuButton<String>(
        key: const ValueKey('classic-sync-indicator'),
        tooltip: label,
        color: palette.card,
        onSelected: (v) {
          if (v == 'sync') ref.read(offlineAutoSyncProvider).trigger();
          if (v == 'toggle') ref.read(settingsNotifierProvider.notifier).toggleOfflineMode(!offline);
        },
        itemBuilder: (_) => [
          if (!offline && sync.hasPending)
            PopupMenuItem(
              value: 'sync',
              child: Text('${t.tr('classic_sync_now', fallback: 'Sync now')} (${sync.pendingCount})'),
            ),
          PopupMenuItem(
            value: 'toggle',
            child: Text(offline
                ? t.tr('classic_go_online', fallback: 'Go online')
                : t.tr('classic_offline_mode', fallback: 'Offline mode')),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (offline ? const Color(0xFFFF9F0A) : palette.primary).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            sync.isSyncing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(offline ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined,
                    size: 16, color: offline ? const Color(0xFFFF9F0A) : palette.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: palette.textPrimary)),
          ]),
        ),
      ),
    );
  }
}
