import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get unitTotal => product.price * quantity;
}

class CartService extends ChangeNotifier {
  static const _prefsKey = 'kronio_cart_v1';
  final Map<String, CartItem> _items = {};
  bool _loaded = false;

  static Future<CartService> load() async {
    final service = CartService();
    await service._load();
    return service;
  }

  Map<String, CartItem> get items => Map.unmodifiable(_items);
  List<CartItem> get itemList => _items.values.toList();

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
          final map = item as Map<String, dynamic>;
          final product = Product.fromJson(map['product'] as Map<String, dynamic>);
          final quantity = (map['quantity'] as num).toInt();
          if (quantity > 0) {
            _items[product.id] = CartItem(product: product, quantity: quantity);
          }
        }
      }
    } catch (_) {
      // Corrupto o inaccesible; arrancamos con carrito vacío.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(Product product, {int quantity = 1}) async {
    final existing = _items[product.id];
    if (existing != null) {
      existing.quantity = existing.quantity + quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> increment(String productId) async {
    final item = _items[productId];
    if (item == null) return;
    item.quantity++;
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
    _items.remove(productId);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.values
        .map((item) => {
              'product': {
                'id': item.product.id,
                'name': item.product.name,
                'slug': item.product.slug,
                'price': item.product.price,
                'oldPrice': item.product.oldPrice,
                'image': item.product.image,
                'stock': item.product.stock,
              },
              'quantity': item.quantity,
            })
        .toList();
    await prefs.setString(_prefsKey, jsonEncode(data));
  }
}