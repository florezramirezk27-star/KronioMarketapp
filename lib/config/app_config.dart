/// Configuracion de la app, resuelta en tiempo de compilacion.
///
/// Los valores vienen de `--dart-define`, lo que permite apuntar el mismo
/// codigo a distintos backends sin tocar el fuente:
///
/// ```bash
/// flutter run --dart-define=KRONIO_API_URL=http://10.0.2.2:3000
/// flutter build apk --release --dart-define=KRONIO_API_URL=https://api.kronio.co
/// ```
///
/// Si no se define nada se usa el proxy publico de produccion, asi que
/// `flutter run` a secas funciona.
library;

class AppConfig {
  const AppConfig._();

  /// Base URL de la API, sin barra final.
  ///
  /// Android emulador: `http://10.0.2.2:3000` (localhost del host).
  static const String apiBaseUrl = String.fromEnvironment(
    'KRONIO_API_URL',
    defaultValue: 'https://ecomerce-delta-three.vercel.app/api/proxy',
  );

  /// Cuánto esperar la respuesta de una peticion antes de abortarla.
  ///
  /// Sin esto, si el servidor cuelga la app se queda con el spinner para
  /// siempre y el usuario no tiene forma de reintentar.
  static const Duration requestTimeout = Duration(
    seconds: int.fromEnvironment('KRONIO_TIMEOUT_SECONDS', defaultValue: 15),
  );

  /// Cuantos productos pedir por pagina.
  ///
  /// El backend pagina: pedir un numero fijo y no implementar scroll infinito
  /// hace que los productos que entren en la pagina 2 sean invisibles.
  static const int productsPerPage = int.fromEnvironment(
    'KRONIO_PAGE_SIZE',
    defaultValue: 20,
  );

  /// Nombre del entorno, solo para mostrar en la pantalla de perfil.
  static const String environment = String.fromEnvironment(
    'KRONIO_ENV',
    defaultValue: 'production',
  );

  /// Correo de soporte que abre el enlace "Contacto" del footer.
  ///
  /// Es el mismo correo que aparece en los documentos legales, asi que cambiarlo
  /// en un solo lado deja el resto mintiendo. Si lo cambias, recompila con
  /// `--dart-define=KRONIO_SUPPORT_EMAIL=correo@real`.
  ///
  /// Es lo que permite que "Contacto" tenga funcionalidad de verdad (abrir el
  /// cliente de correo) en vez de un dialogo que dice que no hay nada.
  static const String supportEmail = String.fromEnvironment(
    'KRONIO_SUPPORT_EMAIL',
    defaultValue: 'kroniomarket@gmail.com',
  );

  // ---------------------------------------------------------------------------
  // Datos de la empresa, usados en los documentos legales.
  //
  // Van como `String.fromEnvironment` y no como constantes fijas por una razon
  // concreta: son datos que cambian (se compra un dominio nuevo, se cambia de
  // direccion) y tenerlos en el codigo obliga a recompilar y volver a firmar el
  // APK para corregir una direccion. Ademas, en el repositorio publico no debe
  // quedar el NIT ni el nombre del representante legal.
  //
  // Compilalos asi:
  //   flutter build apk --release \
  //     --dart-define=KRONIO_LEGAL_NIT="900.123.456-7" \
  //     --dart-define=KRONIO_LEGAL_ADDRESS="Calle 100 # 20-30" \
  //     --dart-define=KRONIO_LEGAL_PHONE="+57 300 123 4567" \
  //     --dart-define=KRONIO_REPRESENTATIVE="Nombre del representante"
  //
  // Sin `--dart-define` quedan los valores de ejemplo de abajo, que son
  // marcadores de posicion propositados. `_isPlaceholder` los reconoce y los
  // documentos los muestran como "[pendiente de configurar]" en vez de
  // publicarlos como si fueran ciertos: un NIT de ejemplo mostrado a un
  // consumidor es una afirmacion falsa con apariencia legal, que es peor que
  // un hueco visible. Ver `hasCompleteLegalData`.
  // ---------------------------------------------------------------------------

  /// NIT de la empresa.
  ///
  /// Formato colombiano con puntos y guion: `900.123.456-7`.
  static const String legalNit = String.fromEnvironment(
    'KRONIO_LEGAL_NIT',
    defaultValue: '000.000.000-0',
  );

  /// Direccion fisica. Es la "direccion de notificacion judicial" que exige el
  /// literal a) del articulo 50 de la Ley 1480 de 2011, asi que debe incluir
  /// calle y numero, no solo la ciudad.
  static const String legalAddress = String.fromEnvironment(
    'KRONIO_LEGAL_ADDRESS',
    defaultValue: '[direccion pendiente de configurar]',
  );

  /// Ciudad y departamento.
  static const String legalCity = String.fromEnvironment(
    'KRONIO_LEGAL_CITY',
    defaultValue: 'Bogota, D.C., Colombia',
  );

  /// Telefono de contacto, con indicativo de pais.
  static const String legalPhone = String.fromEnvironment(
    'KRONIO_LEGAL_PHONE',
    defaultValue: '+57 (1) 555-1234',
  );

  /// Nombre de quien responde por los datos personales.
  static const String representative = String.fromEnvironment(
    'KRONIO_REPRESENTATIVE',
    defaultValue: '[representante legal pendiente de configurar]',
  );

  /// Tipo y numero de documento del representante.
  static const String representativeId = String.fromEnvironment(
    'KRONIO_REPRESENTATIVE_ID',
    defaultValue: '',
  );

  /// Nombres que son marcadores de posicion y no datos reales.
  ///
  /// Se comparan sin espacios y en minusculas para que cambiar el formato del
  /// marcador no rompa la deteccion. `000.000.000-0` es el NIT de ejemplo que
  /// aparece en toda guia de la SIC y `555-1234` es el telefono de ejemplo
  /// internacional: los dos son reconocibles, y por eso sirven de señal.
  static const Set<String> _placeholderValues = {
    '000.000.000-0',
    '+57(1)555-1234',
    '[direccionpendientedeconfigurar]',
    '[representantelegalpendientedeconfigurar]',
    '',
  };

  /// `true` si [value] sigue siendo un marcador de posicion.
  static bool _isPlaceholder(String value) =>
      _placeholderValues.contains(value.replaceAll(' ', '').toLowerCase());

  /// El dato si es real, o `[pendiente de configurar]` si no.
  ///
  /// Lo usan los documentos legales. Devolver el marcador en vez del valor de
  /// ejemplo es deliberado: un hueco se nota y se arregla, un NIT falso se
  /// publica.
  static String legalOrPending(String value) =>
      _isPlaceholder(value) ? '[pendiente de configurar]' : value;

  /// `true` cuando los datos de la empresa ya son reales.
  ///
  /// Lo usan la pantalla de contenido y los tests para decidir si el documento
  /// se publica tal cual o si debe avisar que esta pendiente de completar.
  static bool get hasCompleteLegalData =>
      !_isPlaceholder(legalNit) &&
      !_isPlaceholder(legalAddress) &&
      !_isPlaceholder(legalPhone) &&
      !_isPlaceholder(representative);

  /// Tiempo maximo que se espera el arranque antes de montar la app igual.
  ///
  /// El splash aguanta mientras se cargan el carrito, la sesion y el catalogo.
  /// Si la red se queda colgada, [CatalogController.load] resuelve por su cuenta
  /// con el error, pero este tope evita que un fallo inesperado deje al usuario
  /// mirando el logo indefinidamente.
  static const Duration startupTimeout = Duration(
    seconds: int.fromEnvironment('KRONIO_STARTUP_SECONDS', defaultValue: 20),
  );
}
