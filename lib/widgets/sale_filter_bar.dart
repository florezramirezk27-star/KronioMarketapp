import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../theme/app_colors.dart';

/// Aviso de que el catalogo esta filtrado a solo ofertas, con su salida.
///
/// Es una barra propia y no un chip mas en la tira de categorias, porque el
/// filtro de ofertas no es una categoria: mezclado con "Moda" o "Salud" el
/// usuario no sabria si "Todos" limpia los dos filtros o solo el de categoria.
///
/// Existe sobre todo por el fallo que ya se corrigio una vez: un filtro sin
/// forma de quitarse deja al usuario atrapado en una lista que no pidio. En el
/// Inicio no hay chips de categoria, asi que sin esta barra el filtro de
/// ofertas no tendria salida visible desde ahi.
class SaleFilterBar extends StatelessWidget {
  const SaleFilterBar({super.key, required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Ocupa cero alto cuando no hay filtro, para no dejar un hueco entre la
        // tira de categorias y la grilla.
        if (!controller.saleOnly) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.sell_outlined,
                size: 16,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Solo productos con descuento',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.setSaleOnly(false),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Quitar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
