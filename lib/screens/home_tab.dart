import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../models/category.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/product_grid.dart';
import '../widgets/search_field.dart';

/// Pestana de inicio: banner, categorias circulares y catalogo.
///
/// El pull-to-refresh ahora si funciona: llama a [CatalogController.refresh],
/// que vuelve a pedir productos y categorias. Antes hacia
/// `setState(() {})` sobre el mismo `Future`, que no disparaba ninguna peticion
/// nueva.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onOpenCategory,
    required this.onOpenOffers,
    this.onOpenCatalog,
  });

  final CatalogController controller;
  final VoidCallback onSearch;
  final void Function(String categoryId) onOpenCategory;

  /// Abre el catalogo filtrado a las ofertas.
  final VoidCallback onOpenOffers;

  /// Se reenvia al footer. En esta pestana no es un no-op: desde el pie de la
  /// pestana "Inicio", "Catalogo" tiene que cambiar de pestana.
  final VoidCallback? onOpenCatalog;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

/// Estado de [HomeTab].
///
/// `AutomaticKeepAliveClientMixin` para que la pestana sobreviva al cambio de
/// tab: sin el, `TabBarView` la destruye al salir de pantalla y al volver hay
/// que recargarla desde cero.
class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.status == LoadStatus.error &&
            controller.products.isEmpty) {
          return CatalogErrorView(controller: controller);
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ProductGrid(
            controller: controller,
            onOpenCatalog: widget.onOpenCatalog,
            showFooter: true,
            header: _HomeHeader(
              controller: controller,
              onSearch: widget.onSearch,
              onOpenCategory: widget.onOpenCategory,
              onOpenOffers: widget.onOpenOffers,
            ),
          ),
        );
      },
    );
  }
}

/// Estado de error a pantalla completa, con accion de reintento.
///
/// El boton llama a [CatalogController.retry], que vuelve a pedir los datos.
/// Antes hacia `setState(() {})` sobre el mismo `Future` ya completado, asi
/// que el error se quedaba pegado para siempre.
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({super.key, required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = controller.error;
    final message = error is ApiException
        ? error.message
        : 'Ocurrio un problema al cargar el catalogo.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error is ApiNetworkException ? Icons.wifi_off : Icons.cloud_off,
              size: 56,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.canRetry ? controller.retry : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.controller,
    required this.onSearch,
    required this.onOpenCategory,
    required this.onOpenOffers,
  });

  final CatalogController controller;
  final VoidCallback onSearch;
  final void Function(String categoryId) onOpenCategory;

  /// Abre el catalogo con el filtro de ofertas puesto.
  final VoidCallback onOpenOffers;

  @override
  Widget build(BuildContext context) {
    final categories = controller.categories
        .where((c) => c.productCount > 0)
        .toList();

    // Se cuentan sobre `loadedProducts` y no sobre `products`: el segundo
    // getter ya viene filtrado, asi que con un filtro puesto el banner
    // contaria como ofertas solo lo que el filtro dejo pasar.
    final offers = controller.loadedProducts
        .where((p) => p.hasDiscount)
        .toList();
    final bestDiscount = offers.isEmpty
        ? 0
        : offers.map((p) => p.discountPercent).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SearchField(onTap: onSearch),
        ),

        // El banner desaparece si no hay nada que ofrecer, en vez de quedarse
        // con "0 productos en oferta". Un bloque vacio con un boton que no
        // lleva a ninguna parte es peor que no mostrarlo.
        if (offers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _OffersBanner(
              count: offers.length,
              bestDiscount: bestDiscount,
              onTap: onOpenOffers,
            ),
          ),
        ],

        if (categories.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionTitle(title: 'Categorias'),
          ),
          const SizedBox(height: 12),
          _CategoriesStrip(categories: categories, onTap: onOpenCategory),
        ],

        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionTitle(
            title: 'Productos',
            trailing: '${controller.total} disponibles',
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Banner de ofertas.
///
/// Todos los numeros salen de los productos: cuantos hay con descuento y cual
/// es el mejor porcentaje. No hay cuenta regresiva ni "-50%" de adorno, porque
/// en este catalogo los tres descuentos son del 13% y poner un 40% seria
/// decirle al cliente una mentira que el catalogo contradice a un toque.
class _OffersBanner extends StatelessWidget {
  const _OffersBanner({
    required this.count,
    required this.bestDiscount,
    required this.onTap,
  });

  final int count;
  final int bestDiscount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // En singular cambia la frase: "1 producto con descuento" y no
    // "1 productos con descuento".
    final headline = count == 1
        ? '1 producto con descuento'
        : '$count productos con descuento';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sell_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'EN OFERTA',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hasta $bestDiscount% de descuento. Paga al recibir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                // Boton blanco sobre el naranja: es el unico elemento del banner
                // con contraste propio, y asi se lee como la accion principal
                // sin sacar el banner de su color de marca.
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(22),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver ofertas',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _CategoriesStrip extends StatelessWidget {
  const _CategoriesStrip({required this.categories, required this.onTap});

  final List<Category> categories;
  final void Function(String categoryId) onTap;

  /// Icono por nombre de categoria. El backend usa "Tecnologia" sin tilde, asi
  /// que estan las dos variantes.
  static const _icons = <String, IconData>{
    'salud': Icons.health_and_safety,
    'tecnologia': Icons.devices,
    'tecnología': Icons.devices,
    'belleza': Icons.spa,
    'moda': Icons.checkroom,
    'hogar': Icons.chair,
    'herramientas': Icons.handyman,
    'alimentos': Icons.restaurant,
    'deportes': Icons.sports_soccer,
    'mascotas': Icons.pets,
    'juguetes': Icons.toys,
  };

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryBubble(
            category: category,
            icon: _icons[category.name.toLowerCase()] ?? Icons.category,
            onTap: () => onTap(category.id),
          );
        },
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.category,
    required this.icon,
    required this.onTap,
  });

  final Category category;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
