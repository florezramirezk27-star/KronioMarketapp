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
}
