import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_logo.dart';
import '../widgets/cart_button.dart';
import '../widgets/category_chips.dart';
import '../widgets/product_grid.dart';
import 'home_tab.dart';
import 'search_screen.dart';

/// Pantalla principal con pestanas "Inicio" y "Catalogo".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogController _controller = CatalogController(api: ApiService());

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(size: 32),
              SizedBox(width: 8),
              Flexible(
                child: Text('Kronio Market', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar',
              onPressed: _openSearch,
            ),
            const CartButton(),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Mi cuenta',
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Inicio'),
              Tab(text: 'Catalogo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HomeTab(
              controller: _controller,
              onSearch: _openSearch,
              onOpenCategory: (id) => _controller.setCategory(id),
            ),
            _CatalogTab(
              controller: _controller,
              onSearch: _openSearch,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pestana de catalogo completo con filtro por categoria.
class _CatalogTab extends StatelessWidget {
  const _CatalogTab({
    required this.controller,
    required this.onSearch,
  });

  final CatalogController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchField(onTap: onSearch),
        CategoryChips(controller: controller),
        Expanded(
          child: ProductGrid(
            controller: controller,
          ),
        ),
      ],
    );
  }
}

/// Campo de busqueda decorativo que abre la pantalla de busqueda.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buscar productos...',
                  style: const TextStyle(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de error a pantalla completa, con accion de reintento.
///
/// El boton llama a [CatalogController.retry], que vuelve a pedir los datos.
/// Antes hacia `setState(() {})` sobre el mismo `Future` ya completado, asi
/// que el error se quedaba pegado para siempre.
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({super.key, required this.controller});

  final CatalogController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = controller.error;
    final message = error is ApiException
        ? error.message
        : 'Ocurrio un problema al cargar el catalogo.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error is ApiNetworkException ? Icons.wifi_off : Icons.cloud_off,
              size: 56,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.canRetry ? controller.retry : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
