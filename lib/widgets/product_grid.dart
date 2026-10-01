import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../models/product.dart';
import 'product_card.dart';

/// Grid de productos con scroll infinito.
///
/// Sustituye a los tres `GridView.builder` con `shrinkWrap` y
/// `NeverScrollableScrollPhysics` que habia en `home_screen.dart`.
///
/// Diferencias importantes:
///  - El `childAspectRatio` se calcula segun el ancho disponible en vez de estar
///    fijo en 0.68, que desbordaba con nombres largos o texto grande.
///  - `cacheExtent` y `cacheWidth` para no decodificar imagenes a tamano
///    completo.
///  - El trigger de paginacion dispara `loadMore()` cuando falta poco para
///    llegar al fondo.
class ProductGrid extends StatefulWidget {
  const ProductGrid({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.all(16),
    this.onTapProduct,
    this.header,
    this.physics,
  });

  final CatalogController controller;
  final EdgeInsets padding;
  final void Function(Product product)? onTapProduct;
  final Widget? header;
  final ScrollPhysics? physics;

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    // Al llegar cerca del final se pide la pagina siguiente.
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final products = controller.products;

        return CustomScrollView(
          controller: _scrollController,
          physics:
              widget.physics ??
              const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
          slivers: [
            if (widget.header != null)
              SliverToBoxAdapter(child: widget.header!),

            SliverPadding(
              padding: widget.padding,
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = _columnsFor(constraints.crossAxisExtent);

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      // Proporción pensada para la altura real del card
                      // (imagen cuadrada + nombre + precio). Se recalcula por
                      // columna para que el card se adapte al ancho real.
                      childAspectRatio: _aspectRatioFor(
                        constraints.crossAxisExtent,
                        columns,
                      ),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        onTap: widget.onTapProduct == null
                            ? null
                            : () => widget.onTapProduct!(product),
                      );
                    }, childCount: products.length),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(child: _Footer(controller: controller)),
          ],
        );
      },
    );
  }

  /// 2 columnas en telefonos, mas en tablets. A partir de 600dp se sube a 3 y
  /// de 900dp a 4, para que los cards no queden gigantes.
  int _columnsFor(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  double _aspectRatioFor(double width, int columns) {
    final cardWidth = (width - (columns - 1) * 12) / columns;
    // Card: imagen cuadrada + ~86 de texto con padding.
    return cardWidth / (cardWidth + 86);
  }
}

/// Pie del grid: estado de paginacion y mensajes.
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (controller.loadingMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            Text(
              controller.loadingMoreError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.loadMore,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (controller.products.isNotEmpty && !controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Mostrando ${controller.products.length} de ${controller.total} productos',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 16);
  }
}
