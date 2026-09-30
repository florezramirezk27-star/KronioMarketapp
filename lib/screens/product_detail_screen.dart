import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/format.dart';
import '../widgets/cart_scope.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final images = product.gallery.isNotEmpty
        ? product.gallery
        : (product.image.isNotEmpty ? [product.image] : <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          const _CartButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image gallery / preview
            AspectRatio(
              aspectRatio: 1.1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: images.isEmpty
                    ? const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            size: 64, color: Colors.grey),
                      )
                    : Image.network(
                        images[_selectedImageIndex],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 64, color: Colors.grey),
                        ),
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
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = index == _selectedImageIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = index),
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              size: 20,
                              color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Badges
            Row(
              children: [
                if (product.category != null) ...[
                  Chip(
                    label: Text(product.category!.name),
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (product.hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
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
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),

            // Prices
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatCop(product.price),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (product.hasDiscount) ...[
                  const SizedBox(width: 12),
                  Text(
                    formatCop(product.oldPrice!),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Stock
            if (product.outOfStock)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Producto agotado',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else if (product.lowStock)
              Text(
                '¡Últimas ${product.stock} unidades disponibles!',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Description
            const Text(
              'Descripción',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              product.description.isNotEmpty
                  ? product.description
                  : 'Sin descripción disponible.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Quantity selector & Add to cart button
            if (!product.outOfStock) ...[
              Row(
                children: [
                  const Text(
                    'Cantidad:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _quantity < product.stock
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final cart = CartScope.of(context);
                    cart.add(product, quantity: _quantity);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Agregado "$_quantity" ${_quantity > 1 ? "unidades" : "unidad"} al carrito'),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'Ver Carrito',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const CartScreen()),
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text('Agregar al Carrito • ${formatCop(product.price * _quantity)}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
        if (cart.totalItems > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '${cart.totalItems}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}