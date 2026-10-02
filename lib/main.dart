import 'package:flutter/material.dart';

import 'screens/app_splash.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_scope.dart';
import 'widgets/cart_scope.dart';
import 'widgets/catalog_scope.dart';
import 'widgets/checkout_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KronioApp());
}

/// Genera las rutas de auth, que necesitan ser `Route<bool>`.
///
/// Van en `onGenerateRoute` y no en `routes` a proposito: se abren con
/// `pushNamed<bool>` y ambas pantallas hacen `pop(true)` cuando dejan la sesion
/// iniciada, para que quien las abrio pueda cerrarse tambien.
///
/// `routes` no puede servir para eso: Flutter envuelve cada entrada en su
/// `pageRouteBuilder`, que siempre devuelve `MaterialPageRoute<dynamic>`, y al
/// castear esa ruta a `Route<bool>` revienta con
/// `type 'MaterialPageRoute<dynamic>' is not a subtype of type 'Route<bool?>'`.
///
/// Vive fuera de [KronioApp] para que un test pueda usar exactamente el mismo
/// generador que la app y cubra esa regresion.
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/login':
      return MaterialPageRoute<bool>(
        builder: (_) => const LoginScreen(),
        settings: settings,
      );
    case '/register':
      return MaterialPageRoute<bool>(
        builder: (_) => const RegisterScreen(),
        settings: settings,
      );
  }
  return null;
}

class KronioApp extends StatelessWidget {
  const KronioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kronio Market',
      debugShowCheckedModeBanner: false,
      // Sigue la preferencia del sistema (claro / oscuro / automatico).
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Rutas nombradas para pantallas compartidas (carrito, perfil).
      // Evita tener que pasar los scopes a mano al navegar.
      routes: {
        '/cart': (context) => const CartScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      // Las de auth van aparte porque necesitan ser `Route<bool>`; ver
      // [generateRoute].
      onGenerateRoute: generateRoute,
      // Sin `initialRoute`: `home` es solo la pantalla inicial; el resto se
      // resuelve por `routes` y `onGenerateRoute`.
      home: const HomeScreen(),
      // Los scopes van en el `builder` y no en `home` a proposito: asi envuelven
      // al Navigator completo y las rutas nombradas heredan el carrito y la
      // sesion.
      //
      // Si se dejaran en `home`, `/cart` y `/profile` quedarian como hermanas de
      // esa rama, fuera de los `InheritedWidget`, y `CartScope.of(context)`
      // devolveria null -> pantalla roja al abrir el carrito.
      builder: (context, child) => _AppScopeHost(child: child!),
    );
  }
}

/// Hidrata carrito, sesion y catalogo una vez y monta los scopes.
///
/// Va en el `builder` del `MaterialApp` para que abarque tambien las rutas
/// nombradas (`/cart`, `/profile`), que si no quedan fuera de los
/// `InheritedWidget`.
///
/// Mientras [loadBootstrap] resuelve se ve [BrandSplash]. El catalogo entra en
/// la misma espera, de modo que al aparecer la tienda los productos ya estan
/// cargados en vez de arrancar con un spinner.
class _AppScopeHost extends StatefulWidget {
  const _AppScopeHost({required this.child});

  final Widget child;

  @override
  State<_AppScopeHost> createState() => _AppScopeHostState();
}

class _AppScopeHostState extends State<_AppScopeHost> {
  late final Future<AppBootstrap> _bootstrap = loadBootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppBootstrap>(
      future: _bootstrap,
      builder: (context, snapshot) {
        final boot = snapshot.data;
        if (boot == null) return const BrandSplash();

        return CartScope(
          cart: boot.cart,
          child: AuthScope(
            auth: boot.auth,
            child: CatalogScope(
              catalog: boot.catalog,
              // Va dentro de `AuthScope` a proposito: `CheckoutScope` comparte el
              // cliente de la sesion, y el orden del arbol lo documenta.
              child: CheckoutScope(service: boot.checkout, child: widget.child),
            ),
          ),
        );
      },
    );
  }
}
