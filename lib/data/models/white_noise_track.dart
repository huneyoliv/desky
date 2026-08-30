import '../../core/cdn/cdn_resolver.dart';

class WhiteNoiseTrack {
  final String id;
  final String title;
  final String relativePath;
  final double volume;
  final bool isPlaying;

  const WhiteNoiseTrack({
    required this.id,
    required this.title,
    required this.relativePath,
    this.volume = 0.5,
    this.isPlaying = false,
  });

  String get audioUrl => CdnResolver.audioUrl(relativePath);

  WhiteNoiseTrack copyWith({
    String? id,
    String? title,
    String? relativePath,
    double? volume,
    bool? isPlaying,
  }) {
    return WhiteNoiseTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      relativePath: relativePath ?? this.relativePath,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
