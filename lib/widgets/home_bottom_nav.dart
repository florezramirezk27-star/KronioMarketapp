import 'package:flutter/material.dart';

import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import 'cart_scope.dart';

/// Barra de navegacion inferior de la pantalla principal.
///
/// Son cuatro destinos, no cinco: el diseno original traia tambien "Favoritos",
/// pero la tienda no tiene favoritos, asi que ese icono seria una puerta a nada.
/// Un destino que no lleva a ninguna parte se nota mas que su ausencia.
///
/// Los destinos son [Inicio] y [Catalogo] (que son las dos pestanas de
/// [currentIndex]), mas [Carrito] y [Perfil], que se empujan como pantallas.
/// Por eso [currentIndex] va de 0 a 3 y no 0 a 1: el indice refleja donde esta
/// el usuario, no solo en que pestana esta.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // `maybeOf` y no `of` para que la barra se pueda montar sin carrito. El
    // badge es informacion secundaria: si no hay carrito, la barra se dibuja
    // igual pero sin el numero, en vez de reventar la pantalla entera.
    final cart = CartScope.maybeOf(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        // Sombra hacia arriba: separa la barra del contenido que scrollea por
        // debajo. Un borde de 1 px solo no basta, porque los productos pasan por
        // debajo y se ven pegados al vidrio.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Inicio',
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view,
                label: 'Catalogo',
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Carrito',
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
                badge: cart == null ? null : _cartCount(cart),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Perfil',
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Numero de lineas del carrito, no de unidades.
  ///
  /// El carrito agrupa por producto, asi que con tres unidades de un solo
  /// article el badge sale en 1. Es lo que espera la gente: "tienes una cosa
  /// pendiente", no "tres".
  int _cartCount(CartService cart) => cart.itemList.length;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    // El destino activo se marca con dos cosas a la vez: icono relleno y color
    // de marca. Con el icono solo, las dos filas de la barra se ven iguales de
    // lejos y no se sabe donde esta uno.
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final count = badge ?? 0;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      selected ? activeIcon : icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                          // El anillo del color de la barra hace que el numero
                          // se lea sobre cualquier icono, en vez de flotar.
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          // Se corta en 99+ porque con tres cifras el globo se
                          // sale de la barra en un telefono de 360 dp.
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
