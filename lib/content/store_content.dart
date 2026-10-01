/// Contenido de las paginas informativas del footer.
///
/// El backend no expone endpoints de contenido estatico (verificado: `/pages`,
/// `/content`, `/settings`, `/legal`, `/faq` responden 404), asi que el texto
/// vive aqui y se compila dentro de la app.
///
/// Los dos documentos legales ([termsContent] y [privacyContent]) son el texto
/// redactado para Kronio Market, con citas al articulo 50 de la Ley 1480 de
/// 2011 (literal a, identidad del proveedor), a la Ley 2439 de 2024 que lo
/// modifica, y a la Ley 1581 de 2012 con sus decretos reglamentarios. Los datos
/// que cambian de una empresa a otra (razon social, NIT, direccion, telefono,
/// representante) no estan escritos a mano: salen de `AppConfig`, que los lee
/// con `--dart-define` para que no queden en el repositorio y para poder
/// corregirlos sin volver a firmar el APK.
///
/// NOTA SOBRE ACENTOS
///
/// A diferencia del resto del proyecto, este archivo si usa tildes y la "ñ".
/// Es una excepcion deliberada: el texto es un documento legal que se lee en
/// pantalla completa y "Terminos", "articulo" o "informacion" se leen como
/// errores. `test/content/store_content_test.dart` vigila que el archivo no
/// sufra sustituciones de codificacion, que es como se corromperia.
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

/// Nombre comercial de la tienda, tal como se publica en los documentos.
const String storeName = 'Kronio Market';

// -----------------------------------------------------------------------------
// Bloques de datos que se repiten en los documentos
// -----------------------------------------------------------------------------

/// Bloque de "informacion del proveedor", exigido por el literal a) del
/// articulo 50 de la Ley 1480 de 2011.
///
/// Se arma con [AppConfig] y no con texto fijo: el NIT y la direccion son los
/// datos que mas cambian, y tenerlos escritos a mano en dos documentos es la
/// forma mas rapida de que dejen de coincidir entre si.
String get _providerBlock =>
    'Nombre o razón social: $storeName.\n'
    'NIT: ${AppConfig.legalOrPending(AppConfig.legalNit)}.\n'
    'Dirección de notificación judicial: '
    '${AppConfig.legalOrPending(AppConfig.legalAddress)}, '
    '${AppConfig.legalCity}.\n'
    'Teléfono: ${AppConfig.legalOrPending(AppConfig.legalPhone)}.\n'
    'Correo electrónico: ${AppConfig.supportEmail}.';

/// Bloque de canales de atencion (PQRS), exigido por el literal g) del
/// articulo 50: debe existir en el mismo medio en que se vende, con radicado y
/// seguimiento.
///
/// El aviso de que cada PQRS genera radicado queda acompanado de un "y a mas
/// tardar", porque un compromiso de plazo que el sistema no cumple es peor que
/// no comprometerlo.
String get _contactBlock =>
    'Correo electrónico: ${AppConfig.supportEmail}\n'
    'Teléfono: ${AppConfig.legalOrPending(AppConfig.legalPhone)}\n'
    'Dirección: ${AppConfig.legalOrPending(AppConfig.legalAddress)}, '
    '${AppConfig.legalCity}';

// -----------------------------------------------------------------------------
// Sobre nosotros
// -----------------------------------------------------------------------------

/// Que es Kronio Market y como funciona.
final aboutContent = ContentDocument(
  title: 'Sobre nosotros',
  updatedAt: 'Septiembre de 2026',
  intro:
      'Kronio Market es una tienda en línea orientada al mercado colombiano. '
      'Traemos productos de distintos proveedores en un solo catálogo, con '
      'precios y descuentos visibles antes de agregar algo al carrito.',
  sections: [
    ContentSection(
      'Qué puedes hacer aquí',
      'Navegar el catálogo por categorías, buscar productos, ver el detalle '
          'con su galería de imágenes y video, agregar al carrito, ajustar '
          'cantidades según el stock disponible, crear una cuenta, registrar '
          'un pedido y seguir su envío.\n\n'
          'El chatbot KronioBot responde preguntas sobre stock, precios y '
          'estado de tus pedidos, y puede mostrarte productos relacionados '
          'mientras conversa.',
    ),
    ContentSection(
      'Cómo obtenemos los productos',
      'Trabajamos con proveedores verificados mediante Dropi, una plataforma '
          'colombiana de dropshipping. Eso significa que no siempre '
          'almacenamos nosotros: cuando confirmas un pedido, se genera una '
          'orden de envío con el proveedor correspondiente, que es quien '
          'prepara y despacha.\n\n'
          'Por eso el precio y la disponibilidad que ves pueden cambiar en '
          'cualquier momento; lo que muestra la app es la foto más reciente '
          'que tenemos del inventario del proveedor.',
    ),
    ContentSection(
      'Pagos y envíos',
      'El pago es contra entrega: pagas el valor total en efectivo al '
          'transportador en el momento en que recibes tus productos. Cada '
          'pedido tiene un número de seguimiento que puedes consultar en '
          'cualquier momento y recibes confirmaciones por correo electrónico '
          'en cada cambio de estado.',
    ),
    ContentSection('Información del proveedor', _providerBlock),
  ],
);

