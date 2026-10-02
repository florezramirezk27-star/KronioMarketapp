import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../controllers/auth_controller.dart';
import '../controllers/catalog_controller.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/checkout_service.dart';
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
    required this.checkout,
    this.packageInfo,
  });

  final CartService cart;
  final AuthController auth;
  final CatalogController catalog;

  /// Compra y consulta de pedidos.
  ///
  /// Comparte el [ApiService] de la sesion ([AuthService.api]) a proposito, y no
  /// uno nuevo como el catalogo: el checkout necesita la cookie httpOnly y el
  /// token CSRF que ya estan cargados ahi. Con un cliente aparte, el POST a
  /// `/orders/checkout` llegaria sin sesion y el backend responderia 401 aunque
  /// el usuario tenga la sesion iniciada.
  final CheckoutService checkout;

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
    // Se arma con el cliente de la sesion ya resuelto, que es el unico que
    // tiene la cookie httpOnly. Ver la nota de [AppBootstrap.checkout].
    checkout: CheckoutService(api: (results[1] as AuthController).service.api),
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

/// Pantalla de bienvenida: solo el logo y el nombre de la marca.
///
/// Se muestra mientras [loadBootstrap] resuelve, para que el usuario vea la
/// marca en vez de una pantalla en blanco.
///
///lleva el eslogan ni el `CircularProgressIndicator` que tenia antes, a
/// pedido: el nombre de la tienda se lee de un vistazo y sin ruido. Eso deja
/// la carga invisible durante el arranque, que dura lo que el catalogo y la
/// sesion tarden en responder.
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
          ],
        ),
      ),
    );
  }
}
