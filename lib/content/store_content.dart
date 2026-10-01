/// Contenido de las paginas informativas del footer.
///
/// El backend no expone endpoints de contenido estatico (verificado: `/pages`,
/// `/content`, `/settings`, `/legal`, `/faq` responden 404), asi que el texto
/// vive aqui y se compila dentro de la app.
///
/// Cada documento se armó leyendo lo que el sistema hace de verdad, no lo que
/// seria ideal. En concreto:
///
/// - El catalogo, el carrito, los pedidos y las ordenes de envio salen de la
///   API de Kronio Market (NestJS + PostgreSQL + Redis).
/// - Los pedidos que pasan a produccion se crean como ordenes reales en Dropi,
///   que es quien despacha. Por eso el documento de datos habla de Dropi como
///   transferencia y como encargado del tratamiento del envio.
/// - El chatbot de ventas (KronioBot) manda conversaciones a Google Gemini,
///   asi que la conversacion es un dato personal que viaja a un tercero.
/// - Las imagenes de producto se sirven por CloudFront.
///
/// ADVERTENCIA IMPORTANTE
///
/// Estos textos estan redactados siguiendo la estructura que exigen la Ley 1581
/// de 2012 (proteccion de datos), la Ley 1712 de 2014 (comercio electronico) y
/// la Ley 1480 de 2011 (proteccion al consumidor), pero **no son un documento
/// legal validado**. Un abogado debe revisarlos y ajustarlos a la situacion
/// real de la empresa antes de publicar la app. Lo que hay aqui es una base
/// solida y bien estructurada, no un dictamen.
///
/// Los datos de la empresa (razon social, NIT, direccion, representante) se
/// inyectan con `--dart-define` para no dejarlos en el repositorio. Si no estan
/// configurados, los documentos avisan en pantalla en vez de mostrar huecos
/// silenciosos. Ver `AppConfig.hasCompleteLegalData`.
library;

import '../config/app_config.dart';

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

/// Bloque de datos del responsable, comun a los documentos legales.
///
/// Se arma desde [AppConfig] en vez de estar escrito a mano para que cambiar la
/// razon social no obligue a tocar este archivo.
ContentSection get _responsibleSection => ContentSection(
  'Responsable del tratamiento',
  '${_orPending(AppConfig.legalName, 'Razon social pendiente de configurar')}\n'
      'NIT: ${_orPending(AppConfig.legalNit, 'pendiente')}\n'
      '${_orPending(AppConfig.legalAddress, 'Direccion pendiente')}, '
      '${_orPending(AppConfig.legalCity, 'Ciudad pendiente')}\n'
      'Telefono: ${_orPending(AppConfig.legalPhone, 'pendiente')}\n'
      'Correo: ${AppConfig.supportEmail}\n'
      'Responsable: ${_orPending(AppConfig.representative, 'pendiente')}',
);

/// Devuelve el valor, o un texto que deja claro que falta configurarlo.
String _orPending(String value, String pending) =>
    value.isEmpty ? '[$pending]' : value;

/// Datos basicos de la empresa: se usa en varios documentos.

// -----------------------------------------------------------------------------
// Sobre nosotros
// -----------------------------------------------------------------------------

