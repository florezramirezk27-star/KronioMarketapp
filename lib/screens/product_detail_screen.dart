import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_header.dart';
import '../widgets/product_image.dart';
import '../utils/format.dart';
import '../widgets/cart_button.dart';
import '../widgets/cart_scope.dart';

/// Detalle de un producto.
///
/// Recibe el [Product] que ya trajo el listado, no lo vuelve a pedir: el slug
/// esta disponible ([Product.slug]) pero traerlo de nuevo por cada apertura
/// suma una peticion sin necesidad, porque el listado ya trae precio, imagen,
/// stock y categoria.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;

  Product get _product => widget.product;

  Future<void> _addToCart() async {
    final cart = CartScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final quantity = _quantity;
    final product = _product;

    final added = await cart.add(product, quantity: quantity);
    if (!mounted) return;

    if (!added) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El producto ya no esta disponible')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          quantity == 1
              ? 'Producto agregado al carrito'
              : '$quantity unidades agregadas al carrito',
        ),
        action: SnackBarAction(
          label: 'Ver carrito',
          onPressed: () => navigator.pushNamed('/cart'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = _product;
    final images = product.displayImages;

    // Si la galeria es mas corta que el indice elegido (por ejemplo tras una
    // revalidacion), se vuelve al primero.
    if (_selectedImageIndex >= images.length) {
      _selectedImageIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        // El logo como `leading` deja un acceso al inicio en cada pantalla sin
        // robarle espacio al nombre del producto.
        leading: const BrandHeader(logoSize: 24, showName: false),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [CartButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImagePreview(
              images: images,
              selectedIndex: _selectedImageIndex,
              onSelect: (index) => setState(() => _selectedImageIndex = index),
            ),
            const SizedBox(height: 20),
            _Badges(product: product),
            const SizedBox(height: 12),
            Text(
              product.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _PriceRow(product: product),
            const SizedBox(height: 16),
            _StockNotice(product: product),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Descripcion',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.description.isNotEmpty
                  ? product.description
                  : 'Sin descripcion disponible.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if ((product.customCode ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Codigo: ${product.customCode}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (product.isAvailable)
              _PurchaseSection(
                product: product,
                quantity: _quantity,
                onQuantityChanged: (value) => setState(() => _quantity = value),
                onAddToCart: _addToCart,
              )
            else
              const _UnavailableNotice(),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.images,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> images;
  final int selectedIndex;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.1,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: images.isEmpty
                ? const _NoImage(size: 64)
                : ProductImage(
                    url: images[selectedIndex],
                    fit: BoxFit.contain,
                    // La imagen principal se muestra a pantalla completa.
                    memCacheWidth: 1200,
                    iconSize: 64,
                  ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelect(index),
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ProductImage(
                      url: images[index],
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      iconSize: 20,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (product.category != null)
          Chip(
            label: Text(product.category!.name),
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            side: BorderSide.none,
            labelStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (product.hasDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-${product.discountPercent}% DESCUENTO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(
          formatCop(product.price),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        if (product.hasDiscount)
          Text(
            formatCop(product.oldPrice!),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

class _StockNotice extends StatelessWidget {
  const _StockNotice({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.outOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_circle_outline,
              color: AppColors.danger,
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'Producto agotado',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (product.lowStock) {
      return Text(
        'Ultimas ${product.stock} unidades disponibles',
        style: const TextStyle(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _PurchaseSection extends StatelessWidget {
  const _PurchaseSection({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAddToCart,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    // El tope combina el stock disponible y el limite por item del carrito.
    final stockLimit = product.stock < CartService.maxQuantityPerItem
        ? product.stock
        : CartService.maxQuantityPerItem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Cantidad:',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: 'Quitar una unidad',
                    onPressed: quantity > 1
                        ? () => onQuantityChanged(quantity - 1)
                        : null,
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Agregar una unidad',
                    onPressed: quantity < stockLimit
                        ? () => onQuantityChanged(quantity + 1)
                        : null,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '${product.stock} disponibles',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAddToCart,
            icon: const Icon(Icons.shopping_cart_checkout),
            label: Text(
              'Agregar al carrito • ${formatCop(product.price * quantity)}',
            ),
          ),
        ),
      ],
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary, size: 32),
          SizedBox(height: 8),
          Text(
            'Este producto no esta disponible en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
