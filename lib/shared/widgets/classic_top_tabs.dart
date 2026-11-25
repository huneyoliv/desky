import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_translation.dart';
import '../../core/theme/theme_palette.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/notifications/widgets/notification_bell.dart';
import 'sidebar_nav.dart';

/// Optional Classic YPT layout: the sidebar's destinations as tabs along the
/// top of the window.
///
/// It adds no screens or routes of its own: the tabs are [SidebarNav.items]
/// (same routes, labels and icons), and the right side holds the sidebar
/// footer's notification bell and logout button. Adding a destination to the
/// sidebar adds it here too.
class ClassicTopTabs extends ConsumerWidget {
  const ClassicTopTabs({super.key, required this.currentRoute});

  final String currentRoute;

  static const double height = 50;

  /// The tab that owns [route]; detail pages such as `/groups/12` light up
  /// their parent tab.
  static String? activeRouteFor(String route) {
    for (final item in SidebarNav.items) {
      if (route == item.route || route.startsWith('${item.route}/')) return item.route;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appTranslationProvider);
    final palette = context.palette;
    final active = activeRouteFor(currentRoute);

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            // Scrolls sideways when the window is too narrow for every tab.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in SidebarNav.items)
                    _TopTab(
                      key: ValueKey('classic-top-tab-${item.route}'),
                      item: item,
                      label: t.tr(item.keyName, fallback: item.defaultTitle),
                      selected: item.route == active,
                      onTap: () => context.go(item.route),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          const NotificationBell(),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: palette.textMuted, size: 20),
            tooltip: t.tr('logout', fallback: 'Sair'),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    super.key,
    required this.item,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final SidebarNavItemData item;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.primary : palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: selected ? palette.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.svgAsset != null)
                  SvgPicture.asset(
                    item.svgAsset!,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  )
                else
                  Icon(item.fallbackIcon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? palette.textPrimary : palette.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