/// Que es Kronio Market y como funciona.
final aboutContent = ContentDocument(
  title: 'Sobre nosotros',
  updatedAt: 'Octubre de 2026',
  intro:
      'Kronio Market es una tienda en linea orientada al mercado colombiano. '
      'Traemos productos de distintos proveedores en un solo catalogo, con '
      'precios y descuentos visibles antes de agregar algo al carrito.',
  sections: [
    ContentSection(
      'Que puedes hacer aqui',
      'Navegar el catalogo por categorias, buscar productos, ver el detalle '
          'con su galeria de imagenes y video, agregar al carrito, ajustar '
          'cantidades segun el stock disponible, crear una cuenta, registrar '
          'un pedido y seguir su envio.\n\n'
          'El chatbot KronioBot responde preguntas sobre stock, precios y '
          'estado de tus pedidos, y puede mostrarte productos relacionados '
          'mientras conversa.',
    ),
    ContentSection(
      'Como obtenemos los productos',
      'Trabajamos con proveedores verificados mediante Dropi, una plataforma '
          'colombiana de dropshipping. Eso significa que no siempre '
          'almacenamos nosotros: cuando confirmas un pedido, se genera una '
          'orden de envio con el proveedor correspondiente, que es quien '
          'prepara y despacha.\n\n'
          'Por eso el precio y la disponibilidad que ves pueden cambiar en '
          'cualquier momento; lo que muestra la app es la foto mas reciente '
          'que tenemos del inventario del proveedor.',
    ),
    ContentSection(
      'Pagos y envios',
      'El pago se realiza dentro de la app al confirmar el pedido. Cada pedido '
          'tiene un numero de seguimiento que puedes consultar en cualquier '
          'momento, y recibes confirmaciones por correo electronico en cada '
          'cambio de estado.',
    ),
    _responsibleSection,
  ],
);

// -----------------------------------------------------------------------------
// Politica de privacidad
// -----------------------------------------------------------------------------

