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
  /// OJO: el valor por defecto es un marcador de posicion. Antes de publicar en
  /// Play Store hay que confirmar el dominio real y, si cambia, compilar con
  /// `--dart-define=KRONIO_SUPPORT_EMAIL=contacto@dominio real`.
  ///
  /// Es lo que permite que "Contacto" tenga funcionalidad de verdad (abrir el
  /// cliente de correo) en vez de un dialogo que dice que no hay nada.
  static const String supportEmail = String.fromEnvironment(
    'KRONIO_SUPPORT_EMAIL',
    defaultValue: 'soporte@kroniomarket.co',
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
  //     --dart-define=KRONIO_LEGAL_NAME="..." \
  //     --dart-define=KRONIO_LEGAL_NIT="..." \
  //     --dart-define=KRONIO_LEGAL_ADDRESS="..." \
  //     --dart-define=KRONIO_LEGAL_CITY="..." \
  //     --dart-define=KRONIO_LEGAL_PHONE="..." \
  //     --dart-define=KRONIO_REPRESENTATIVE="..." \
  //     --dart-define=KRONIO_REPRESENTATIVE_ID="..."
  //
  // Los valores por defecto estan vacios a proposito: si un documento legal
  // muestra un hueco, se nota de inmediato. Poner un dato inventado seria peor
  // que no poner nada, porque un NIT falso es un problema legal.
  // ---------------------------------------------------------------------------

  /// Razon social o nombre del responsable del tratamiento.
  static const String legalName = String.fromEnvironment('KRONIO_LEGAL_NAME');

  /// NIT de la empresa, sin guiones ni puntos.
  static const String legalNit = String.fromEnvironment('KRONIO_LEGAL_NIT');

  /// Direccion fisica donde se puede ejercer el derecho de queja.
  static const String legalAddress = String.fromEnvironment(
    'KRONIO_LEGAL_ADDRESS',
  );

  /// Ciudad y departamento.
  static const String legalCity = String.fromEnvironment('KRONIO_LEGAL_CITY');

  /// Telefono de contacto.
  static const String legalPhone = String.fromEnvironment('KRONIO_LEGAL_PHONE');

  /// Nombre de quien responde por los datos personales.
  static const String representative = String.fromEnvironment(
    'KRONIO_REPRESENTATIVE',
  );

  /// Tipo y numero de documento del representante.
  static const String representativeId = String.fromEnvironment(
    'KRONIO_REPRESENTATIVE_ID',
  );

  /// `true` cuando los datos de la empresa estan completos.
  ///
  /// Lo usan los documentos legales para decidir si se pueden publicar o si hay
  /// que avisar de que faltan datos. Un documento con huecos es peor que uno
  /// ausente: un aviso de privacidad sin llenar no sirve ni como borrador.
  static bool get hasCompleteLegalData =>
      legalName.isNotEmpty &&
      legalNit.isNotEmpty &&
      legalAddress.isNotEmpty &&
      legalCity.isNotEmpty &&
      legalPhone.isNotEmpty &&
      representative.isNotEmpty;

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
