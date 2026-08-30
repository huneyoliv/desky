import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_translation.dart';
import '../../features/auth/auth_notifier.dart';
import '../../data/repositories/notification_repository.dart';
import '../../features/notifications/widgets/notification_bell.dart';
import '../../features/timer/timer_notifier.dart';
import '../../core/cdn/cdn_resolver.dart';
import 'studicon_avatar.dart';

class SidebarNavItemData {
  final String keyName;
  final String defaultTitle;
  final String route;
  final IconData fallbackIcon;
  final String? svgAsset;

  const SidebarNavItemData({
    required this.keyName,
    required this.defaultTitle,
    required this.route,
    required this.fallbackIcon,
    this.svgAsset,
  });
}

class SidebarNav extends ConsumerWidget {
  final String currentRoute;

  const SidebarNav({
    super.key,
    required this.currentRoute,
  });

  static const items = [
    SidebarNavItemData(
      keyName: 'bottom_home',
      defaultTitle: 'Cronômetro',
      route: '/home',
      fallbackIcon: Icons.timer,
      svgAsset: 'assets/icons/bottom_home_fill.svg',
    ),
    SidebarNavItemData(
      keyName: 'bottom_group',
      defaultTitle: 'Grupos',
      route: '/groups',
      fallbackIcon: Icons.group,
      svgAsset: 'assets/icons/bottom_group_fill.svg',
    ),
    SidebarNavItemData(
      keyName: 'bottom_calendar',
      defaultTitle: 'Planner',
      route: '/planner',
      fallbackIcon: Icons.calendar_today,
      svgAsset: 'assets/icons/bottom_calendar.svg',
    ),
    SidebarNavItemData(
      keyName: 'ranking',
      defaultTitle: 'Rankings',
      route: '/ranks',
      fallbackIcon: Icons.leaderboard,
    ),
    SidebarNavItemData(
      keyName: 'flashcard',
      defaultTitle: 'Flashcards',
      route: '/flashcards',
      fallbackIcon: Icons.style_outlined,
    ),
    SidebarNavItemData(
      keyName: 'my_avatars',
      defaultTitle: 'Meus Avatares',
      route: '/store',
      fallbackIcon: Icons.storefront,
    ),
    SidebarNavItemData(
      keyName: 'timelapse',
      defaultTitle: 'Timelapse',
      route: '/timelapse',
      fallbackIcon: Icons.slow_motion_video_rounded,
    ),
    SidebarNavItemData(
      keyName: 'challenge',
      defaultTitle: 'Desafios',
      route: '/challenges',
      fallbackIcon: Icons.emoji_events_outlined,
    ),
    SidebarNavItemData(
      keyName: 'profile',
      defaultTitle: 'Perfil',
      route: '/profile',
      fallbackIcon: Icons.person_outline,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final timerState = ref.watch(timerNotifierProvider);
    final isStudying = timerState.isRunning && !timerState.isPaused;
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final hasUnread = unreadAsync.maybeWhen(data: (cnt) => cnt > 0, orElse: () => true);
    final t = ref.watch(appTranslationProvider);

    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        children: [
          // Header: User Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                StudiconAvatar(
                  studiconId: isStudying ? (user?.studiconId ?? -1) : -1,
                  isStudying: isStudying,
                  pose: CdnResolver.resolvePose(
                    isStudying: isStudying,
                    isPaused: timerState.isPaused,
                    studyMs: timerState.todayTotalMs,
                    dailyGoalMs: timerState.dailyGoalMinutes * 60 * 1000,
                  ),
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? t.tr('student', fallback: 'Estudante'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isStudying ? AppColors.success : AppColors.textMuted.withAlpha(120),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isStudying
                                ? t.tr('studying', fallback: 'Estudando')
                                : t.tr('idle', fallback: 'Inativo'),
                            style: TextStyle(
                              color: isStudying ? AppColors.success : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Middle: Nav Links List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = currentRoute == item.route;
                final localizedTitle = t.tr(item.keyName, fallback: item.defaultTitle);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(item.route),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: AppColors.outline)
                              : null,
                        ),
                        child: Row(
                          children: [
                            if (item.svgAsset != null)
                              SvgPicture.asset(
                                item.svgAsset!,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  BlendMode.srcIn,
                                ),
                              )
                            else
                              Icon(
                                item.fallbackIcon,
                                size: 20,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                localizedTitle,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (item.route == '/notifications' && hasUnread && currentRoute != '/notifications') ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer: Notification Bell & Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const NotificationBell(),
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.textMuted, size: 20),
                  tooltip: t.tr('logout', fallback: 'Sair'),
                  onPressed: () {
                    ref.read(authStateProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
