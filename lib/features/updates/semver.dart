/// Semantic version parsing and precedence, following SemVer 2.0.0 §11.
///
/// Written because the previous comparator dropped everything after the first
/// `-`, which made `1.2.0-beta.1` and `1.2.0` the same version. That froze any
/// user who installed a pre-release: they were never offered `beta.2` and never
/// offered the final release either.
class SemVer implements Comparable<SemVer> {
  const SemVer({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = const [],
    this.build = const [],
  });

  final int major;
  final int minor;
  final int patch;

  /// Dot-separated pre-release identifiers, already split. Empty means this is
  /// a normal release, which outranks every pre-release of the same base.
  final List<String> preRelease;

  /// Dot-separated build metadata. Ignored for precedence, per the spec.
  final List<String> build;

  bool get isPreRelease => preRelease.isNotEmpty;

  /// Parses `MAJOR.MINOR.PATCH[-PRE][+BUILD]`, tolerating a leading `v`.
  ///
  /// Missing minor/patch default to zero so `1.2` still parses. Returns null
  /// when the string cannot be a version at all, so callers can decide what to
  /// do instead of silently comparing zeros.
  static SemVer? tryParse(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1).trim();
    }
    if (text.isEmpty) return null;

    // Build metadata is stripped first: it never affects precedence.
    var build = const <String>[];
    final plus = text.indexOf('+');
    if (plus >= 0) {
      build = _splitIdentifiers(text.substring(plus + 1));
      text = text.substring(0, plus);
    }

    var preRelease = const <String>[];
    final dash = text.indexOf('-');
    if (dash >= 0) {
      preRelease = _splitIdentifiers(text.substring(dash + 1));
      text = text.substring(0, dash);
      if (preRelease.isEmpty) return null; // "1.2.0-" is not a version
    }

    final parts = text.split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final numbers = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0) return null;
      numbers.add(value);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }

    return SemVer(
      major: numbers[0],
      minor: numbers[1],
      patch: numbers[2],
      preRelease: preRelease,
      build: build,
    );
  }

  static List<String> _splitIdentifiers(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed.split('.').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Negative when this version precedes [other], zero when they have equal
  /// precedence, positive when it follows.
  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // A release outranks any pre-release of the same base: 1.2.0 > 1.2.0-rc.1.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final shared = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < shared; i++) {
      final cmp = _compareIdentifier(preRelease[i], other.preRelease[i]);
      if (cmp != 0) return cmp;
    }
    // All shared identifiers equal: the longer one wins (1.2.0-alpha < 1.2.0-alpha.1).
    return preRelease.length.compareTo(other.preRelease.length);
  }

  static int _compareIdentifier(String a, String b) {
    final aNumeric = int.tryParse(a);
    final bNumeric = int.tryParse(b);

    // Numeric identifiers always rank below alphanumeric ones.
    if (aNumeric != null && bNumeric != null) return aNumeric.compareTo(bNumeric);
    if (aNumeric != null) return -1;
    if (bNumeric != null) return 1;

    // Alphanumeric identifiers compare by ASCII order.
    return a.compareTo(b);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;
  bool operator >=(SemVer other) => compareTo(other) >= 0;
  bool operator <=(SemVer other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    final pre = preRelease.isEmpty ? '' : '-${preRelease.join('.')}';
    final meta = build.isEmpty ? '' : '+${build.join('.')}';
    return '$base$pre$meta';
  }
}