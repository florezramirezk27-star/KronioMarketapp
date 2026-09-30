import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/cart_service.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          primary: const Color(0xFFEA580C), // orange-600
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF7ED), // orange-50
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Geist',
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFFEA580C),
          unselectedLabelColor: Color(0xFF6B7280),
          indicatorColor: Color(0xFFEA580C),
        ),
      ),
      home: const _Root(),
    );
  }
}

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
        return CartScope(
          cart: snapshot.data!,
          child: const HomeScreen(),
        );
      },
    );
  }
}

class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
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
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tu tienda de confianza',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFEA580C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}