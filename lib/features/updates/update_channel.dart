import 'models/update_model.dart';
import 'semver.dart';

/// Chooses which release an update check should consider.
///
/// The stable channel uses GitHub's `/releases/latest`, which already excludes
/// pre-releases and drafts. The beta channel has to read the release list
/// instead, because `/releases/latest` never returns a pre-release.
class UpdateChannel {
  UpdateChannel._();

  /// Picks the highest release by SemVer among [releases], ignoring drafts and
  /// anything without a parseable version.
  ///
  /// With [includePreReleases] false, pre-releases are also skipped, so the
  /// same function can serve both channels if needed.
  static AppRelease? best({
    required List<AppRelease> releases,
    bool includePreReleases = true,
  }) {
    AppRelease? winner;
    SemVer? winnerVersion;

    for (final release in releases) {
      if (release.isDraft) continue;
      if (!includePreReleases && release.isPrerelease) continue;
      final version = SemVer.tryParse(release.cleanVersion);
      if (version == null) continue;
      if (winnerVersion == null || version > winnerVersion) {
        winner = release;
        winnerVersion = version;
      }
    }
    return winner;
  }

  /// Applies the channel rule to a raw GitHub `/releases` payload.
  ///
  /// Kept here rather than in the service so the filtering can be tested
  /// without a fake Dio.
  static AppRelease? fromReleaseList(
    List<dynamic> payload, {
    bool includePreReleases = true,
  }) {
    final parsed = <AppRelease>[];
    for (final entry in payload) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        parsed.add(AppRelease.fromJson(entry));
      } catch (_) {
        // A malformed entry must not break the whole check.
      }
    }
    return best(releases: parsed, includePreReleases: includePreReleases);
  }

  /// Default of the "join the beta" toggle: on only when the running build is
  /// itself a pre-release, so stable users are never opted in silently.
  static bool defaultEnabledFor(String appVersion) {
    final parsed = SemVer.tryParse(appVersion);
    return parsed?.isPreRelease ?? false;
  }
}