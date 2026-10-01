import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../controllers/auth_controller.dart';
import '../controllers/catalog_controller.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';

/// Todo lo que la app necesita antes de poder pintar la primera pantalla.
///
/// Se carga una sola vez al arrancar y se pasa ya construido a [KronioApp].
/// Antes cada pantalla creaba su propio cliente HTTP y su propio
/// `CatalogController`, asi que el splash solo cubria el carrito local y el
/// catalogo recien aparecia con un spinner despues.
class AppBootstrap {
  const AppBootstrap({
    required this.cart,
    required this.auth,
    required this.catalog,
    this.packageInfo,
  });

  final CartService cart;
  final AuthController auth;
  final CatalogController catalog;

  /// Ya leido en el arranque para que el footer y el perfil no aparezcan con
  /// un "desconocida" en el primer frame. `null` si la plataforma no lo entrego.
  final PackageInfo? packageInfo;
}

/// Carga lo que la app necesita antes de mostrar la primera pantalla.
///
/// Las tres cosas son independientes entre si (el carrito y la sesion son de
/// disco, el catalogo es de red), asi que se piden en paralelo.
///
/// Nunca lanza: si algo falla se devuelve lo que se haya podido cargar y la app
/// arranca igual. Un splash colgado es peor que una pantalla con error y boton
/// de reintentar.
Future<AppBootstrap> loadBootstrap() async {
  // El carrito y la sesion son locales y rapidos; el catalogo es de red.
  final cartFuture = CartService.load();
  final authFuture = AuthService.create();
  final catalog = CatalogController(api: ApiService());
  final packageInfoFuture = _readPackageInfo();

  // `restore()` ya captura sus propios errores y el `CatalogController.load()`
  // resuelve en estado de error en vez de lanzar, asi que ninguno de los dos
  // puede romper el arranque.
  final catalogFuture = catalog.load();
  final authFutureRestored = _restore(authFuture);

  final results = await Future.wait([
    _withTimeout(cartFuture, 'carrito'),
    _withTimeout(authFutureRestored, 'sesion'),
    _withTimeout(catalogFuture, 'catalogo'),
    _withTimeout(packageInfoFuture, 'version'),
  ]);

  return AppBootstrap(
    cart: results[0] as CartService,
    auth: results[1] as AuthController,
    catalog: catalog,
    packageInfo: results[3] as PackageInfo?,
  );
}

/// Crea el [AuthController] y restaura la sesion.
///
/// Se separa de [loadBootstrap] para poder aplicar el mismo timeout a las dos
/// mitades: crear el servicio y consultarlo al backend son esperas distintas.
Future<AuthController> _restore(Future<AuthService> serviceFuture) async {
  final service = await serviceFuture;
  final auth = AuthController(service: service);
  unawaited(auth.restore());
  return auth;
}

Future<T?> _withTimeout<T>(Future<T> future, String label) async {
  try {
    return await future.timeout(AppConfig.startupTimeout);
  } catch (_) {
    // Se registra para poderdiagnosticarlo en el log, sin romper el arranque.
    debugPrint('Kronio: la carga de "$label" no termino a tiempo.');
    return null;
  }
}

Future<PackageInfo?> _readPackageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    // En web y en tests `package_info_plus` no esta disponible. El footer y el
    // perfil lo tratan como "version desconocida".
    return null;
  }
}

/// Pantalla de bienvenida: logo, nombre y eslogan de la marca.
///
/// Se muestra mientras [loadBootstrap] resuelve, para que el usuario vea la
/// marca en vez de una pantalla en blanco.
///
/// Usa colores fijos en vez de los del tema a proposito: tiene que ser igual
/// que el splash nativo de Android (`launch_background.xml` y
/// `values/styles.xml`), que se pinta antes de que exista el arbol de widgets.
/// Si se usara el tema, en modo oscuro el fondo cambiaria y se veria un
/// parpadeo al pasar del splash nativo al de Flutter.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandLogo(size: 96),
            SizedBox(height: 20),
            Text(
              'Kronio Market',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tu tienda de confianza',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
