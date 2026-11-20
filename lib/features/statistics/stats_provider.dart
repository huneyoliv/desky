import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_notifier.dart';
import '../ranks/ranks_screen.dart' show rankRepositoryProvider;
import 'stats_data.dart';

/// Study history from January of last year until today.
///
/// Fetched in quarter-sized requests (in parallel) so no single call asks the
/// API for a very long range. Kept alive while the app runs; pull-to-refresh
/// or the refresh button invalidates it.
final statisticsDataProvider = FutureProvider<StatsData>((ref) async {
  final user = ref.watch(authStateProvider.select((s) => s.user));
  if (user == null) return StatsData.empty;
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
      repo.fetchUserStats(userId: user.id, startDate: fmt.format(a), endDate: fmt.format(b)),
  ]);
  return StatsData.fromPayloads(payloads);
});
