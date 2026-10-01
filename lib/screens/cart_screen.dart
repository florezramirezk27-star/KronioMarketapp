import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_header.dart';
import '../widgets/product_image.dart';
import '../utils/format.dart';
import '../widgets/cart_scope.dart';

/// Carrito de compras.
///
/// El servicio de carrito se expone con `CartScope.of(context)`, asi que cada
/// cambio dispara un rebuild via `InheritedNotifier`.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BrandHeader(logoSize: 24, showName: false),
        title: Text('Carrito${cart.isEmpty ? '' : ' (${cart.totalItems})'}'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Vaciar carrito',
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: cart.isEmpty ? const _EmptyCart() : const _CartContents(),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final cart = CartScope.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Vaciar carrito?'),
        content: const Text('Se eliminaran todos los productos de tu carrito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Vaciar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cart.clear();
    }
  }
}

class _CartContents extends StatelessWidget {
  const _CartContents();

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cart.itemList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = cart.itemList[index];
              return _CartItemTile(item: item);
            },
          ),
        ),
        const _CheckoutBar(),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final product = item.product;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CartThumb(product: product),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCop(product.price),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (product.outOfStock) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Agotado',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QuantityStepper(item: item),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Quitar del carrito',
            visualDensity: VisualDensity.compact,
            onPressed: () => cart.remove(product.id),
          ),
        ],
      ),
    );
  }
}

class _CartThumb extends StatelessWidget {
  const _CartThumb({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        height: 64,
        color: AppColors.surfaceLight,
        child: product.image.isEmpty
            ? const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondary,
                size: 28,
              )
            : ProductImage(
                url: product.image,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                iconSize: 28,
              ),
      ),
    );
  }
}

/// Control de cantidad con tope por stock.
///
/// El `+` se deshabilita cuando se alcanza el maximo, que es el menor entre el
/// stock del producto y el tope por item del carrito.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final product = item.product;

    // El maximo por item es el menor entre el stock real y el tope del
    // servicio, para no dejar agregar mas de lo que hay disponible.
    final stockLimit = product.stock > 0
        ? product.stock
        : CartService.maxQuantityPerItem;
    final limit = stockLimit < CartService.maxQuantityPerItem
        ? stockLimit
        : CartService.maxQuantityPerItem;
    final canIncrement = item.quantity < limit && !product.outOfStock;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 22),
          tooltip: 'Quitar una unidad',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => cart.decrement(product.id),
        ),
        Text(
          '${item.quantity}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 22),
          tooltip: canIncrement ? 'Agregar una unidad' : 'Sin stock disponible',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: canIncrement ? () => cart.increment(product.id) : null,
        ),
      ],
    );
  }
}

/// Barra inferior con el subtotal y el boton de pago.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar();

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Si hay algo agotado no se puede seguir con el pago.
    final hasUnavailable = cart.itemList.any((i) => i.product.outOfStock);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cart.totalItems} items)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  formatCop(cart.subtotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (hasUnavailable) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quita los productos agotados para continuar',
                      style: TextStyle(color: AppColors.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasUnavailable
                    ? null
                    : () => _startCheckout(context),
                child: const Text('Proceder al pago'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startCheckout(BuildContext context) {
    // El checkout real todavia no existe: el backend exige JWT y el flujo de
    // pago no esta implementado. Se avisa en vez de simular una compra.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El pago todavia no esta disponible. Tu carrito quedo guardado.',
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu carrito esta vacio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explora nuestros productos y agrega tus favoritos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ir a la tienda'),
            ),
          ],
        ),
      ),
    );
  }
}
