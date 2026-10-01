import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../content/store_content.dart';
import '../theme/app_colors.dart';
import '../screens/content_screen.dart';
import 'brand_header.dart';

/// Pie de pagina de la tienda.
///
/// Aparece al final del catalogo, debajo de la grilla. Es `SliverToBoxAdapter`
/// en el `CustomScrollView` del grid, no un `Column` dentro de un `ListView`:
/// meterlo en la lista lo haria una celda mas y quedaria pegado a la ultima
/// tarjeta en vez de al fondo.
///
/// Cada enlace hace algo de verdad: los de tienda navegan a su pantalla y los
/// de ayuda abren el documento correspondiente. Cuando una accion no se puede
/// completar (por ejemplo, no hay cliente de correo instalado), se avisa con un
/// `SnackBar` en vez de fallar en silencio.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.onOpenCatalog});

  /// Callback para llevar al catalogo.
  ///
  /// El footer vive dentro del catalogo y en la pestana de inicio, asi que
  /// "volver al catalogo" no siempre es un no-op: si se esta en la pestana de
  /// inicio hay que cambiar de pestana. `HomeScreen` lo resuelve; si es `null`
  /// el enlace solo vuelve al inicio.
  final VoidCallback? onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        // Todo el footer centrado: la marca, las columnas de enlaces y el
        // aviso legal. Antes arrancaba a la izquierda y se veÃ­a descuadrado
        // contra el logo de la cabecera.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _FooterBrand(),
          const SizedBox(height: 28),
          // En pantallas anchas las columnas van en fila; en telefono se apilan.
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 560;
              final columns = [
                // Sin `const`: recibe el callback de abajo.
                _LinkColumn(
                  title: 'Tienda',
                  links: [
                    _FooterLink(
                      'Catalogo',
                      Icons.grid_view_outlined,
                      _FooterAction.catalog,
                      // Se inyecta aca: el catalogo es el unico enlace que
                      // necesita volver a la pestana, porque el footer tambien
                      // vive en la pestana de inicio.
                      onOpenCatalog: onOpenCatalog,
                    ),
                    _FooterLink(
                      'Carrito',
                      Icons.shopping_cart_outlined,
                      _FooterAction.cart,
                    ),
                    _FooterLink(
                      'Mi cuenta',
                      Icons.person_outline,
                      _FooterAction.account,
                    ),
                  ],
                ),
                const _LinkColumn(
                  title: 'Ayuda',
                  links: [
                    _FooterLink(
                      'Sobre nosotros',
                      Icons.info_outline,
                      _FooterAction.about,
                    ),
                    _FooterLink(
                      'Contacto',
                      Icons.support_agent_outlined,
                      _FooterAction.contact,
                    ),
                    _FooterLink(
                      'Politica de privacidad',
                      Icons.privacy_tip_outlined,
                      _FooterAction.privacy,
                    ),
                    _FooterLink(
                      'Datos personales',
                      Icons.verified_user_outlined,
                      _FooterAction.dataTreatment,
                    ),
                    _FooterLink(
                      'Terminos y condiciones',
                      Icons.gavel_outlined,
                      _FooterAction.terms,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  columns.first,
                  const SizedBox(height: 28),
                  columns.last,
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 16),
          const _FooterBottom(),
        ],
      ),
    );
  }
}

/// Que hace cada enlace del footer.
enum _FooterAction {
  catalog,
  cart,
  account,
  about,
  contact,
  privacy,
  dataTreatment,
  terms,
}

/// Logo, nombre y eslogan. El logo y el nombre devuelven al inicio.
class _FooterBrand extends StatelessWidget {
  const _FooterBrand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const BrandHeader(logoSize: 48),
        const SizedBox(height: 10),
        Text(
          'Tu tienda de confianza',
          textAlign: TextAlign.center,
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
      children: [
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
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
            padding: const EdgeInsets.only(bottom: 6),
            child: _FooterLinkButton(link: link),
          ),
      ],
    );
  }
}

