class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.type,
    required this.name,
    required this.color,
    required this.isDefault,
    required this.isActive,
  });

  final String id;
  final String type;
  final String name;
  final String color;
  final bool isDefault;
  final bool isActive;

  factory CategoryModel.fromMap(String id, Map<String, dynamic> data) {
    return CategoryModel(
      id: id,
      type: data['type'] as String? ?? 'income',
      name: data['name'] as String? ?? '',
      color: data['color'] as String? ?? '#13896f',
      isDefault: data['isDefault'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
