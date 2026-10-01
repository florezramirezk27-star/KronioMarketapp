import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_scope.dart';
import 'widgets/brand_logo.dart';
import 'widgets/cart_scope.dart';

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

/// Carrito y sesion ya hidratados, listos para montar los scopes.
class _AppScopes {
  const _AppScopes({required this.cart, required this.auth});

  final CartService cart;
  final AuthController auth;
}

/// Hidrata carrito y sesion una vez y monta los scopes por encima del Navigator.
///
/// Va en el `builder` del `MaterialApp` para que abarque tambien las rutas
/// nombradas (`/cart`, `/profile`), que si no quedan fuera de los
/// `InheritedWidget`.
class _AppScopeHost extends StatefulWidget {
  const _AppScopeHost({required this.child});

  final Widget child;

  @override
  State<_AppScopeHost> createState() => _AppScopeHostState();
}

class _AppScopeHostState extends State<_AppScopeHost> {
  late final Future<_AppScopes> _scopes = _load();

  Future<_AppScopes> _load() async {
    final cart = await CartService.load();
    final auth = AuthController(service: await AuthService.create());

    // La restauracion de la sesion no bloquea el arranque: la app abre con el
    // perfil en estado "cargando" y se resuelve solo cuando termina.
    unawaited(auth.restore());

    return _AppScopes(cart: cart, auth: auth);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppScopes>(
      future: _scopes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const BrandSplash();
        }
        final scopes = snapshot.data!;
        return CartScope(
          cart: scopes.cart,
          child: AuthScope(auth: scopes.auth, child: widget.child),
        );
      },
    );
  }
}

/// Pantalla de bienvenida mientras se hidrata el carrito local.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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
