import 'package:flutter/material.dart';

import '../services/cart_service.dart';

/// Suministra el [CartService] al arbol y notifica a los que dependan de el
/// cuando el carrito cambia.
///
/// Es el patron de `InheritedNotifier`: en vez de propagar el servicio por
/// constructor a cada pantalla, los widgets que lo necesitan lo piden con
/// `CartScope.of(context)` y se reconstruyen solos.
class CartScope extends InheritedNotifier<CartService> {
  const CartScope({
    super.key,
    required CartService cart,
    required super.child,
  }) : super(notifier: cart);

  /// Obtiene el carrito. Lanza en debug si no hay [CartScope] en el arbol, que
  /// casi siempre significa que la pantalla se abrio fuera del arbol principal.
  static CartService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope no encontrado en el arbol de widgets');
    return scope!.notifier!;
  }

  /// Variante opcional, para widgets que pueden existir sin carrito.
  static CartService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CartScope>()?.notifier;
  }
}
