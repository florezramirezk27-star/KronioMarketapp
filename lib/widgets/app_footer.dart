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
/// Todo esta alineado a la izquierda, sin centros. Es el estandar de las
/// tiendas en linea y lo que hacia que este pareciera generico: centrado, un
/// bloque de enlaces apilados en el medio y un borde gris encima se lee como
/// plantilla. Alineado a la izquierda el pie se lee como el cierre de una
/// pagina y no como un recuadro suelto.
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
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FooterBrand(),
          const SizedBox(height: 28),
          const _FooterBenefits(),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              // Un pie de dos columnas en un telefono de 360 dp deja cada
              // columna en 150 dp, y "Términos y condiciones" no entra: se
              // parte en dos lineas y el bloque queda desalineado. Por eso el
              // corte esta en 460 dp, mas arriba que el habitual de 600.
              final isWide = constraints.maxWidth >= 460;

              final columns = [
                _LinkColumn(
                  title: 'Tienda',
                  // Sin `const`: recibe el callback de abajo.
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
                    const _FooterLink(
                      'Carrito',
                      Icons.shopping_cart_outlined,
                      _FooterAction.cart,
                    ),
                    const _FooterLink(
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
                      'Política de privacidad',
                      Icons.privacy_tip_outlined,
                      _FooterAction.privacy,
                    ),
                    _FooterLink(
                      'Términos y condiciones',
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
                      if (i > 0) const SizedBox(width: 28),
                      Expanded(child: columns[i]),
                    ],
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  columns.first,
                  const SizedBox(height: 24),
                  columns.last,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // El separador se hace con un `Container` y no con `Divider` para
          // controlar el color: `Divider` usa `outlineVariant`, que en el tema
          // claro queda casi blanco sobre el fondo naranja del pie.
          Container(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          const _FooterBottom(),
        ],
      ),
    );
  }
}

/// Que hace cada enlace del footer.
///
/// Los documentos legales son solo dos: la Politica de Privacidad ya es el
/// aviso de tratamiento de datos de la Ley 1581 de 2012, asi que un tercer
/// enlace "Datos personales" apuntaria a un documento casi duplicado. Duplicar
/// un texto legal es peor que no duplicarlo: el usuario no sabria cual rige.
enum _FooterAction { catalog, cart, account, about, contact, privacy, terms }

/// Logo, nombre y eslogan. El logo y el nombre devuelven al inicio.
class _FooterBrand extends StatelessWidget {
  const _FooterBrand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandHeader(logoSize: 44),
        const SizedBox(height: 12),
        Text(
          'Tu tienda de confianza',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Fila con las tres condiciones de compra de la tienda.
///
/// Son datos, no adornos. Cada uno sale de lo que ya esta escrito en los
/// terminos y en la pantalla de checkout, asi que no se afirma nada que la app
/// no cumpla:
///  - el pago es contra entrega (no hay pasarela, ver los terminos);
///  - la devolucion tiene 30 dias calendario (apartado 9 de los terminos);
///  - el envio lo hace el transportador hasta la direccion que pone el cliente.
///
/// Cada uno es pulsable y lleva a la seccion de los terminos que lo explica.
/// Un texto que no lleva a ningun lado es decoracion; este lleva a la norma que
/// lo respalda.
class _FooterBenefits extends StatelessWidget {
  const _FooterBenefits();

  static const _benefits = [
    _Benefit(
      icon: Icons.payments_outlined,
      title: 'Paga al recibir',
      detail: 'Contra entrega, sin pedirte datos de tarjeta',
    ),
    _Benefit(
      icon: Icons.assignment_return_outlined,
      title: '30 días para devolver',
      detail: 'Garantía legal, sin letra pequeña',
    ),
    _Benefit(
      icon: Icons.local_shipping_outlined,
      title: 'Envíos a todo el país',
      detail: 'El transportador va a tu dirección',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // En pantallas anchas van en fila; en telefono se apilan. El corte esta
        // en 460 dp porque cada tarjeta necesita su icono y un titulo corto en
        // la misma linea.
        final isWide = constraints.maxWidth >= 460;

        final cards = [
          for (final benefit in _benefits)
            _BenefitCard(benefit: benefit, scheme: scheme, text: text),
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              cards[i],
            ],
          ],
        );
      },
    );
  }
}

/// Una tarjeta de ventaja de compra.
class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.benefit,
    required this.scheme,
    required this.text,
  });

  final _Benefit benefit;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(benefit.icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  benefit.detail,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono, titulo y detalle de una ventaja de compra.
class _Benefit {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

/// Columna de enlaces: un titulo y la lista de destinos.
///
/// Alineada a la izquierda, como el resto del pie. El titulo lleva un filete
/// corto de color de marca debajo: separa el encabezado de los enlaces sin
/// depender de un `SizedBox` grande, que dejaba los titulos flotando.
class _LinkColumn extends StatelessWidget {
  const _LinkColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(width: 24, height: 2, color: AppColors.primary),
        const SizedBox(height: 10),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _FooterLinkButton(link: link),
          ),
      ],
    );
  }
}

/// Boton de un enlace del footer.
///
/// El icono va en un circulo de fondo y el texto se desplaza al tocarlo: da el
/// mismo "esto es pulsable" que da una lista con divisorios, pero sin las lineas
/// horizontales que ensucian un pie de pagina. Antes era un `Row` centrado con
/// `mainAxisSize.min`, que se leia como texto suelto.
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
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => _run(context),
        borderRadius: BorderRadius.circular(8),
        // El relleno llega hasta el borde izquierdo del contenido para que la
        // superficie de pulsado llegue al margen del pie. Antes el `Padding`
        // horizontal de 8 px dejaba 8 px de zona muerta a la izquierda, y en
        // una columna alineada a la izquierda eso se nota al tocar.
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(link.icon, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              // `Expanded` y no `Flexible`: los enlaces van todos a la misma
              // x de izquierda, asi que comparten el borde vertical. Con
              // `Flexible` el texto se queda pegado al icono y cada linea
              // empieza en un punto distinto, que es lo que hacia ver el bloque
              // desordenado.
              Expanded(
                child: Text(
                  link.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              // Chevron a la derecha: la misma convencion de las listas de
              // detalle, y deja claro que la linea completa es pulsable.
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copyright y version real del APK.
///
/// No lleva el nombre del entorno. Antes si, y salia la palabra "production" al
/// pie de la tienda: es informacion de desarrollo en la ultima pantalla que ve
/// el cliente, y lo unico queolucia era confirmar que el build es de
/// produccion. Sigue disponible en la pantalla de perfil, que es donde se mira
/// cuando se depura.
class _FooterBottom extends StatelessWidget {
  const _FooterBottom();

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    // La version viene del APK instalado, no de una constante en el codigo:
    // si se sube a Play Store sin tocar el fuente, el footer sigue siendo
    // cierto. `package_info_plus` no funciona en tests unitarios, asi que si
    // falla se degrada a solo el anio en vez de romper la pantalla.
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? null
            : '${info.version} (${info.buildNumber})';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              version == null
                  ? '(c) $year Kronio Market. Todos los derechos reservados.'
                  : '(c) $year Kronio Market v$version. '
                        'Todos los derechos reservados.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            // La ciudad de la tienda, no el nombre del entorno. Es informacion
            // que le sirve al cliente (la SIC exige datos de contacto y la
            // razon social) y que antes solo aparecia dentro de los documentos.
            Text(
              AppConfig.legalCity,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        );
      },
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
