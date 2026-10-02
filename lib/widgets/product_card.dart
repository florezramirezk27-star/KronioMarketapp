import 'package:flutter/material.dart';

import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'cart_scope.dart';
import 'product_image.dart';

/// Tarjeta de producto para el grid del catalogo.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;

  /// Si es `null` se navega a la pantalla de detalle. Permite que un contenedor
  /// (por ejemplo, productos relacionados) defina su propia navegacion.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // `maybeOf` y no `of`: hay tarjetas que se montan sin carrito (en tests y en
    // cualquier previsualizacion aislada). Con `of` se revienta el arbol entero
    // por un boton que es opcional. Sin carrito no se muestra el boton de
    // anadir y la tarjeta sigue sirviendo para mirar el producto.
    final cart = CartScope.maybeOf(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            onTap ??
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildImage(context)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPriceRow(context),
                    if (product.lowStock) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ultimas ${product.stock} unidades',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (cart != null && product.isAvailable) ...[
                      const SizedBox(height: 8),
                      _AddToCartButton(product: product, cart: cart),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            formatCop(product.price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (product.hasDiscount) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              formatCop(product.oldPrice!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    // `cacheWidth` evita que se decodifique la imagen completa del CDN a
    // resolucion nativa: en un grid de 2 columnas eso es la diferencia entre
    // unos pocos MB y decenas.
    return Stack(
      fit: StackFit.expand,
      children: [
        ProductImage(
          url: product.image,
          fit: BoxFit.cover,
          // Se limita el ancho en pixeles habituales de una tarjeta.
          memCacheWidth: 400,
        ),
        if (product.hasDiscount)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-${product.discountPercent}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (product.outOfStock)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  'AGOTADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Boton de "Anadir" que aparece en la tarjeta cuando hay carrito.
///
/// Es un `Material` propio y no un `TextButton` suelto porque el `InkWell` de la
/// tarjeta lo envuelve: sin un `Material` intermedio el ripple del boton se
/// dibuja sobre el fondo de la tarjeta y al tocar se ven dos ondas a la vez.
///
/// La tarjeta tambien abre el detalle, y los dos gestos no se disparan a la
/// vez: en el arena de reconocedores gana el mas interno, o sea que el boton se
/// lleva el toque y la tarjeta no lo ve.
///
/// Aqui se agrega siempre **una** unidad. La pantalla de detalle es la que
/// tiene el selector de cantidad, y ponerlo en cada tarjeta del grid no vale
/// la pena.
class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.product, required this.cart});

  final Product product;
  final CartService cart;

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final added = await cart.add(product);
    if (!context.mounted) return;

    if (!added) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El producto ya no esta disponible')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Producto agregado al carrito'),
        action: SnackBarAction(
          label: 'Ver carrito',
          onPressed: () => navigator.pushNamed('/cart'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _add(context),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_shopping_cart_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Anadir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