/// Boton de un enlace del footer.
///
/// El contenido va centrado y el `Row` usa `mainAxisSize.min` para que el
/// bloque quede centrado en vez de pegado a la izquierda.
class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({required this.link});

  final _FooterLink link;

  Future<void> _run(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    switch (link.action) {
      case _FooterAction.catalog:
        // Los tres destinos de tienda usan rutas nombradas: `/cart` y
        // `/profile` viven en `routes` de `MaterialApp`. El catalogo es la
        // raiz, asi que se resuelve con `popUntil`.
        navigator.popUntil((route) => route.isFirst);
        link.onOpenCatalog?.call();

      case _FooterAction.cart:
        await navigator.pushNamed('/cart');

      case _FooterAction.account:
        await navigator.pushNamed('/profile');

      case _FooterAction.about:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ContentScreen(document: aboutContent),
          ),
        );

      case _FooterAction.privacy:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ContentScreen(document: privacyContent),
          ),
        );

      case _FooterAction.dataTreatment:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ContentScreen(document: dataTreatmentContent),
          ),
        );

      case _FooterAction.terms:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ContentScreen(document: termsContent),
          ),
        );

      case _FooterAction.contact:
        final sent = await launchSupportEmail();
        if (!sent) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'No pudimos abrir tu correo. Escribenos a '
                '${AppConfig.supportEmail}',
              ),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => _run(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(link.icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  link.label,
                  textAlign: TextAlign.center,
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
    );
  }
}

/// Copyright, version real del APK y entornos.
class _FooterBottom extends StatelessWidget {
  const _FooterBottom();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = DateTime.now().year;

    return Column(
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
              textAlign: TextAlign.center,
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
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Un enlace del footer.
class _FooterLink {
  const _FooterLink(this.label, this.icon, this.action, {this.onOpenCatalog});

  final String label;
  final IconData icon;
  final _FooterAction action;

  /// Se propaga desde [AppFooter.onOpenCatalog] al enlace de catalogo.
  final VoidCallback? onOpenCatalog;
}

/// Tope de tiempo para abrir el cliente de correo.
///
/// `url_launcher` va al `PackageManager` de Android via method channel. En
/// algunos ROM (Huawei entre ellos) esa consulta tarda o se queda colgada, y
/// sin este tope el enlace "Contacto" se queda esperando en el vacio sin
/// responder nunca. Es un precaution, no una expectativa: en un dispositivo
/// normal `launchUrl` responde en milisegundos.
const Duration _emailLaunchTimeout = Duration(seconds: 5);

/// Abre el cliente de correo del usuario con el correo de soporte.
///
/// Devuelve `false` si no hay ninguna app capaz de manejar `mailto:` (por
/// ejemplo, una tablet sin clientes de correo), para que quien llama pueda
/// avisar y mostrar la direccion en vez de fallar en silencio.
///
/// No se consulta antes con `canLaunchUrl`: es una segunda ida y vuelta al
/// canal que no aporta nada, porque `launchUrl` ya devuelve `false` cuando no
/// hay ningun handler. Ademas esa llamada fue la que se quedaba colgada
/// durante los tests, dejando el enlace esperando para siempre.
///
/// El `Uri` se construye con [Uri] en vez de interpolar la cadena a mano: asi
/// el asunto y el cuerpo quedan escapados y un `&` en el correo no rompe la
/// URL.
Future<bool> launchSupportEmail() async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConfig.supportEmail,
    queryParameters: const {
      'subject': 'Soporte Kronio Market',
      'body': 'Hola, necesito ayuda con: ',
    },
  );

  try {
    // `await` explicito: un future devuelto dentro de un `try` no lo cubre el
    // `catch`, asi que una excepcion asincrona se escaparia sin manejar.
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).timeout(_emailLaunchTimeout, onTimeout: () => false);
  } catch (_) {
    // Sin cliente de correo, o una excepcion del plugin: cae al `false` de
    // abajo y el footer muestra el correo en un aviso.
  }
  return false;
}
