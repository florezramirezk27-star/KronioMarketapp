import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../theme/app_colors.dart';

/// Tira horizontal de categorias filtrables.
///
/// Solo muestra las categorias que tienen al menos un producto: el backend
/// devuelve tambien las vacias (`_count.products == 0`), y offeringle al
/// usuario un filtro que siempre da "no se encontraron productos" es ruido.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final all = controller.categories;
        if (all.isEmpty) return const SizedBox.shrink();

        final visible = all.where((c) => c.productCount > 0).toList();

        return SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: 'Todos',
                count: controller.total,
                selected: controller.categoryId == null,
                onTap: () => controller.setCategory(null),
              ),
              ...visible.map(
                (c) => _CategoryChip(
                  label: c.name,
                  count: c.productCount,
                  selected: controller.categoryId == c.id,
                  onTap: () => controller.setCategory(c.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(count > 0 ? '$label ($count)' : label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