// -----------------------------------------------------------------------------
// Terminos y condiciones
// -----------------------------------------------------------------------------

/// Terminos y condiciones de uso y compra.
///
/// Aplica el articulo 48 de la Ley 1480 de 2011 (condiciones generales del
/// contrato en ventas a distancia) y los literales a, b, c, g y h del
/// articulo 50, en la redaccion que les dio la Ley 2439 de 2024.
final termsContent = ContentDocument(
  title: 'Términos y condiciones',
  updatedAt: 'Septiembre de 2026',
  intro:
      'Última actualización: Septiembre de 2026. Vigentes de conformidad con la '
      'Ley 1480 de 2011 (Estatuto del Consumidor), la Ley 2439 de 2024 y el '
      'Decreto 587 de 2016.\n\n'
      'Estos términos y condiciones regulan la relación entre $storeName y los '
      'consumidores que utilizan nuestro sitio de comercio electrónico. Al '
      'momento de confirmar una compra, usted acepta de manera expresa e '
      'inequívoca las condiciones generales del contrato (artículo 48 de la Ley '
      '1480 de 2011), dejando constancia de la aceptación mediante el registro '
      'de su transacción.\n\n'
      'La Tienda se reserva el derecho de modificar estos términos en cualquier '
      'momento. Los cambios entrarán en vigor después de su publicación en el '
      'sitio y no afectarán las órdenes ya confirmadas. Le recomendamos revisar '
      'periódicamente esta página.',
  sections: [
    ContentSection(
      '1. Información del proveedor',
      'Conforme al literal a) del artículo 50 de la Ley 1480 de 2011, el '
          'proveedor que ofrece productos mediante comercio electrónico debe '
          'informar de forma cierta, fidedigna, suficiente, clara, accesible y '
          'actualizada su identidad. De conformidad con lo anterior:\n\n'
          '$_providerBlock\n\n'
          'La entrega o distribución de productos con descuento, rebaja o con '
          'carácter promocional está sujeta a las reglas contenidas en la Ley '
          '1480 de 2011.',
    ),
    ContentSection(
      '2. Aceptación de los términos',
      'Estos términos y condiciones regulan la relación entre $storeName y los '
          'consumidores que utilizan nuestro sitio de comercio electrónico. Al '
          'momento de confirmar una compra, usted acepta de manera expresa e '
          'inequívoca las condiciones generales del contrato (artículo 48 de la '
          'Ley 1480 de 2011), dejando constancia de la aceptación mediante el '
          'registro de su transacción.\n\n'
          'La Tienda se reserva el derecho de modificar estos términos en '
          'cualquier momento. Los cambios entrarán en vigor después de su '
          'publicación en el sitio y no afectarán las órdenes ya confirmadas. '
          'Le recomendamos revisar periódicamente esta página.',
    ),
    ContentSection(
      '3. Productos e información suministrada',
      'De acuerdo con el literal b) del artículo 50 de la Ley 1480 de 2011, '
          'suministramos información cierta, fidedigna, suficiente, clara y '
          'actualizada respecto de los productos ofrecidos, incluyendo '
          'características, materiales, usos, restricciones de uso y cuidado, '
          'propiedades y calidad, de forma que el consumidor pueda hacerse una '
          'representación lo más aproximada a la realidad del producto.\n\n'
          'Las imágenes son de carácter ilustrativo. Hacemos esfuerzos '
          'razonables por mostrar descripciones y fotografías precisas, pero '
          'los colores y detalles pueden variar según las condiciones de cada '
          'pantalla.',
    ),
    ContentSection(
      '4. Precios e impuestos',
      'Todos los precios están expresados en Pesos Colombianos (COP) e incluyen '
          'los impuestos, costos y gastos necesarios para adquirir el producto. '
          'En caso de aplicarse gastos de envío, estos se informan de forma '
          'separada y clara antes de finalizar la transacción (literal c) del '
          'artículo 50 de la Ley 1480 de 2011).\n\n'
          'Los precios están sujetos a cambios sin previo aviso, pero los '
          'cambios no afectarán las órdenes ya confirmadas. En caso de error '
          'manifiesto en el precio publicado, la Tienda podrá cancelar la orden '
          'y devolver la totalidad del dinero pagado.',
    ),
    ContentSection(
      '5. Proceso de compra y resumen del pedido',
      'Antes de finalizar la transacción, le presentamos un resumen del pedido '
          'con la descripción completa de los bienes, el precio individual de '
          'cada uno, el precio total y, de ser aplicable, los costos de envío. '
          'Usted puede verificar, modificar o cancelar la transacción antes de '
          'concluirla. La aceptación de la transacción es expresa, '
          'inequívoca y verificable.\n\n'
          'Concluida la transacción, le remitimos a más tardar el día '
          'calendario siguiente un acuse de recibo del pedido con la '
          'información del tiempo de entrega, precio exacto, impuestos, gastos '
          'de envío y la forma en que se realizó el pago. También recibirá el '
          'número de seguimiento de su orden una vez sea despachada.',
    ),
    ContentSection(
      '6. Medios de pago',
      'El método de pago disponible en la Tienda es el pago contra entrega: '
          'usted paga el valor del pedido en efectivo en el momento en que '
          'recibe sus productos.\n\n'
          'Pago contra entrega (efectivo): se cancela la totalidad del pedido, '
          'incluidos los gastos de envío, directamente al transportador al '
          'momento de la entrega. No se requiere ningún pago anticipado para '
          'realizar la compra.\n\n'
          'Por la naturaleza de este método de pago, no procesamos pagos con '
          'tarjetas o plataformas de pago en línea, y tampoco almacenamos datos '
          'de medios de pago en nuestros servidores.',
    ),
    ContentSection(
      '7. Envíos y entrega',
      'Realizamos envíos a todo el territorio colombiano. El plazo de entrega '
          'se informa de manera previa a la finalización de la transacción. A '
          'falta de plazo pactado, el pedido será entregado a más tardar dentro '
          'de los treinta (30) días calendario siguientes a la recepción de su '
          'pedido, de conformidad con el literal h) del artículo 50 de la Ley '
          '1480 de 2011.\n\n'
          'Si la entrega supera el plazo pactado o los treinta (30) días '
          'calendario, o si el producto adquirido no se encuentra disponible, '
          'usted podrá resolver el contrato unilateralmente y obtener la '
          'devolución de todas las sumas pagadas sin retención o descuento '
          'alguno, en un plazo máximo de quince (15) días calendario conforme '
          'a la Ley 2439 de 2024.\n\n'
          'Es responsabilidad del comprador suministrar una dirección de envío '
          'correcta y completa. Los costos de reenvío por dirección incorrecta '
          'o por no recepción del pedido en los términos pactados serán '
          'asumidos por el comprador.',
    ),
    ContentSection(
      '8. Derecho de retracto',
      'Usted tiene derecho a retractarse de la compra dentro de los cinco (5) '
          'días hábiles siguientes a la entrega del bien, sin necesidad de '
          'justificar su decisión.\n\n'
          'De conformidad con el artículo 47 de la Ley 1480 de 2011, en las '
          'ventas a distancia o a través de medios electrónicos se entenderá '
          'pactado el derecho de retracto. En caso de ejercerlo, se resolverá '
          'el contrato y le reintegraremos el dinero que haya pagado:\n\n'
          '- El producto debe devolverse por los mismos medios y en las mismas '
          'condiciones en que lo recibió, con todos sus empaques y accesorios.\n'
          '- Los costos de transporte y demás que conlleve la devolución serán '
          'cubiertos por usted, salvo que el defecto corresponda a la calidad o '
          'idoneidad del producto.\n'
          '- La devolución del dinero se realizará en un plazo máximo de quince '
          '(15) días calendario desde el ejercicio del derecho, sin retenciones '
          'ni descuentos, por el medio que usted elija o por el medio acordado '
          '(Ley 2439 de 2024, artículo 5). La información de las opciones '
          'disponibles le será comunicada de forma clara y detallada.\n\n'
          'Se exceptúa del derecho de retracto, conforme a la ley, los '
          'siguientes casos:\n\n'
          '- Contratos de prestación de servicios cuya ejecución haya comenzado '
          'con su acuerdo.\n'
          '- Productos confeccionados conforme a las especificaciones del '
          'consumidor o claramente personalizados.\n'
          '- Productos que por su naturaleza no puedan ser devueltos o puedan '
          'deteriorarse o caducar con rapidez.\n'
          '- Productos perecederos.\n'
          '- Productos de uso personal de carácter higiénico cuyo sello haya sido '
          'retirado.\n'
          '- Productos cuyo precio esté sujeto a fluctuaciones de coeficientes '
          'del mercado financiero que no puedan ser controladas por el '
          'proveedor.',
    ),
    ContentSection(
      '9. Garantía legal',
      'Todos los productos comercializados cuentan con la garantía legal '
          'establecida en los artículos 7 y 8 de la Ley 1480 de 2011, que obliga '
          'al productor y al proveedor a responder por la calidad, idoneidad, '
          'seguridad y el buen estado y funcionamiento de los productos.\n\n'
          'Plazo: la garantía empieza a correr desde la entrega del producto al '
          'consumidor. De no indicarse un término específico, la garantía es de '
          'un (1) año para productos nuevos y el término de la fecha de '
          'expiración para productos perecederos.\n\n'
          'Cobertura: reparación totalmente gratuita de los defectos del bien, '
          'incluyendo su transporte de ser necesario y el suministro oportuno '
          'de repuestos. Si el bien no admite reparación, se procederá a su '
          'reposición o a la devolución del dinero (artículo 11 de la Ley 1480 '
          'de 2011).\n\n'
          'No cubre: daños por uso indebido, accidentes, modificaciones no '
          'autorizadas o desgaste normal. La garantía legal no tendrá '
          'contraprestación adicional al precio del producto.\n\n'
          'Para hacer efectiva la garantía, debe presentar la factura o '
          'comprobante de compra y describir el defecto. Ante los consumidores, '
          'la responsabilidad recae solidariamente en productores y proveedores '
          '(artículo 10 de la Ley 1480 de 2011).',
    ),
    ContentSection(
      '10. Reversión de pagos',
      'Conforme al artículo 51 de la Ley 1480 de 2011 y al procedimiento del '
          'Decreto 587 de 2016, usted puede solicitar la reversión del cargo '
          'realizado cuando la transacción se haya efectuado mediante fraude, el '
          'producto no haya sido entregado, no corresponda a lo ofrecido o haya '
          'sido devuelto.\n\n'
          'Para gestionar su solicitud, contáctenos a través de los canales de '
          'atención mencionados en la sección 12 y consigne los soportes '
          'correspondientes. La Tienda orientará el proceso hasta su solución y '
          'le devolverá las sumas pagadas por el medio acordado dentro de los '
          'plazos legales.',
    ),
    ContentSection(
      '11. Cambios y devoluciones',
      'Atendemos solicitudes de cambio o devolución dentro de los plazos '
          'legales. Si el producto presenta defecto de calidad o no corresponde '
          'a lo solicitado, cubriremos los costos de transporte de la devolución '
          'conforme a la garantía legal. En cualquier otro caso, se aplican los '
          'términos del derecho de retracto descritos en la sección 8.\n\n'
          'El producto debe devolverse en su estado original, sin uso indebido y '
          'con la totalidad de sus empaques, accesorios y la factura de compra.',
    ),
    ContentSection(
      '12. PQRS y canales de atención',
      'De conformidad con el literal g) del artículo 50 de la Ley 1480 de '
          '2011, ponemos a su disposición canales de fácil acceso que garantizan '
          'la orientación y asistencia a los consumidores y la trazabilidad de '
          'las reclamaciones presentadas. Cada petición, queja, reclamo o '
          'sugerencia (PQRS) genera un número de radicado con fecha y hora, y un '
          'mecanismo de seguimiento.\n\n'
          '$_contactBlock\n\n'
          'También puede acudir directamente a la Superintendencia de Industria '
          'y Comercio (SIC), autoridad colombiana de protección al consumidor, '
          'en www.sic.gov.co.',
    ),
    ContentSection(
      '13. Propiedad intelectual',
      'Todos los contenidos del sitio web, incluyendo textos, imágenes, '
          'logotipos, diseños, iconos, software y código, son propiedad de '
          '$storeName o de sus proveedores de contenido y están protegidos por '
          'las leyes de propiedad intelectual colombianas e internacionales. '
          'Queda prohibida su reproducción o uso no autorizado.',
    ),
    ContentSection(
      '14. Limitación de responsabilidad',
      'En la medida máxima permitida por la ley colombiana, la Tienda no será '
          'responsable por daños indirectos o consecuentes derivados del uso o '
          'la imposibilidad de usar la plataforma. Nuestra responsabilidad frente '
          'al consumidor se rige por las normas de protección al consumidor y no '
          'excluye las garantías y derechos que le asisten por mandato legal.',
    ),
    ContentSection(
      '15. Ley aplicable y jurisdicción',
      'Estos términos se rigen por las leyes de la República de Colombia, en '
          'especial por la Ley 1480 de 2011 (Estatuto del Consumidor), su '
          'normativa reglamentaria y las normas que las modifiquen o adicionen, '
          'incluida la Ley 2439 de 2024. Las controversias serán conocidas por '
          'las autoridades competentes de la ciudad de Bogotá, D.C., sin '
          'perjuicio de las facultades jurisdiccionales de la Superintendencia de '
          'Industria y Comercio.',
    ),
    ContentSection(
      '16. Contacto',
      'Para cualquier pregunta, queja o solicitud relacionada con estos '
          'términos, contáctenos a través de los canales indicados en la sección '
          '12. También puede consultar nuestra Política de Privacidad.',
    ),
  ],
);

