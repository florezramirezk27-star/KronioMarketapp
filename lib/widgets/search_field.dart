import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Campo de busqueda que abre la pantalla de busqueda.
///
/// No es un `TextField`: no escribe nada. Al tocarlo empuja la pantalla de
/// busqueda real, que es la que tiene historial y resultados. Un campo que
/// parece escribir pero no escribe es peor que no tener campo.
///
/// Vive en `home_tab.dart` y en la pestana de catalogo, asi que se extrajo
/// aqui para que las dos pestañas se vean igual. Antes cada una tenia la suya
/// y ya diverge: una redondeaba a 12 y la otra no.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onTap, this.hint});

  final VoidCallback onTap;

  /// Texto de ejemplo. Por defecto no pone nada: el catalogo va a cambiar de
  /// productos y un ejemplo de "zapatillas" en una tienda de audifonos queda
  /// raro.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          // La lupa va dentro de un circulo: es lo que hace que un campo de
          // busqueda se lea como tal de un vistazo, y no solo por el icono.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint ?? 'Buscar productos...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
