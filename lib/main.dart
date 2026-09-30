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
      // Sin `initialRoute`: la pantalla real la monta `_Root` debajo, y
      // declarar ambos a la vez hace que Flutter lance un assert.
      home: const _Root(),
    );
  }
}

/// Carga el carrito persistido y recien ahi monta el arbol principal.
///
/// Se usa un `FutureBuilder` en vez de un `StatefulWidget` porque la carga es
/// de una sola vez al arranque y no hace falta conservar estado.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CartService>(
      future: CartService.load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const BrandSplash();
        }
        return CartScope(cart: snapshot.data!, child: const HomeScreen());
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