/// Aviso de privacidad.
///
/// Estructurado como lo pide la Ley 1581 de 2012: responsable, tratamiento,
/// finalidad, principios, derechos del titular y transferencias.
final privacyContent = ContentDocument(
  title: 'Politica de privacidad',
  updatedAt: 'Octubre de 2026',
  intro:
      'Kronio Market, con las tareas de tratamiento de datos personales '
      'descritas en este documento, tratara los datos personales de los '
      'usuarios de esta app. Esta politica explica que datos manejamos, con '
      'que finalidad y que derechos tienes sobre ellos.',
  sections: [
    _responsibleSection,

    ContentSection(
      '1. Datos personales que tratamos',
      'Datos que nos llega al crear una cuenta:\n'
          '- Nombre.\n'
          '- Correo electronico.\n'
          '- Contrasena, que viaja cifrada por HTTPS, se guarda cifrada en el '
          'servidor con bcrypt y nunca se guarda en tu dispositivo.\n'
          '- Tipo y numero de documento del representante legal, unicamente '
          'cuando realizas una compra.\n'
          '- Direccion de envio y datos de la persona que recibe, al registrar '
          'un pedido.\n\n'
          'Datos que genera tu uso de la app:\n'
          '- Historial de pedidos y estado de los envios.\n'
          '- Contenido de tu carrito, que se guarda en tu propio dispositivo y '
          'no se sincroniza con nuestros servidores.\n'
          '- Registros tecnicos de seguridad: direccion IP, marca de tiempo y '
          'conteo de intentos fallidos de inicio de sesion.\n\n'
          'Datos que genera el chatbot:\n'
          '- El texto que escribes en el chat con KronioBot y las respuestas '
          'que genera. Las conversaciones se guardan para que puedas '
          'retomarlas.',
    ),

    ContentSection(
      '2. Con que finalidad tratamos los datos',
      '- Crear y mantener tu cuenta, y autenticar tu inicio de sesion.\n'
          '- Gestionar tu carrito y registrar tus pedidos.\n'
          '- Procesar pagos y emitir los comprobantes correspondientes.\n'
          '- Generar y seguir las ordenes de envio con los proveedores.\n'
          '- Enviarte confirmaciones y notificaciones sobre el estado de tus '
          'pedidos por correo electronico.\n'
          '- Prestar soporte y atender tus solicitudes por el chatbot o por '
          'correo.\n'
          '- Cumplir obligaciones legales, contables y tributarias.\n'
          '- Prevenir fraude y proteger la seguridad de la plataforma, '
          'incluido el bloqueo temporal de cuentas con cinco intentos fallidos '
          'de acceso.',
    ),

    ContentSection(
      '3. Principios del tratamiento',
      'Tratamos los datos personales con los principios de finalidad, '
          'libertad, veracidad, calidad, transparencia, acceso y restriction, '
          'seguridad, confidencialidad e integridad, de acuerdo con el '
          'articulo 4 de la Ley 1581 de 2012. No tratamos datos de menores de '
          'edad.',
    ),

    ContentSection(
      '4. Durante cuanto tiempo y por que medio',
      'Los datos de cuenta y los pedidos se conservan mientras tu cuenta este '
          'activa y por los plazos legales exigidos por la normacion '
          'colombiana, especialmente los contables y tributarios. Al solicitar '
          'el cierre de tu cuenta eliminamos los datos que no tengamos '
          'obligacion legal de conservar.\n\n'
          'Puedes ejercer tus derechos escribiendo a ${AppConfig.supportEmail} '
          'desde el correo con el que te registraste.',
    ),

    ContentSection(
      '5. Transferencias a terceros y encargados del tratamiento',
      '- Dropi (dropshipping colombiano): recibe la orden de envio con el '
          'producto, la direccion de entrega y los datos de la persona que '
          'recibe. Actua como encargado del tratamiento.\n'
          '- Google (Gemini): el chatbot de ventas envia el texto de tu '
          'conversacion a los servidores de Google para generar la respuesta.\n'
          '- Amazon CloudFront: sirve las imagenes de producto; al pedirlas, '
          'recibe tu direccion IP y los datos tecnicos de la conexion.\n'
          '- Proveedores de pago y de correo electronico, en la medida '
          'necesaria para procesar pedidos y enviarte notificaciones.\n'
          '- Autoridades publicas, cuando exista una obligacion legal que nos '
          'obligue a entregar informacion.',
    ),

    ContentSection(
      '6. Tus derechos como titular',
      'Puedes conocer, consultar, actualizar, corregir y suprimir tus datos, '
          'revocar tu consentimiento y pedir informacion sobre el uso que le '
          'damos a ellos, escribiendo a ${AppConfig.supportEmail} y '
          'acreditando tu identidad. Tienes derecho a reclamar ante la '
          'Superintendencia de Industria y Comercio (SIC) si consideras que '
          'hemos vulnerado tus derechos.',
    ),

    ContentSection(
      '7. Seguridad',
      'Usamos cifrado en transito (HTTPS), contrasenas cifradas con bcrypt, '
          'sesiones firmadas mediante tokens (JWT), proteccion CSRF, control de '
          'acceso por turnos y bloqueo de cuentas tras cinco intentos '
          'fallidos. Ningun metodo es infalible, pero hacemos lo razonablemente '
          'posible para proteger tus datos.',
    ),

    ContentSection(
      '8. Cambios en esta politica',
      'Podemos actualizar esta politica para reflejar cambios en la '
          'plataforma o en la normatividad. La fecha de actualizacion siempre '
          'aparece al inicio del documento y los cambios relevantes se '
          'anunciaran dentro de la app.',
    ),
  ],
);

// -----------------------------------------------------------------------------
// Terminos y condiciones
// -----------------------------------------------------------------------------