// -----------------------------------------------------------------------------
// Politica de privacidad
// -----------------------------------------------------------------------------

/// Politica de tratamiento de datos personales.
///
/// Es a la vez el aviso de privacidad y el aviso de tratamiento de datos de la
/// Ley 1581 de 2012: reune los elementos del articulo 3 (responsable,
/// finalidad, forma de tratamiento, derechos, procedimiento) y desarrolla los
/// principios del articulo 4 y los derechos de los articulos 8, 14 y 15.
///
/// Por eso no hay un tercer documento "Datos personales": este ya lo es.
final privacyContent = ContentDocument(
  title: 'Política de Privacidad',
  updatedAt: 'Septiembre de 2026',
  intro:
      'Última actualización: Septiembre de 2026. Política de tratamiento de la '
      'información conforme a la Ley 1581 de 2012, el Decreto 1377 de 2013 y el '
      'Decreto 1074 de 2015.',
  sections: [
    ContentSection(
      '1. Responsable del tratamiento',
      'El Responsable del tratamiento de los datos personales es $storeName. '
          'Para cualquier consulta puede contactarnos a través de:\n\n'
          '$_contactBlock\n\n'
          'NIT: ${AppConfig.legalOrPending(AppConfig.legalNit)}.',
    ),
    ContentSection(
      '2. Normativa aplicable',
      'Esta política desarrolla el derecho constitucional a la protección de '
          'datos (artículo 15 de la Constitución Política de Colombia) y se rige '
          'por:\n\n'
          '- Ley 1581 de 2012 — Régimen general de protección de datos '
          'personales.\n'
          '- Decreto 1377 de 2013 — Reglamentación parcial de la Ley 1581 de '
          '2012.\n'
          '- Decreto 1074 de 2015 — Decreto único reglamentario del sector '
          'comercio.\n'
          '- Las directrices y circulares de la Superintendencia de Industria y '
          'Comercio (SIC).',
    ),
    ContentSection(
      '3. Principios del tratamiento',
      'De conformidad con el artículo 4 de la Ley 1581 de 2012, el tratamiento '
          'de sus datos personales se desarrolla con sujeción a los siguientes '
          'principios:\n\n'
          '- Legalidad: el tratamiento se rige únicamente por las normas vigentes '
          'aplicables.\n'
          '- Finalidad: sus datos se recopilan para finalidades específicas, '
          'explícitas y legítimas, informadas previamente.\n'
          '- Libertad: el tratamiento se realiza con su autorización previa, '
          'expresa e informada.\n'
          '- Veracidad o calidad: los datos son veraces, completos, exactos, '
          'actualizados y pertinentes.\n'
          '- Transparencia: puede obtener información sobre la existencia y '
          'características del tratamiento, en cualquier momento.\n'
          '- Acceso y circulación restringida: sus datos solo son tratados por '
          'personas autorizadas.\n'
          '- Seguridad: se adoptan medidas técnicas, humanas y administrativas '
          'para su protección.\n'
          '- Confidencialidad: la información se mantiene reservada, incluso '
          'después de finalizada la relación.',
    ),
    ContentSection(
      '4. Datos personales que recopilamos',
      '4.1 Datos suministrados por usted\n'
          '- Nombres y apellidos\n'
          '- Documento de identificación\n'
          '- Correo electrónico y número de teléfono\n'
          '- Dirección de envío y facturación\n'
          '- Datos de la cuenta de usuario\n\n'
          '4.2 Datos recopilados automáticamente\n'
          '- Dirección IP, tipo de navegador y sistema operativo\n'
          '- Páginas visitadas, productos consultados y comportamiento de '
          'navegación\n'
          '- Cookies y tecnologías similares (ver sección 14)\n\n'
          'La recolección se limita a los datos pertinentes y adecuados para '
          'las finalidades informadas en esta política (Decreto 1377 de 2013, '
          'artículo 4).',
    ),
    ContentSection(
      '5. Finalidades del tratamiento',
      'Sus datos personales serán utilizados para las siguientes finalidades '
          'específicas, explícitas y legítimas:\n\n'
          '- Procesar, gestionar y entregar sus pedidos, y gestionar cambios y '
          'devoluciones.\n'
          '- Crear y administrar su cuenta de usuario.\n'
          '- Enviar confirmaciones de pedido, facturas, actualizaciones de envío '
          'y comunicaciones sobre su cuenta.\n'
          '- Atender sus peticiones, quejas, reclamos y sugerencias (PQRS).\n'
          '- Verificar la identidad y prevenir el fraude.\n'
          '- Mejorar nuestros productos, servicios y experiencia de compra.\n'
          '- Enviar comunicaciones comerciales y promocionales únicamente con su '
          'autorización previa.\n'
          '- Cumplir con obligaciones legales, fiscales y regulatorias.',
    ),
    ContentSection(
      '6. Autorización previa, expresa e informada',
      'De acuerdo con el artículo 9 de la Ley 1581 de 2012, el tratamiento de '
          'datos personales requiere su autorización previa, expresa e informada. '
          'La autorización se obtiene por cualquier medio que permita su consulta '
          'posterior (escrito, oral o mediante conductas inequívocas; el '
          'silencio nunca equivale a autorización) y se solicita antes o a más '
          'tardar en el momento de la recolección de los datos.\n\n'
          'Al aceptar esta política y/o nuestros términos de compra, usted '
          'autoriza el tratamiento de sus datos personales conforme a las '
          'finalidades aquí descritas y conservamos prueba de dicha '
          'autorización (Decreto 1377 de 2013, artículo 7).',
    ),
    ContentSection(
      '7. Datos sensibles',
      'Datos sensibles son aquellos que afectan la intimidad del titular o cuyo '
          'uso indebido puede generar discriminación (origen étnico o racial, '
          'orientación política, convicciones religiosas o filosóficas, '
          'pertenencia sindical, biometría, salud, etc.), conforme al artículo 5 '
          'de la Ley 1581 de 2012.\n\n'
          '$storeName no solicita ni trata datos sensibles como requisito para '
          'acceder a sus productos o servicios, salvo que usted los suministre '
          'voluntariamente o que la ley lo exija. En tal caso, se aplicará lo '
          'dispuesto en el artículo 6 de la Ley 1581 de 2012: usted será '
          'informado de que no está obligado a autorizar su tratamiento, se le '
          'indicará cuáles datos son sensibles y la finalidad específica, y se '
          'obtendrá su consentimiento expreso y facultativo.',
    ),
    ContentSection(
      '8. Derechos del titular de los datos',
      'De conformidad con el artículo 8 de la Ley 1581 de 2012, usted tiene los '
          'siguientes derechos (hábeas data):\n\n'
          '- Conocer (acceder): obtener de nosotros información clara y completa '
          'sobre sus datos y su tratamiento.\n'
          '- Actualizar y rectificar: solicitar la corrección de datos inexactos, '
          'incompletos o desactualizados.\n'
          '- Suprimir: solicitar la eliminación de sus datos cuando no sean '
          'necesarios para las finalidades autorizadas.\n'
          '- Revocar la autorización: revocar total o parcialmente la '
          'autorización otorgada para el tratamiento.\n'
          '- Presentar reclamos por el uso indebido de sus datos.\n'
          '- Solicitar prueba de la autorización otorgada.\n\n'
          'Los derechos podrán ejercerse por usted, sus causahabientes, su '
          'representante o el apoderado. Cuando la solicitud sea presentada por '
          'persona distinta del titular, se deberá acreditar la calidad en que '
          'actúa.',
    ),
    ContentSection(
      '9. Procedimiento de consultas y reclamos',
      'Consultas: conforme al artículo 14 de la Ley 1581 de 2012, las consultas '
          'sobre sus datos personales se atenderán dentro de los diez (10) días '
          'hábiles siguientes a la recepción. Cuando no sea posible atenderla en '
          'dicho término, se le informará la razón de la demora y la fecha en que '
          'será atendida, sin exceder de cinco (5) días hábiles adicionales.\n\n'
          'Reclamos: conforme al artículo 15 de la Ley 1581 de 2012, los reclamos '
          'por tratamiento no autorizado se atenderán dentro de los quince (15) '
          'días hábiles siguientes a la recepción. Si no es posible atenderlo en '
          'ese plazo, se le informará la razón de la demora y la fecha en que se '
          'atenderá, sin exceder de ocho (8) días hábiles adicionales.\n\n'
          'Para ejercer sus derechos, envíe su solicitud a '
          '${AppConfig.supportEmail} indicando su nombre, el derecho que desea '
          'ejercer, los datos objeto de la solicitud y una breve descripción de '
          'la petición. Le daremos respuesta por el mismo medio y le '
          'confirmaremos la radicación de su solicitud.',
    ),
    ContentSection(
      '10. Transferencias de datos',
      'No vendemos, alquilamos ni compartimos sus datos personales con terceros no '
          'relacionados. Los datos solo se comparten, de forma limitada, con:\n\n'
          '- Empresas de transporte y logística, para la entrega de los pedidos.\n'
          '- Proveedores tecnológicos (hosting, analítica, mensajería y soporte).\n'
          '- Autoridades competentes, cuando sea requerido por disposición legal o '
          'judicial.\n\n'
          'Todos los terceros que tratan sus datos por cuenta de $storeName actúan '
          'como Encargados del tratamiento, solo para los fines autorizados y con '
          'obligaciones de confidencialidad y seguridad (artículo 12 de la Ley '
          '1581 de 2012).',
    ),
    ContentSection(
      '11. Transferencias internacionales',
      'El chatbot de ventas de esta app (KronioBot) genera sus respuestas con un '
          'modelo de inteligencia artificial de Google. Eso implica que el texto '
          'de su conversación se envía a servidores de Google ubicados fuera de '
          'Colombia. Las imágenes del catálogo se sirven desde una red de '
          'distribución de contenido (CDN) en el exterior, que al pedirlas recibe '
          'su dirección IP.\n\n'
          'Cuando sus datos deban ser transferidos a un tercero ubicado fuera de '
          'Colombia, nos aseguraremos de que el país destino ofrezca niveles de '
          'protección adecuados conforme a los estándares de la SIC, o de que la '
          'transferencia se ajuste a las excepciones legales y a las declaraciones '
          'de conformidad aplicables (artículo 26 de la Ley 1581 de 2012).',
    ),
    ContentSection(
      '12. Conservación de los datos',
      'Conservaremos sus datos personales durante el tiempo necesario para cumplir '
          'las finalidades de esta política o el término exigido por las leyes '
          'aplicables. Los datos asociados a transacciones comerciales se conservan '
          'por el término exigido para el cumplimiento de obligaciones fiscales y '
          'contables. Una vez cumplida la finalidad o vencido el término, sus '
          'datos serán suprimidos de forma segura.',
    ),
    ContentSection(
      '13. Seguridad de los datos',
      'Implementamos medidas técnicas, humanas y administrativas orientadas a '
          'garantizar la seguridad y confidencialidad de sus datos (artículo 17 de '
          'la Ley 1581 de 2012), incluyendo:\n\n'
          '- Cifrado en tránsito (HTTPS/TLS) para las comunicaciones.\n'
          '- Almacenamiento cifrado de contraseñas.\n'
          '- Control de acceso por roles y registro de consultas.\n'
          '- Monitoreo de vulnerabilidades y copias de seguridad.\n\n'
          'En la app móvil, la sesión se mantiene con un token de acceso y no con '
          'cookies: el navegador de Android no permite que una aplicación lea ni '
          'escriba cookies de otros sitios.',
    ),
    ContentSection(
      '14. Cookies y tecnologías similares',
      'Esta política aplica a nuestros sitios web. La app móvil de $storeName no '
          'utiliza cookies: en un dispositivo Android las cookies pertenecen al '
          'navegador, no a la aplicación.\n\n'
          'En el sitio web, utilizamos cookies y tecnologías similares para el '
          'funcionamiento del sitio, mejorar la experiencia de compra y analizar el '
          'tráfico. Puede configurar el uso de cookies desde su navegador.\n\n'
          'Al entrar por primera vez le mostramos un aviso para que decida si '
          'permite o no las cookies que no son esenciales. Mientras no acepte, el '
          'sitio funciona igual, pero ninguna herramienta de medición o publicidad '
          'se carga en su dispositivo. Navegar por el sitio no se considera '
          'aceptación.\n\n'
          'Tipos de cookies:\n'
          '- Esenciales: necesarias para el carrito de compras, el inicio de sesión '
          'y la seguridad. Están siempre activas porque sin ellas el sitio no '
          'puede funcionar, y por eso no requieren su autorización.\n'
          '- De analítica y publicidad: el píxel de Meta (Facebook Pixel), que '
          'sirve para medir el tráfico y mostrarle anuncios relevantes. Solo se '
          'cargan si usted lo autoriza en el aviso de cookies.\n\n'
          'Cómo retirar su consentimiento: puede cambiar su decisión cuando quiera, '
          'sin que esto afecte al acceso a la tienda. Le recomendamos usar el enlace '
          'Configurar cookies que aparece al final de esta página. Allí puede '
          'aceptar todas las cookies, quedarse solo con las esenciales o elegir '
          'categoría por categoría. Si decide no permitir las de analítica y '
          'publicidad, las cookies que ya se habían guardado se eliminan de su '
          'navegador.\n\n'
          'También puede bloquear o eliminar cookies desde la configuración de su '
          'navegador. Tenga en cuenta que si bloquea las cookies esenciales, el '
          'carrito de compras y el inicio de sesión pueden dejar de funcionar.\n\n'
          'No utilizamos cookies de publicidad comportamental sin su autorización '
          'previa. El tratamiento de datos derivado de cookies queda sujeto a esta '
          'política.',
    ),
    ContentSection(
      '15. Datos de menores de edad',
      'Nuestros servicios y productos están dirigidos a personas mayores de 18 '
          'años. No recopilamos intencionalmente datos de menores. El tratamiento '
          'de datos de niñas, niños y adolescentes está sujeto a los requisitos '
          'especiales del Decreto 1377 de 2013 (artículo 12). Si tiene conocimiento '
          'de que hemos tratado datos de un menor sin autorización de sus padres o '
          'representantes legales, contáctenos de inmediato para proceder a su '
          'eliminación.',
    ),
    ContentSection(
      '16. Registro Nacional de Bases de Datos',
      'De conformidad con la Ley 1581 de 2012 y el Decreto 886 de 2014, '
          'complementamos las obligaciones propias de los Responsables del '
          'tratamiento, incluido, cuando corresponda, el registro de nuestras bases '
          'de datos en el Registro Nacional de Bases de Datos administrado por la '
          'Superintendencia de Industria y Comercio.',
    ),
    ContentSection(
      '17. Vigencia y cambios de esta política',
      'Esta política de tratamiento de la información entra en vigencia a partir de '
          'la fecha de la última actualización indicada al inicio de este documento. '
          'Nos reservamos el derecho de modificarla cuando sea necesario; los '
          'cambios serán publicados en esta página con la fecha de actualización '
          'correspondiente y, cuando sean significativos, se le notificará a través '
          'de un aviso visible en el sitio o por correo electrónico.',
    ),
    ContentSection(
      '18. Contacto',
      'Si tiene preguntas, inquietudes o desea presentar una queja sobre el '
          'tratamiento de sus datos personales, puede contactar a nuestro equipo de '
          'protección de datos en ${AppConfig.supportEmail}.\n\n'
          'Si considera que el tratamiento de sus datos vulnera la normativa '
          'aplicable, tiene derecho a presentar una reclamación ante la '
          'Superintendencia de Industria y Comercio (SIC) en www.sic.gov.co. También '
          'puede consultar los términos de compra de la tienda.',
    ),
  ],
);
