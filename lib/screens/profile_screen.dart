import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/cart_scope.dart';

/// Pantalla de perfil.
///
/// Antes estaba dead code: el archivo existia pero ninguna parte de la app
/// navegaba a el. Ahora es alcanzable desde el menu lateral del AppBar.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Inicia sesion para ver tus pedidos',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // El login todavia no existe: el backend exige JWT y la pantalla
              // de autenticacion no esta implementada.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'El inicio de sesion todavia no esta disponible',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesion'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          _StatsCard(cartItems: cart.totalItems, cartSubtotal: cart.subtotal),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acerca de'),
            subtitle: Text('Kronio Market - ecommerce construido con Flutter'),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Entorno'),
            subtitle: Text(AppConfig.environment),
          ),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

/// Resumen local del carrito.
///
/// No viene del backend: muestra lo que hay guardado en este dispositivo.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.cartItems, required this.cartSubtotal});

  final int cartItems;
  final double cartSubtotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Items en carrito',
                value: formatCount(cartItems),
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.border),
            Expanded(
              child: _Stat(label: 'Subtotal', value: formatCop(cartSubtotal)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
