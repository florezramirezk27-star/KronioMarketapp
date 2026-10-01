import 'package:flutter/material.dart';

import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'services/cart_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';
import 'widgets/cart_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KronioApp());
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
      // Rutas nombradas para pantallas compartidas (carrito, perfil). Evita
      // tener que pasar el `CartScope` a mano al navegar.
      routes: {
        '/cart': (context) => const CartScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      // Sin `initialRoute`: `home` es solo la pantalla inicial; el resto se
      // resuelve por `routes`.
      home: const HomeScreen(),
      // El `CartScope` va en el `builder` y no en `home` a proposito: asi envuelve
      // al Navigator completo y las rutas nombradas heredan el carrito.
      //
      // Si se dejara en `home`, `/cart` y `/profile` quedarian como hermanas de
      // esa rama, fuera del `InheritedWidget`, y `CartScope.of(context)`
      // devolveria null -> pantalla roja al abrir el carrito.
      builder: (context, child) => _CartScopeHost(child: child!),
    );
  }
}

/// Hidrata el carrito una vez y monta el [CartScope] por encima del Navigator.
///
/// Va en el `builder` del `MaterialApp` para que abarque tambien las rutas
/// nombradas (`/cart`, `/profile`), que si no quedan fuera del
/// `InheritedWidget` y `CartScope.of` revienta.
class _CartScopeHost extends StatefulWidget {
  const _CartScopeHost({required this.child});

  final Widget child;

  @override
  State<_CartScopeHost> createState() => _CartScopeHostState();
}

class _CartScopeHostState extends State<_CartScopeHost> {
  late final Future<CartService> _cart = CartService.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CartService>(
      future: _cart,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const BrandSplash();
        }
        return CartScope(cart: snapshot.data!, child: widget.child);
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
