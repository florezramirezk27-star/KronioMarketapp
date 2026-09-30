import '../utils/json_parsing.dart';

/// Producto del catalogo.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    required this.image,
    this.description = '',
    this.oldPrice,
    this.gallery = const [],
    this.stock = 0,
    this.lowStockThreshold = 5,
    this.active = true,
    this.categoryId,
    this.category,
    this.dropiProductId,
    this.customCode,
    this.video,
  });

  final String id;
  final String name;
  final String slug;
  final String description;

  /// Precio actual. El backend lo manda como string ("269000"), no como numero.
  final double price;

  /// Precio de referencia. Solo es descuento si es **mayor** que [price]: el
  /// catalogo tiene productos donde el precio actual es mayor que el
  /// anterior, y en ese caso no hay nada que descontar.
  final double? oldPrice;

  final String image;
  final List<String> gallery;
  final int stock;
  final int lowStockThreshold;
  final bool active;
  final String? categoryId;
  final CategoryInfo? category;

  /// Id del producto en el ERP de origen (Dropi). Necesario para crear pedidos.
  final int? dropiProductId;

  /// SKU / codigo interno del proveedor.
  final String? customCode;

  final String? video;

  factory Product.fromJson(Map<String, dynamic> json) {
    CategoryInfo? category;
    final rawCategory = json['category'];
    if (rawCategory is Map<String, dynamic>) {
      category = CategoryInfo.fromJson(rawCategory);
    }

    final rawOldPrice = json['oldPrice'];

    return Product(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'Sin nombre'),
      slug: asString(json['slug']),
      description: asString(json['description']),
      price: parseMoney(json['price']),
      oldPrice: rawOldPrice == null ? null : parseMoney(rawOldPrice),
      image: asString(json['image']),
      gallery: asStringList(json['gallery']),
      stock: asInt(json['stock']) ?? 0,
      lowStockThreshold: asInt(json['lowStockThreshold']) ?? 5,
      active: json['active'] as bool? ?? true,
      categoryId: json['categoryId']?.toString(),
      category: category,
      dropiProductId: asInt(json['dropiProductId']),
      customCode: asString(json['customCode'], fallback: ''),
      video: asString(json['video']),
    );
  }

  /// Serializa el producto para guardarlo en el carrito local.
  ///
  /// Se persisten solo los campos necesarios para mostrar el item y calcular el
  /// subtotal sin red. El precio queda congelado en el momento de agregar: por
  /// eso el carrito hay que revalidarlo contra el servidor antes de cobrar.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'price': price,
    'oldPrice': oldPrice,
    'image': image,
    'stock': stock,
    'description': description,
  };

  /// Copia con stock actualizado. Se usa al revalidar el carrito contra el
  /// backend sin volver a pedir todo el producto.
  Product withStock(int newStock) => Product(
    id: id,
    name: name,
    slug: slug,
    description: description,
    price: price,
    oldPrice: oldPrice,
    image: image,
    gallery: gallery,
    stock: newStock,
    lowStockThreshold: lowStockThreshold,
    active: active,
    categoryId: categoryId,
    category: category,
    dropiProductId: dropiProductId,
    customCode: customCode,
    video: video,
  );

  bool get hasDiscount => oldPrice != null && oldPrice! > price;

  int get discountPercent {
    if (!hasDiscount || oldPrice! <= 0) return 0;
    return (((oldPrice! - price) / oldPrice!) * 100).round();
  }

  bool get lowStock => stock > 0 && stock <= lowStockThreshold;

  bool get outOfStock => stock <= 0;

  /// `true` si ya se puede agregar al carrito.
  bool get isAvailable => active && !outOfStock;

  /// Imagenes a mostrar: la galeria si hay, si no la principal.
  List<String> get displayImages =>
      gallery.isNotEmpty ? gallery : (image.isNotEmpty ? [image] : const []);
}

/// Datos minimos de la categoria, embebidos en el producto.
class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      id: asString(json['id']),
      name: asString(json['name']),
      slug: asString(json['slug']),
    );
  }
}
