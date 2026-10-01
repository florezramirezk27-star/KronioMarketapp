/// Contenido de las paginas informative del footer.
///
/// El backend no expone endpoints de contenido estatico (verificado: `/pages`,
/// `/content`, `/settings`, `/legal`, `/faq` responden 404), asi que el texto
/// vive aqui y se compila dentro de la app.
///
/// Los textos describen lo que el codigo hace de verdad, no lo que seria
/// ideal: los datos que viajan al backend, los que quedan en el dispositivo y
/// los terceros reales (el CDN de imagenes). Es informacion que ya se puede
/// verificar leyendo el proyecto, asi que no hace falta inventar.
///
/// ADVERTENCIA: esto es una base tecnica, no un documento legal. Antes de
/// publicar hay que revisarlo con un abogado y confirmar los datos de la
/// empresa (razon social, NIT, direccion, politica de devoluciones).
library;

/// Seccion de un documento, con titulo y cuerpo.
class ContentSection {
  const ContentSection(this.title, this.body);

  final String title;
  final String body;
}

/// Documento largo con titulo, fecha y secciones.
class ContentDocument {
  const ContentDocument({
    required this.title,
    required this.updatedAt,
    required this.intro,
    required this.sections,
  });

  final String title;

  /// Fecha de ultima actualizacion, en texto legible.
  final String updatedAt;
  final String intro;
  final List<ContentSection> sections;
}

/// Que es Kronio Market y como funciona.
const aboutContent = ContentDocument(
  title: 'Sobre nosotros',
  updatedAt: 'Octubre de 2026',
  intro:
      'Kronio Market es una tienda en linea construida con Flutter. Traemos '
      'productos de distintos proveedores en un solo catalogo, con precios y '
      'descuentos visibles antes de agregar algo al carrito.',
  sections: [
    ContentSection(
      'Que puedes hacer aqui',
      'Navegar el catalogo por categorias, buscar productos, ver el detalle '
          'con su galeria, agregar al carrito, ajustar cantidades segun el stock '
          'disponible y crear una cuenta para ver tu perfil.\n\n'
          'Tu carrito se guarda en el propio dispositivo: si cierras la app, sigue '
          'ahi cuando vuelvas a abrirla.',
    ),
    ContentSection(
      'Como obtenemos los productos',
      'El catalogo se sincroniza desde nuestro sistema de inventario. Por eso '
          'el precio y la disponibilidad que ves pueden cambiar en cualquier '
          'momento; lo que muestra la app es la foto mas reciente que tenemos.',
    ),
    ContentSection(
      'Estado de la tienda',
      'El registro de usuario y el catalogo funcionan. El pago en linea todavia '
          'no esta disponible: cuando lo actives, aparecera aqui el detalle de los '
          'metodos de pago y los plazos de entrega.',
    ),
  ],
);

/// Aviso de privacidad basado en lo que la app realmente hace.
const privacyContent = ContentDocument(
  title: 'Politica de privacidad',
  updatedAt: 'Octubre de 2026',
  intro:
      'Esta politica explica que datos maneja Kronio Market, para que sepas '
      'exactamente que ocurre con la informacion que nos das.',
  sections: [
    ContentSection(
      'Datos que nos llegan',
      'Cuando creas una cuenta nos llega tu nombre, tu correo electronico y la '
          'contrasena que eliges. La contrasena viaja cifrada por HTTPS y nunca se '
          'guarda en el dispositivo.\n\n'
          'Al entrar, el servidor responde con una cookie de sesion y otra de '
          'seguridad (CSRF). Son las que permiten que la app sepa que ya estas '
          'conectado.',
    ),
    ContentSection(
      'Datos que guardamos en tu telefono',
      'El contenido de tu carrito (productos y cantidades) y la cookie de '
          'sesion se guardan en el almacenamiento local de la app. No se sincronizan '
          'con nuestros servidores y puedes borrarlos desinstalando la app o '
          'vaciando el carrito.',
    ),
    ContentSection(
      'Imagenes de producto',
      'Las fotos se cargan desde una CDN (Amazon CloudFront). Al pedirlas, ese '
          'servicio recibe tu direccion IP y los datos tecnicos de la conexion, '
          'igual que cualquier servidor web al que navegas. Si prefieres no '
          'compartir tu IP con ese tercero, puedes bloquear las imagenes en tu '
          'aplicacion de red: la app sigue funcionando, solo sin fotos.',
    ),
    ContentSection(
      'Lo que no hacemos',
      'No vendemos ni alquilamos tus datos. No usamos publicidad de terceros '
          'ni rastreadores dentro de la app: no hay SDK de analytics, de publicidad '
          'ni de mapas. No repartimos informacion con terceros por motivos '
          'comerciales.',
    ),
    ContentSection(
      'Tus derechos',
      'Puedes pedirnos copia de tus datos, corregirarlos o eliminarlos. Para '
          'eso escribenos desde el enlace de contacto del pie de pagina e '
          'identificate con el correo con el que te registraste.',
    ),
    ContentSection(
      'Niños',
      'La tienda esta dirigida a mayores de edad. Si crees que un menor nos '
          'entrego datos sin autorizacion, escribinos y los eliminamos.',
    ),
  ],
);

/// Terminos y condiciones.
const termsContent = ContentDocument(
  title: 'Terminos y condiciones',
  updatedAt: 'Octubre de 2026',
  intro:
      'Al usar Kronio Market aceptas lo que sigue. Si no estas de acuerdo con '
      'alguno de estos puntos, te pedimos que no uses la tienda.',
  sections: [
    ContentSection(
      'Sobre tu cuenta',
      'Registrarte requiere un correo valido y una contrasena. Eres '
          'responsable de mantenerla segura y de lo que se haga con tu cuenta. '
          'Cierra sesion si usas un dispositivo compartido.',
    ),
    ContentSection(
      'Precios y disponibilidad',
      'Los precios estan en pesos colombianos. El stock que muestra la app se '
          'actualiza desde nuestro inventario y puede agotarse en cualquier momento, '
          'aun antes de que confirmes un pedido. Si un producto ya no esta '
          'disponible, te lo avisaremos antes de cobrarte.',
    ),
    ContentSection(
      'Pedidos y pagos',
      'El pago en linea todavia no esta habilitado. Cuando lo este, esta '
          'seccion detallara los metodos aceptados, los plazos de entrega y las '
          'condiciones de cancelacion. Por ahora el carrito es una seleccion de '
          'productos, no una reserva.',
    ),
    ContentSection(
      'Cambios en un pedido',
      'Antes de que el pedido salga de nuestro almacen se puede cancelar o '
          'modificar escribiendo a soporte. Una vez despachado, aplicaran las '
          'politicas de '
          'devoluciones, que publicaremos aqui antes de que el pago este activo.',
    ),
    ContentSection(
      'Uso permitido',
      'No puedes usar la tienda para actividades ilicitas ni intentar acceder '
          'a cuentas ajenas. Podemos cancelar cuentas que se usen de forma '
          'fraudulenta.',
    ),
    ContentSection(
      'Disponibilidad del servicio',
      'Procuramos que la app funcione siempre, pero no garantizamos que este '
          'libre de interrupciones. Si una parte del servicio no esta disponible, '
          'puede que algunas funciones queden fuera de uso.',
    ),
  ],
);
