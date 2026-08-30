import '../../core/cdn/cdn_resolver.dart';

class StudiconItemModel {
  final int id;
  final String name;
  final String category;
  final int priceFlames;
  final bool isOwned;
  final bool isEquipped;
  final String? description;

  const StudiconItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.priceFlames,
    this.isOwned = false,
    this.isEquipped = false,
    this.description,
  });

  String get previewUrl => CdnResolver.studiconUrl(id, StudiconPose.normal1);

  factory StudiconItemModel.fromJson(Map<String, dynamic> json) {
    final title = json['te'] as String? ?? json['tk'] as String? ?? json['name'] as String? ?? 'Avatar';
    final desc = json['de'] as String? ?? json['dk'] as String? ?? json['description'] as String?;
    return StudiconItemModel(
      id: json['id'] as int? ?? json['studiconID'] as int? ?? 0,
      name: title,
      category: json['category'] as String? ?? 'Meus Avatares',
      priceFlames: (json['p'] ?? json['fc'] ?? json['flame_cost'] ?? json['price'] as num?)?.toInt() ?? 200,
      isOwned: json['isOwned'] as bool? ?? true,
      isEquipped: json['isEquipped'] as bool? ?? false,
      description: desc,
    );
  }

  StudiconItemModel copyWith({
    int? id,
    String? name,
    String? category,
    int? priceFlames,
    bool? isOwned,
    bool? isEquipped,
    String? description,
  }) {
    return StudiconItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      priceFlames: priceFlames ?? this.priceFlames,
      isOwned: isOwned ?? this.isOwned,
      isEquipped: isEquipped ?? this.isEquipped,
      description: description ?? this.description,
    );
  }
}
