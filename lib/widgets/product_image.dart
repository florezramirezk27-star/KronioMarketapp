import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Imagen de producto con cache en disco y memoria.
///
/// Antes cada pantalla usaba `Image.network` con su propio
/// `loadingBuilder`/`errorBuilder`. `Image.network` solo cachea en memoria y
/// mientras el proceso vive: al evictuar la entrada o al reiniciar la app, la
/// foto se volvia a bajar. `CachedNetworkImage` ademas guarda en disco, asi que
/// volver al catalogo o al detalle no vuelve a pegarle al CDN.
///
/// `memCacheWidth` es lo que evita decodificar la foto del CDN a su resolucion
/// nativa: en una tarjeta de 2 columnas esa diferencia es de unos pocos MB a
/// decenas.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.iconSize = 40,
  });

  /// URL de la foto. Si va vacia se dibuja directamente el icono de "sin
  /// imagen", sin intentar ninguna peticion.
  final String url;

  final BoxFit fit;

  /// Ancho en pixeles logicos al que se decodifica. `null` = resolucion nativa.
  final int? memCacheWidth;

  /// Tamano del icono cuando no hay imagen o falla la carga.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const _Loading(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => ProductImagePlaceholder(iconSize: iconSize);
}

/// Marcador de "sin imagen".
///
/// Se usa tambien desde `ProductCard`, que lo apila sobre la foto en el `Stack`.
class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder({super.key, this.iconSize = 40});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceLight,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: iconSize,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Marcador de carga: mismo fondo que el placeholder para que la foto no entre
/// "dando saltos" al aparecer.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceLight,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
