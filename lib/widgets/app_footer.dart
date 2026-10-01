import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'brand_header.dart';

/// Pie de pagina de la tienda.
///
/// Aparece al final del catalogo, debajo de la grilla. Es `SliverToBoxAdapter`
/// en el `CustomScrollView` del grid, no un `Column` dentro de un `ListView`:
/// meterlo en la lista lo haria una celda mas y quedaria pegado a la ultima
/// tarjeta en vez de al fondo.
///
/// Los enlaces no navegan a pantallas que no existen todavia: cada uno abre un
/// dialogo con su contenido. Es mejor que un enlace que no hace nada, y no
/// requiere inventar rutas.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FooterBrand(),
          const SizedBox(height: 24),
          // En pantallas anchas las columnas van en fila; en telefono se apilan.
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 560;
              final columns = [
                const _LinkColumn(
                  title: 'Tienda',
                  links: [
                    _FooterLink(
                      'Catalogo',
                      Icons.grid_view_outlined,
                      'Catalogo',
                    ),
                    _FooterLink(
                      'Carrito',
                      Icons.shopping_cart_outlined,
                      'Carrito',
                    ),
                    _FooterLink('Mi cuenta', Icons.person_outline, 'Mi cuenta'),
                  ],
                ),
                const _LinkColumn(
                  title: 'Ayuda',
                  links: [
                    _FooterLink(
                      'Sobre nosotros',
                      Icons.info_outline,
                      'Sobre nosotros',
                    ),
                    _FooterLink(
                      'Contacto',
                      Icons.support_agent_outlined,
                      'Contacto',
                    ),
                    _FooterLink(
                      'Politica de privacidad',
                      Icons.privacy_tip_outlined,
                      'Politica de privacidad',
                    ),
                    _FooterLink(
                      'Terminos y condiciones',
                      Icons.gavel_outlined,
                      'Terminos y condiciones',
                    ),
                  ],
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 32),
                      Expanded(child: columns[i]),
                    ],
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  columns.first,
                  const SizedBox(height: 24),
                  columns.last,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 12),
          const _FooterBottom(),
        ],
      ),
    );
  }
}

/// Logo, nombre y eslogan. El logo y el nombre devuelven al inicio.
class _FooterBrand extends StatelessWidget {
  const _FooterBrand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandHeader(logoSize: 44),
        const SizedBox(height: 8),
        Text(
          'Tu tienda de confianza',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LinkColumn extends StatelessWidget {
  const _LinkColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => showFooterDialog(context, link.title),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(link.icon, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        link.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Copyright, version real del APK y redes.
class _FooterBottom extends StatelessWidget {
  const _FooterBottom();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = DateTime.now().year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La version viene del APK instalado, no de una constante en el codigo:
        // si se sube a Play Store sin tocar el fuente, el footer sigue siendo
        // cierto. `package_info_plus` no funciona en tests unitarios, asi que si
        // falla se degrada a solo el anio en vez de romper la pantalla.
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null
                ? null
                : '${info.version} (${info.buildNumber})';

            return Text(
              version == null
                  ? '(c) $year Kronio Market. Todos los derechos reservados.'
                  : '(c) $year Kronio Market v$version. '
                        'Todos los derechos reservados.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          AppConfig.environment,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Un enlace del footer.
class _FooterLink {
  const _FooterLink(this.label, this.icon, this.title);

  final String label;
  final IconData icon;

  /// Titulo del dialogo que se abre al pulsarlo.
  final String title;
}

/// Abre el dialogo con el contenido de un enlace del footer.
///
/// Los textos son marcadores de posicion: el backend todavia no expone
/// paginas de contenido estatico, y escribir un aviso legal inventado seria
/// peor que decir que esta en construccion.
void showFooterDialog(BuildContext context, String title) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        'Esta seccion todavia no esta disponible.\n\n'
        'El contenido se agregara cuando Kronio Market tenga publicada su '
        'politica de privacidad, sus terminos y sus datos de contacto.',
        style: const TextStyle(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
