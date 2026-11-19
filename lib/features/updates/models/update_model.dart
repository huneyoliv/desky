import 'package:flutter/foundation.dart';

import '../semver.dart';

class ReleaseAsset {
  final int id;
  final String name;
  final int size;
  final String downloadUrl;
  final String contentType;

  const ReleaseAsset({
    required this.id,
    required this.name,
    required this.size,
    required this.downloadUrl,
    required this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      downloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'browser_download_url': downloadUrl,
      'content_type': contentType,
    };
  }
}

class AppRelease {
  final int id;
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final bool isPrerelease;
  final bool isDraft;
  final List<ReleaseAsset> assets;

  const AppRelease({
    required this.id,
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    this.publishedAt,
    this.isPrerelease = false,
    this.isDraft = false,
    this.assets = const [],
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final assetsJson = json['assets'] as List<dynamic>? ?? [];
    final publishedStr = json['published_at'] as String?;

    return AppRelease(
      id: json['id'] as int? ?? 0,
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: publishedStr != null ? DateTime.tryParse(publishedStr) : null,
      isPrerelease: json['prerelease'] as bool? ?? false,
      isDraft: json['draft'] as bool? ?? false,
      assets: assetsJson
          .map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag_name': tagName,
      'name': name,
      'body': body,
      'html_url': htmlUrl,
      'published_at': publishedAt?.toIso8601String(),
      'prerelease': isPrerelease,
      'draft': isDraft,
      'assets': assets.map((a) => a.toJson()).toList(),
    };
  }

  String get cleanVersion {
    final tag = tagName.trim();
    if (tag.startsWith('v') || tag.startsWith('V')) {
      return tag.substring(1).trim();
    }
    return tag;
  }

  /// Whether this release is strictly newer than [currentVersion].
  ///
  /// Uses full SemVer 2.0.0 precedence, so pre-releases order correctly
  /// (`1.2.0-beta.1 < 1.2.0-beta.2 < 1.2.0-rc.1 < 1.2.0`) and build metadata
  /// is ignored. A strictly-greater comparison also means a downgrade is never
  /// offered: from `1.2.0` the release `1.2.0-beta.2` reads as "not newer".
  bool isNewerThan(String currentVersion) {
    final remote = SemVer.tryParse(cleanVersion);
    final current = SemVer.tryParse(currentVersion);
    if (remote == null || current == null) return false;
    return remote > current;
  }

  ReleaseAsset? getAssetForPlatform(TargetPlatform platform) {
    if (assets.isEmpty) return null;

    switch (platform) {
      case TargetPlatform.windows:
        return assets.firstWhere(
          (a) =>
              a.name.toLowerCase().endsWith('.msix') ||
              a.name.toLowerCase().endsWith('.exe') ||
              a.name.toLowerCase().endsWith('.msi'),
          orElse: () => assets.firstWhere(
            (a) => a.name.toLowerCase().contains('windows') && a.name.toLowerCase().endsWith('.zip'),
            orElse: () => assets.first,
          ),
        );
      case TargetPlatform.macOS:
        return assets.firstWhere(
          (a) => a.name.toLowerCase().endsWith('.dmg') || a.name.toLowerCase().endsWith('.pkg'),
          orElse: () => assets.firstWhere(
            (a) => a.name.toLowerCase().contains('macos') && a.name.toLowerCase().endsWith('.zip'),
            orElse: () => assets.first,
          ),
        );
      case TargetPlatform.linux:
        return assets.firstWhere(
          (a) => a.name.toLowerCase().endsWith('.deb') || a.name.toLowerCase().endsWith('.appimage'),
          orElse: () => assets.firstWhere(
            (a) => a.name.toLowerCase().contains('linux') && (a.name.toLowerCase().endsWith('.tar.gz') || a.name.toLowerCase().endsWith('.zip')),
            orElse: () => assets.first,
          ),
        );
      default:
        return assets.isNotEmpty ? assets.first : null;
    }
  }
}