/// Terminos y condiciones.
///
/// Incluye las clausulas que la Ley 1480 de 2011 y la Ley 1712 de 2014
/// consideran obligatorias en comercio electronico.
final termsContent = ContentDocument(
  title: 'Terminos y condiciones',
  updatedAt: 'Octubre de 2026',
  intro:
      'Estos terminos y condiciones regulan el uso de la app Kronio Market y la '
      'compra de productos a traves de ella. Al registrarte y realizar un '
      'pedido aceptas lo que sigue. Si no estas de acuerdo con alguno de estos '
      'puntos, te pedimos que no uses la tienda.',
  sections: [
    _responsibleSection,

    ContentSection(
      '1. Sobre tu cuenta',
      'Registrarte requiere un correo valido, un nombre y una contrasena. Eres '
          'responsable de mantener tu contrasena segura y de todo lo que se '
          'haga con tu cuenta. Cierra sesion si usas un dispositivo '
          'compartido. Podemos suspender cuentas que se usen de forma '
          'fraudulenta o que violen estos terminos.',
    ),

    ContentSection(
      '2. Productos y disponibilidad',
      'Los productos se ofrecen mediante proveedores verificados a traves de '
          'Dropi. El stock y el precio que muestra la app se actualizan desde '
          'el inventario del proveedor y pueden cambiar en cualquier momento, '
          'aun antes de que confirmes un pedido. Si un producto ya no esta '
          'disponible o su precio cambio, te lo avisaremos antes de cobrarte y '
          'podras cancelar sin costo.',
    ),

    ContentSection(
      '3. Precios y pagos',
      'Los precios se exhiben en pesos colombianos e incluyen los impuestos '
          'aplicables salvo que se indique lo contrario. El pago se realiza '
          'dentro de la app al confirmar el pedido. Los medios de pago '
          'aceptados son los habilitados en la plataforma. Si el pago falla, el '
          'pedido no se confirma y no se realizo ningun cargo.',
    ),

    ContentSection(
      '4. Pedidos, envios y entrega',
      'Al confirmar un pedido y quedar pagado, generamos una orden de envio con '
          'el proveedor correspondiente. Recibiras un numero de seguimiento que '
          'puedes consultar desde la app o por correo electronico.\n\n'
          'El plazo de entrega depende del proveedor y de la transportadora y '
          'se informa al momento de generar el envio. Si el pedido no puede '
          'entregarse por causas imputables a la transportadora, gestionaremos '
          'su devolucion o reenvio sin costo adicional.',
    ),

    ContentSection(
      '5. Derecho de retracto y devoluciones',
      'Conforme al articulo 8 de la Ley 1480 de 2011 y al Decreto 1074 de 2015, '
          'el consumidor puede ejercer el derecho de retracto dentro de los '
          'cinco (5) dias habiles siguientes a la entrega del producto, sin '
          'necesidad de justificar el motivo.\n\n'
          'Para ejercerlo, debes comunicar tu solicitud a '
          '${AppConfig.supportEmail} indicando el numero de pedido. El producto '
          'debe devolverse sin uso, en su empaque original y con sus '
          'accesorios. El reembolso se realizara dentro de los quince (15) '
          'dias habiles despues de recibido el producto.\n\n'
          'El derecho de retracto no aplica a productos personalizados, ni a '
          'los casos de exclusion previstos en la ley (productos de higiene '
          'personal o de salud con el sello abierto, entre otros).',
    ),

    ContentSection(
      '6. Garantias',
      'Los productos tienen la garantia legal vigente en Colombia: garantia de '
          'satisfaccion para productos no perecederos y garantia de la '
          'producto defectuoso. Para reportar un defecto de un producto, '
          'escribe a ${AppConfig.supportEmail} indicando el numero de pedido y '
          'describe el problema; resolvero segun la via de garantia legal o por '
          'cambio o devolucion.',
    ),

    ContentSection(
      '7. Uso permitido y propiedad intelectual',
      'No puedes usar la tienda para actividades ilicitas, realizar pedidos '
          'falsos o intentar acceder a cuentas ajenas. El software, el diseño y '
          'la marca Kronio Market son propiedad de sus titulares y algunos usos '
          'del contenido (como realizar pedidos para revender) requieren '
          'autorizacion previa por escrito.',
    ),

    ContentSection(
      '8. Responsabilidad',
      'Procuramos que la app y el sitio funcionen correctamente, pero no '
          'garantizamos que esten libres de interrupciones. No respondemos por '
          'daños derivados de lucro cesante o de lucro perdido. Nuestra '
          'responsabilidad ante el consumidor por fallos en el pago o en la '
          'entrega esta sujeta a lo dispuesto en la Ley 1480 de 2011.',
    ),

    ContentSection(
      '9. Modificaciones y terminacion',
      'Podemos modificar estos terminos para reflejar cambios en la plataforma '
          'o en la normatividad; los cambios se publicaran en la app. Puedes '
          'cerrar tu cuenta en cualquier momento escribiendo a '
          '${AppConfig.supportEmail}, y eso daria por terminado el uso de la '
          'tienda bajo estos terminos.',
    ),

    ContentSection(
      '10. Ley aplicable y jurisdiccion',
      'Estos terminos se rigen por las leyes de la Republica de Colombia. '
          'Cualquier controversia se sometera a la jurisdiccion de los jueces '
          'competentes del lugar donde se celebrate el contrato, respetando el '
          'fuero del domicilio del consumidor para las acciones de proteccion '
          'al consumidor.',
    ),
  ],
);

