class CategoryModel {
  final int id;
  final String title;
  final String shortTitle;
  final int order;
  final String section;

  const CategoryModel({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.order,
    required this.section,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int? ?? 0,
      title: json['tt'] as String? ?? json['title'] as String? ?? '',
      shortTitle: json['t'] as String? ?? '',
      order: json['o'] as int? ?? 0,
      section: json['sc'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tt': title,
        't': shortTitle,
        'o': order,
        'sc': section,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
