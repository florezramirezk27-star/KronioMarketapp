import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/auth_scope.dart';
import '../widgets/cart_scope.dart';

/// Pantalla de perfil.
///
/// Muestra la cuenta real cuando hay sesion iniciada. El login del backend es
/// por cookie, asi que la sesion sobrevive a los reinicios y la pantalla la
/// resuelve el [AuthController] al arrancar.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final auth = AuthScope.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Mi cuenta'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AccountSection(auth: auth),
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
          // La version se lee del APK instalado en vez de escribir '1.0.0' a
          // mano, que era un valor fijo que mentia en cuanto se publicaba una
          // actualizacion. Si `package_info_plus` no responde (tests, web) se
          // muestra "desconocida" en vez de fallar la pantalla.
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('Version'),
                subtitle: Text(
                  info == null
                      ? 'desconocida'
                      : '${info.version} (${info.buildNumber})',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Avatar y acciones de la cuenta, segun el estado de la sesion.
class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.auth});

  final AuthController auth;

  Future<void> _openLogin(BuildContext context) async {
    auth.clearError();
    await Navigator.of(context).pushNamed<bool>('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (auth.isUnknown) {
      return const Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
          Text(
            'Cargando tu cuenta...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    final user = auth.user;
    if (user == null) {
      return Column(
        children: [
          const CircleAvatar(
            radius: 40,
            child: Icon(Icons.person_outline, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inicia sesion para ver tus pedidos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openLogin(context),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesion'),
            ),
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            user.initials,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: 8),
          const Chip(label: Text('Administrador')),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: auth.isBusy ? null : () => auth.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ),
      ],
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
