import '../utils/json_parsing.dart';

/// Categoria del catalogo.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String slug;

  /// Cantidad de productos, del `_count.products` que agrega Prisma.
  final int productCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];

    return Category(
      id: asString(json['id']),
      name: asString(json['name']),
      slug: asString(json['slug']),
      productCount: count is Map ? asInt(count['products']) ?? 0 : 0,
    );
  }
}
