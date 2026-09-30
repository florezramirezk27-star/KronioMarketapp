import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              'Inicia sesión para ver tus pedidos',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El login está disponible en la web por ahora'),
                ),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acerca de'),
            subtitle: Text('Kronio Market - ecommerce construido con Flutter'),
          ),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('Versión'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}