// -----------------------------------------------------------------------------
// Aviso de privacidad y tratamiento de datos (Ley 1581 de 2012)
// -----------------------------------------------------------------------------

/// Aviso de privacidad y autorizacion de tratamiento de datos.
///
/// Documento separado porque es el que la SIC revisa y el que el titular
/// deberia firmar de forma expresa. Reúne los elementos del articulo 3 de la
/// Ley 1581: responsable, desde cuando y hasta cuando, finalidad, forma de
/// forma de notificarlos, derechos y procedimiento para ejercerlos.
final dataTreatmentContent = ContentDocument(
  title: 'Tratamiento de datos personales',
  updatedAt: 'Octubre de 2026',
  intro:
      'En cumplimiento del articulo 10 de la Ley 1581 de 2012, esta politica '
      'de tratamiento de datos personales de Kronio Market te informa, como '
      'responsable del tratamiento, para que fines tratamos tus datos, como '
      'puedes ejercer tus derechos y a quien debes dirigirte.',
  sections: [
    _responsibleSection,

    ContentSection(
      '1. Identificacion del responsable y del encargado',
      'Responsable: ${_orPending(AppConfig.legalName, 'razon social pendiente')}, '
          'NIT ${_orPending(AppConfig.legalNit, 'pendiente')}, con domicilio en '
          '${_orPending(AppConfig.legalAddress, 'direccion pendiente')}, '
          '${_orPending(AppConfig.legalCity, 'ciudad pendiente')}.\n'
          'Canal de contacto para fines de proteccion de datos: '
          '${AppConfig.supportEmail}.\n'
          'Encargado interno: '
          '${_orPending(AppConfig.representative, 'representante pendiente')}, '
          '${_orPending(AppConfig.representativeId, 'documento pendiente')}.\n'
          'El procesamiento se realiza en los servidores de la API de Kronio '
          'Market y, en lo que corresponda, en los servicios de terceros '
          'descritos en la seccion 6 de este documento.',
    ),

    ContentSection(
      '2. Alcance del aviso',
      'Este aviso aplica a los datos personales que tratamos a traves de esta '
          'app: registro de usuario, carrito, pedidos, datos de envio, '
          'conversaciones con el chatbot de ventas y registros de seguridad. '
          'No tratamos datos de menores de edad.',
    ),

    ContentSection(
      '3. Datos y finalidades del tratamiento',
      'Tratamos tus datos personales con las siguientes finalidades:\n'
          '- Registro, autenticacion y gestion de tu cuenta.\n'
          '- Gestion del carrito y de los pedidos que realices.\n'
          '- Procesamiento de pagos, facturacion y cumplimiento de obligaciones '
          'contables y tributarias.\n'
          '- Generacion de ordenes de envio y seguimiento con el proveedor.\n'
          '- Envio de notificaciones operativas y transaccionales por correo '
          'electronico.\n'
          '- Atencion de solicitudes y del chatbot de ventas.\n'
          '- Seguridad de la plataforma y prevencion de fraude.',
    ),

    ContentSection(
      '4. Forma de tratamiento y principios',
      'El tratamiento se realiza de forma automatizada a traves de la API de '
          'Kronio Market, con cifrado en transito y en reposo, controles de '
          'acceso y registro de operaciones relevantes. Aplicamos los '
          'principios de finalidad, libertad, veracidad, calidad, '
          'transparencia, acceso y restriccion, seguridad y confidencialidad.',
    ),

    ContentSection(
      '5. Plazo de conservacion',
      'Los datos se conservan mientras tu cuenta este activa y por los plazos '
          'legales aplicables, especialmente los contables y tributarios. '
          'Solicita el cierre de tu cuenta escribiendo a '
          '${AppConfig.supportEmail} para eliminar los datos que no debamos '
          'conservar por obligacion legal.',
    ),

    ContentSection(
      '6. Transferencias a terceros y encargados del tratamiento',
      'Compartimos datos, por cuenta de Kronio Market y solo en lo necesario '
          'para prestar el servicio, con:\n'
          '- Dropi, plataforma de dropshipping que recibe la orden de envio '
          'con el producto, la direccion de entrega y los datos de quien '
          'recibe. Actua como encargado del tratamiento.\n'
          '- Google (Gemini), a quien el chatbot de ventas envia el texto de '
          'tu conversacion para generar la respuesta.\n'
          '- Amazon CloudFront, que sirve las imagenes de producto y, al '
          'pedirlas, recibe tu direccion IP y los datos tecnicos de la '
          'conexion.\n'
          '- Proveedores de pago y de correo electronico, en la medida '
          'necesaria para procesar pedidos y enviarte notificaciones.\n'
          '- Autoridades publicas, cuando exista una obligacion legal que nos '
          'obligue a entregar informacion.',
    ),

    ContentSection(
      '7. Transferencias internacionales',
      'Algunos de los proveedores de la seccion anterior tratan datos en '
          'servidores fuera de Colombia. Es el caso del chatbot de ventas: el '
          'texto que escribes se transfiere a servidores de Google en el '
          'exterior para generar la respuesta. Estos tratamientos se '
          'realizan bajo los acuerdos de transferencia de datos que esos '
          'proveedores ofrecen a sus clientes empresariales.\n\n'
          'Si en un momento la normatividad exige localizar ese tratamiento, '
          'adaptaremos la configuracion del chatbot y te lo informaremos. Para '
          'ejercer tus derechos ante estos proveedores puedes escribir a '
          '${AppConfig.supportEmail} y te orientaremos.',
    ),

    ContentSection(
      '8. Tus derechos como titular y como ejercerlos',
      'Como titular de los datos tienes derecho a conocer, consultar, '
          'actualizar, corregir y suprimir tus datos, revocar el '
          'consentimiento y obtener informacion sobre su tratamiento, asi como '
          'reclamar ante la Superintendencia de Industria y Comercio (SIC).\n\n'
          'Para ejercer cualquiera de ellos, escribe a '
          '${AppConfig.supportEmail} desde el correo con el que te registraste, '
          'indicando tu nombre, la identificacion del dato o del derecho que '
          'deseas ejercer y la documentacion que acredite tu identidad. '
          'Responderemos dentro de los plazos legales, en todo caso dentro '
          'del mes siguiente a la solicitud, con posibilidad de prorroga '
          'justificada.',
    ),

    ContentSection(
      '9. Autorizacion y caracter voluntario u obligatorio',
      'Al registrarte en la app autorizas de forma libre, previa, informada, '
          'inequivoca y expresa el tratamiento de tus datos personales para las '
          'finalidades descritas. El tratamiento de los datos necesarios para '
          'gestionar tu pedido tiene caracter obligatorio por obligacion legal. '
          'Puedes revocar tu autorizacion en cualquier momento escribiendo a '
          '${AppConfig.supportEmail}, sin efectos retroactivos sobre los '
          'tratamientos ya realizados.',
    ),

    ContentSection(
      '10. Cesion y no venta de datos',
      'Kronio Market no vende ni cede tus datos personales con fines '
          'comerciales a terceros. Unicamente los compartimos con los '
          'encargados y las autoridades necesarias para prestar el servicio y '
          'cumplir obligaciones legales, en los terminos descritos en este '
          'documento.',
    ),
  ],
);
