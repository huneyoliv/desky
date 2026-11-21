import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_notifier.dart';
import '../ranks/ranks_screen.dart' show rankRepositoryProvider;
import '../settings/settings_notifier.dart';
import 'stats_data.dart';

/// Statistics need the server; raised while Offline mode is on.
class StatsOfflineException implements Exception {
  const StatsOfflineException();
}

/// Study history from January of last year until today.
///
/// Fetched in quarter-sized requests (in parallel) so no single call asks the
/// API for a very long range. Kept in memory while Statistics or Calendar is
/// open and for a few minutes after (quick tab switching does not refetch),
/// then released so the history does not sit in RAM all day.
final statisticsDataProvider = FutureProvider.autoDispose<StatsData>((ref) async {
  final link = ref.keepAlive();
  Timer? release;
  ref.onCancel(() => release = Timer(const Duration(minutes: 3), link.close));
  ref.onResume(() => release?.cancel());
  ref.onDispose(() => release?.cancel());

  // Only the id: refreshing the user's groups or avatar must not refetch.
  // Offline mode: fail at once instead of waiting on eight network timeouts.
  if (ref.watch(settingsNotifierProvider.select((s) => s.offlineMode))) {
    throw const StatsOfflineException();
  }
  final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
  if (userId == null) return StatsData.empty;
  final repo = ref.read(rankRepositoryProvider);
  final fmt = DateFormat('yyyy-MM-dd');

  final today = dateOnly(DateTime.now());
  final chunks = <(DateTime, DateTime)>[];
  var from = DateTime(today.year - 1, 1, 1);
  while (!from.isAfter(today)) {
    final next = DateTime(from.year, from.month + 3, 1);
    final to = next.subtract(const Duration(days: 1));
    chunks.add((from, to.isAfter(today) ? today : to));
    from = next;
  }

  final payloads = await Future.wait([
    for (final (a, b) in chunks)
      repo.fetchUserStats(userId: userId, startDate: fmt.format(a), endDate: fmt.format(b)),
  ]);
  return StatsData.fromPayloads(payloads);
});
