import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

/// Carrito local persistente ("guest cart").
///
/// Guarda un snapshot del producto con su precio en el momento de agregarlo.
/// Eso hace que el carrito abra al instante y funcione sin red, pero implica que
/// **el precio y el stock quedan congelados**: por eso hay que revalidar contra
/// el backend antes de cobrar (ver [revalidateStock]).
class CartService extends ChangeNotifier {
  CartService();

  static const _prefsKey = 'kronio_cart_v1';

  /// Cantidad maxima por item.
  ///
  /// El backend no impone un tope, asi que se limita en el cliente para evitar
  /// que alguien pida 9999 unidades de un producto con stock 100.
  static const int maxQuantityPerItem = 99;

  final Map<String, CartItem> _items = {};
  bool _loaded = false;

  /// Carga el carrito desde disco. Idempotente.
  static Future<CartService> load() async {
    final service = CartService();
    await service._load();
    return service;
  }

  Map<String, CartItem> get items => Map.unmodifiable(_items);
  List<CartItem> get itemList => _items.values.toList(growable: false);

  bool get isLoaded => _loaded;
  bool get isEmpty => _items.isEmpty;

  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.unitTotal);

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          final rawProduct = map['product'];
          if (rawProduct is! Map) continue;

          final product = Product.fromJson(rawProduct.cast<String, dynamic>());
          final quantity = (map['quantity'] as num?)?.toInt() ?? 0;

          // Se descarta lo invalido: cantidad <= 0, o producto sin id.
          if (quantity > 0 && product.id.isNotEmpty) {
            _items[product.id] = CartItem(
              product: product,
              quantity: quantity.clamp(1, maxQuantityPerItem),
            );
          }
        }
      }
    } catch (_) {
      // JSON corrupto o prefs inaccesible: arrancamos con carrito vacio en vez
      // de crashear al abrir la app.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Agrega un producto al carrito.
  ///
  /// Devuelve `false` si no se agrego (agotado o inactivo).
  Future<bool> add(Product product, {int quantity = 1}) async {
    if (!product.isAvailable || quantity <= 0) return false;

    final existing = _items[product.id];
    if (existing != null) {
      existing.quantity = _clampQuantity(existing.quantity + quantity, product);
    } else {
      _items[product.id] = CartItem(
        product: product,
        quantity: _clampQuantity(quantity, product),
      );
    }

    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> increment(String productId) async {
    final item = _items[productId];
    if (item == null) return;

    final next = _clampQuantity(item.quantity + 1, item.product);
    // Ya estaba en el tope: no se persiste ni se notifica.
    if (next == item.quantity) return;

    item.quantity = next;
    notifyListeners();
    await _persist();
  }

  Future<void> decrement(String productId) async {
    final item = _items[productId];
    if (item == null) return;

    if (item.quantity <= 1) {
      await remove(productId);
      return;
    }

    item.quantity--;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String productId) async {
    if (_items.remove(productId) == null) return;
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    await _persist();
  }

  /// Sincroniza cantidades y stock con el estado real del servidor.
  ///
  /// Reduce las cantidades que superan el stock y elimina los productos que se
  /// quedaron sin existencias. Devuelve un resumen de lo que cambio, para poder
  /// avisarle al usuario en vez de alterar el carrito en silencio.
  Future<CartSyncResult> revalidateStock(List<Product> serverProducts) async {
    if (_items.isEmpty) return const CartSyncResult();

    final byId = {for (final p in serverProducts) p.id: p};
    final reduced = <String>[];
    final removed = <String>[];

    for (final entry in _items.entries.toList()) {
      final server = byId[entry.key];
      if (server == null) {
        // No vino en la consulta: se asume que sigue igual.
        continue;
      }

      if (!server.isAvailable) {
        _items.remove(entry.key);
        removed.add(entry.key);
        continue;
      }

      final maxAllowed = server.stock < maxQuantityPerItem
          ? server.stock
          : maxQuantityPerItem;

      if (entry.value.quantity > maxAllowed) {
        if (maxAllowed <= 0) {
          _items.remove(entry.key);
          removed.add(entry.key);
        } else {
          entry.value.quantity = maxAllowed;
          entry.value.product = server;
          reduced.add(entry.key);
        }
        continue;
      }

      // Refresca precio y datos del producto.
      entry.value.product = server;
    }

    if (reduced.isNotEmpty || removed.isNotEmpty) {
      notifyListeners();
      await _persist();
    }

    return CartSyncResult(reducedQuantities: reduced, removedProducts: removed);
  }

  int _clampQuantity(int quantity, Product product) {
    final byStock = product.stock > 0 ? product.stock : maxQuantityPerItem;
    final limit = byStock < maxQuantityPerItem ? byStock : maxQuantityPerItem;
    return quantity.clamp(1, limit);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _items.values
          .map(
            (item) => {
              'product': item.product.toJson(),
              'quantity': item.quantity,
            },
          )
          .toList();
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {
      // Si no se puede guardar, el carrito sigue funcionando en memoria.
    }
  }
}

/// Un item del carrito.
class CartItem {
  CartItem({required this.product, required this.quantity});

  Product product;
  int quantity;

  double get unitTotal => product.price * quantity;
}

/// Resumen de los ajustes hechos por [CartService.revalidateStock].
class CartSyncResult {
  const CartSyncResult({
    this.reducedQuantities = const [],
    this.removedProducts = const [],
  });

  /// Ids de productos cuya cantidad se bajo por falta de stock.
  final List<String> reducedQuantities;

  /// Ids de productos que se eliminaron por agotarse.
  final List<String> removedProducts;

  bool get hasChanges =>
      reducedQuantities.isNotEmpty || removedProducts.isNotEmpty;
}
