class Sticker {
  final int id;
  final int setId;
  final String url;

  const Sticker({
    required this.id,
    required this.setId,
    required this.url,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? json['u'] ?? '').toString();
    final fullUrl = rawUrl.startsWith('http')
        ? rawUrl
        : 'https://alicdn.tgclab.com/sticker/$rawUrl';

    return Sticker(
      id: (json['id'] as num?)?.toInt() ?? 0,
      setId: (json['set_id'] ?? json['setId'] as num?)?.toInt() ?? 0,
      url: fullUrl,
    );
  }
}

class StickerSet {
  final int id;
  final String name;
  final String previewUrl;
  final List<Sticker> stickers;

  const StickerSet({
    required this.id,
    required this.name,
    required this.previewUrl,
    required this.stickers,
  });

  factory StickerSet.fromJson(Map<String, dynamic> json) {
    final rawPreview = (json['preview_url'] ?? json['preview'] ?? json['p'] ?? '').toString();
    final preview = rawPreview.startsWith('http')
        ? rawPreview
        : 'https://alicdn.tgclab.com/sticker/$rawPreview';

    final rawStickers = json['stickers'] ?? json['s'];
    final list = rawStickers is List
        ? rawStickers.whereType<Map<String, dynamic>>().map((s) => Sticker.fromJson(s)).toList()
        : <Sticker>[];

    return StickerSet(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? json['n'] ?? 'Sticker Set').toString(),
      previewUrl: preview,
      stickers: list,
    );
  }
}
