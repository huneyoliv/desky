import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_translation.dart';
import '../../features/timer/focus_mode_notifier.dart';
import 'sidebar_nav.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(focusModeProvider);
    final isFocusActive = focusState.isStrictFocus || focusState.isMiniPlayer;
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isFocusActive) ...[
                SidebarNav(currentRoute: currentRoute),
                Container(
                  width: 1,
                  color: AppColors.border,
                ),
              ],
              Expanded(
                child: child,
              ),
            ],
          ),

          // Floating Exit Focus Button when in Focus Mode
          if (isFocusActive)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ref.read(focusModeProvider.notifier).exitFocusModes(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close_fullscreen_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          t.tr('exit_focus', fallback: 'Sair do Foco'),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
