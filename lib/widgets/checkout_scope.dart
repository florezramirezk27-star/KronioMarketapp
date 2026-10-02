import 'package:flutter/material.dart';

import '../services/checkout_service.dart';

/// Suministra el [CheckoutService] al arbol.
///
/// Mismo patron que `CartScope` y `AuthScope`: `InheritedWidget` en vez de pasar
/// el servicio por constructor a cada pantalla.
///
/// Va por scope y no por constructor porque lo necesitan el boton de checkout
/// del carrito, la pantalla de confirmacion y la de pedidos, y las tres se
/// abren por rutas distintas. Pasarlo a mano obligaria a cablearlo en cada
/// `push`, que es donde se queda a medias.
class CheckoutScope extends InheritedWidget {
  const CheckoutScope({super.key, required this.service, required super.child});

  final CheckoutService service;

  /// Lanza en debug si falta el scope, que casi siempre significa que la
  /// pantalla se abrio fuera del arbol.
  static CheckoutService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CheckoutScope>();
    assert(scope != null, 'CheckoutScope no encontrado en el arbol de widgets');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(CheckoutScope oldWidget) =>
      oldWidget.service != service;
}
