import 'package:flutter/material.dart';

import 'cart_scope.dart';

/// Boton de carrito con contador de items.
///
/// Estaba duplicado en `home_screen.dart` y `product_detail_screen.dart`.
///
/// El badge se limita a "99+" porque con tres digitos desborda del circulo y
/// tapa el icono.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final count = cart.totalItems;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'Carrito',
          onPressed: () => Navigator.of(context).pushNamed('/cart'),
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
