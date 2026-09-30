import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import '../widgets/product_grid.dart';
import 'home_screen.dart';

/// Pestana de inicio: banner, categorias circulares y catalogo.
///
/// El pull-to-refresh ahora si funciona: llama a [CatalogController.refresh],
/// que vuelve a pedir productos y categorias. Antes hacia
/// `setState(() {})` sobre el mismo `Future`, que no disparaba ninguna peticion
/// nueva.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onOpenCategory,
  });

  final CatalogController controller;
  final VoidCallback onSearch;
  final void Function(String categoryId) onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.status == LoadStatus.error && controller.products.isEmpty) {
          return CatalogErrorView(controller: controller);
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ProductGrid(
            controller: controller,
            header: _HomeHeader(
              controller: controller,
              onSearch: onSearch,
              onOpenCategory: onOpenCategory,
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.controller,
    required this.onSearch,
    required this.onOpenCategory,
  });

  final CatalogController controller;
  final VoidCallback onSearch;
  final void Function(String categoryId) onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final categories =
        controller.categories.where((c) => c.productCount > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _WelcomeBanner(),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionTitle(
            title: 'Categorias',
            trailing: categories.isEmpty
                ? null
                : '${categories.length} disponibles',
          ),
        ),
        const SizedBox(height: 12),
        _CategoriesStrip(
          categories: categories,
          onTap: onOpenCategory,
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _SectionTitle(title: 'Productos'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(size: 56),
          const SizedBox(height: 12),
          Text(
            'Bienvenido a Kronio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Los mejores productos con descuentos',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
