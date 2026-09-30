class Category {
  final String id;
  final String name;
  final String slug;
  final int productCount;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.productCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    int count = 0;
    final c = json['_count'];
    if (c is Map<String, dynamic>) {
      count = (c['products'] as num?)?.toInt() ?? 0;
    }

    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      productCount: count,
    );
  }
}