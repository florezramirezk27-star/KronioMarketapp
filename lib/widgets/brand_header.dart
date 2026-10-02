import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// Logo y nombre de la marca, pulsables.
///
/// Se usa en el AppBar y en el footer. Tocar cualquiera de los dos devuelve al
/// inicio: si la pantalla actual no es la de inicio, cierra las rutas apiladas
/// encima con `popUntil`; si ya estamos en inicio, no hace nada.
///
/// El `AppBar` de `HomeScreen` lo usa como `title`, asi que desde el detalle de
/// un producto, el carrito o el perfil se vuelve a la tienda con un toque.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.logoSize = 32,
    this.showName = true,
    this.onTap,
  });

  final double logoSize;

  /// Si es `false` se dibuja solo el logo. El footer lo pide asi para dejar que
  /// el nombre se dibuje debajo, centrado.
  final bool showName;

  /// Si es `null` se usa el comportamiento por defecto (volver al inicio).
  final VoidCallback? onTap;

  /// Vuelve al inicio cerrando las pantallas apiladas encima.
  ///
  /// `popUntil` con `isFirst` deja solo la ruta raiz, que es `HomeScreen`. Con
  /// `Navigator.popUntil` a secas no serviria: en un `push` anidado (detalle ->
  /// producto relacionado) habria que bajar dos niveles.
  static void goHome(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = BrandLogo(size: logoSize);

    if (!showName) {
      return Semantics(
        button: true,
        label: 'Ir al inicio',
        child: InkWell(
          onTap: onTap ?? () => goHome(context),
          borderRadius: BorderRadius.circular(logoSize * 0.25),
          child: logo,
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Ir al inicio',
      child: InkWell(
        onTap: onTap ?? () => goHome(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              logo,
              const SizedBox(width: 8),
              // `FittedBox` con `scaleDown` en vez de `TextOverflow.ellipsis`.
              //
              // En el `AppBar` de `HomeScreen` el nombre compite con tres
              // botones de accion (buscar, carrito, cuenta), asi que el ancho
              // disponible es el que queda. Con elipsis el nombre salia
              // cortado a "Kronio Mark...", que es justo lo que el usuario
              // reporto: no decia la tienda.
              //
              // `scaleDown` le da al `Text` restricciones sin limite (Flutter
              // devuelve `BoxConstraints()` vacias para este caso), asi que se
              // mide a su tamano natural y despues se reduce lo justo para
              // caber. El nombre sale completo siempre; solo se hace mas
              // pequeno cuando hace falta. La alternativa de bajarle la
              // tipografia fija lo dejaba pequeno para siempre, incluso con
              // espacio de sobra.
              //
              // `maxLines: 1` evita que en un espacio estrecho se parta en dos
              // lineas, que se lee peor que una version un poco mas chica.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kronio Market',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nombre de la marca sin logo, centrado, para el footer.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Kronio Market',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Etiqueta pequena de "pronto disponible".
///
/// Se usa para marcar el login con Google, que todavia no tiene endpoint en el
/// backend. Mostrarlo es preferible a ocultar el boton: deja claro que la
/// funcion esta vista y pendiente, no olvidada.
class ComingSoonTag extends StatelessWidget {
  const ComingSoonTag({super.key, this.label = 'Pronto'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
