class Product {
  final String id;
  final String name;
  final String slug;
  final String description;
  final double price;
  final double? oldPrice;
  final String image;
  final List<String> gallery;
  final int stock;
  final int lowStockThreshold;
  final bool active;
  final String? categoryId;
  final CategoryInfo? category;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    required this.price,
    this.oldPrice,
    required this.image,
    this.gallery = const [],
    required this.stock,
    this.lowStockThreshold = 5,
    this.active = true,
    this.categoryId,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

    List<String> parseGallery(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    CategoryInfo? category;
    if (json['category'] is Map<String, dynamic>) {
      category = CategoryInfo.fromJson(json['category'] as Map<String, dynamic>);
    }

    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Sin nombre',
      slug: json['slug'] ?? '',
      description: (json['description'] as String?) ?? '',
      price: parsePrice(json['price']),
      oldPrice: json['oldPrice'] != null ? parsePrice(json['oldPrice']) : null,
      image: json['image'] ?? '',
      gallery: parseGallery(json['gallery']),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 5,
      active: json['active'] ?? true,
      categoryId: json['categoryId'],
      category: category,
    );
  }

  bool get hasDiscount => oldPrice != null && oldPrice! > price;

  int get discountPercent {
    if (!hasDiscount || price <= 0) return 0;
    return (((oldPrice! - price) / oldPrice!) * 100).round();
  }

  bool get lowStock => stock > 0 && stock <= lowStockThreshold;

  bool get outOfStock => stock <= 0;
}

class CategoryInfo {
  final String id;
  final String name;
  final String slug;

  CategoryInfo({required this.id, required this.name, required this.slug});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}