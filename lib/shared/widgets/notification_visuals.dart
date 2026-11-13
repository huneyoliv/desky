import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/notification_model.dart';

/// Icon for a notification.
///
/// Derived from the real `nt` codes the API returns (uppercase, underscore
/// separated, such as `GROUP_WARNING` or `GROUP_JOIN_APPROVED`) rather than the
/// lowercase words the UI used to compare against, which never matched.
IconData notificationIcon(NotificationModel notice) {
  switch (notice.normalizedType) {
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'join':
    case 'request':
      return Icons.group_add_outlined;
    case 'member':
      return Icons.person_add_alt_1_outlined;
    case 'post':
      return Icons.forum_outlined;
    case 'membership':
      return Icons.group_outlined;
    default:
      return Icons.notifications_none;
  }
}

/// Colour for [notificationIcon]: warnings stand out, everything else follows
/// the active theme.
Color notificationColor(NotificationModel notice, {required Color primary}) {
  return notice.normalizedType == 'warning' ? AppColors.error : primary;
}
