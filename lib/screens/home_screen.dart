import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/catalog_controller.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_header.dart';
import '../widgets/cart_button.dart';
import '../widgets/catalog_scope.dart';
import '../widgets/category_chips.dart';
import '../widgets/product_grid.dart';
import 'home_tab.dart';
import 'search_screen.dart';

/// Pantalla principal con pestanas "Inicio" y "Catalogo".
///
/// El [CatalogController] no se crea aqui: se recibe ya cargado desde el
/// arranque (ver `loadBootstrap`), asi que al abrir la app los productos estan
/// listos en vez de aparecer un spinner con el catalogo vacio.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});

  /// Solo para tests: si es `null` se usa el del arbol de widgets.
  final CatalogController? controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Controlador de las pestanas.
  ///
  /// Antes se usaba `DefaultTabController(length: 2)` con el contexto de este
  /// `State` para tocarlo. No funcionaba: el `DefaultTabController` se creaba
  /// mas abajo, en el `build`, asi que el lookup desde aqui no lo encontraba y
  /// tocar la marca no hacia nada. Con un `TabController` propio se resuelve
  /// sin depender de la posicion en el arbol, y ademas permite que el footer
  /// pida cambiar de pestana.
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  /// Controller del arbol de widgets, cacheado para poder consultarlo desde el
  /// listener de [_tabController].
  ///
  /// El getter [CatalogController.get] usa `CatalogScope.of(context)`, que
  /// llama a `dependOnInheritedWidgetOfExactType`. Eso solo es valido mientras
  /// se construye, asi que desde un listener (que corre en un `setState` del
  /// `TabController`, no en un `build`) hay que usar el valor ya resuelto.
  ///
  /// El `??=` importa: `didChangeDependencies` corre tambien cuando cambia el
  /// `MediaQuery`, y volver a pedir el scope ahi registra una dependencia
  /// fuera de un `build`.
  CatalogController? _catalogDelArbol;

  CatalogController get _catalog => widget.controller ?? _catalogDelArbol!;

  @override
  void initState() {
    super.initState();

    // Volver al Inicio tiene que quitar el filtro de categoria.
    //
    // Las dos pestanas comparten un `CatalogController`, y el filtro vive
    // dentro de el. Antes no habia nada que lo limpiara al cambiar de pestana:
    // se entraba a una categoria, se volvia al Inicio y la lista seguia
    // mostrando solo los productos de esa categoria. Y en el Inicio no hay
    // chips de categoria, asi que tampoco habia forma visible de quitarlo:
    // el usuario quedaba atrapado en un filtro que no habia pedido ahi.
    //
    // Se limpia al *llegar* al Inicio y no en `_openCatalog`, asi que da igual
    // como se llegue: tocando la pestana, deslizando, o con el logo.
    _tabController.addListener(_limpiarFiltroEnInicio);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.controller == null) {
      _catalogDelArbol ??= CatalogScope.of(context);
    }
  }

  void _limpiarFiltroEnInicio() {
    // Se usa el getter y no [_catalogDelArbol] para que tambien funcione con el
    // controller inyectado (tests). Solo toca `dependOnInheritedWidgetOfExactType`
    // si el de verdad vino del arbol, y ese ya quedo cacheado en
    // `didChangeDependencies`, que corre antes de que el usuario pueda tocar
    // nada.
    final catalog = _catalog;
    if (_tabController.index != 0) return;
    if (catalog.categoryId == null) return;

    // `setCategory(null)` ya es idempotente (si el filtro no cambio, no hace
    // nada), asi que el listener puede dispararse varias veces durante la
    // animacion de la pestana sin disparar varias peticiones.
    unawaited(catalog.setCategory(null));
  }

  @override
  void dispose() {
    _tabController.removeListener(_limpiarFiltroEnInicio);
    _tabController.dispose();
    // Solo se destruye el que esta pantalla creo. El del arbol lo destruye
    // `_AppScopeHost` cuando la app se cierra.
    widget.controller?.dispose();
    super.dispose();
  }

  /// Entra a una categoria.
  ///
  /// Aplica el filtro **y** cambia a la pestana Catalogo. Alli el filtro se ve
  /// (el chip de la categoria queda marcado) y se puede quitar tocando
  /// "Todos", que no existe en el Inicio. Entrar a una categoria desde el
  /// Inicio sin cambiar de pestana dejaba al usuario con una lista filtrada y
  /// sin ninguna seña de por que.
  void _openCategory(String categoryId) {
    unawaited(_catalog.setCategory(categoryId));
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  void _openSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  /// Vuelve al primer tab ("Inicio"), que es a donde apunta la marca.
  void _goToFirstTab() {
    BrandHeader.goHome(context);
    _tabController.animateTo(0);
  }

  /// Enlace "Catalogo" del footer: deja la app en la pestana de catalogo.
  ///
  /// `animateTo` y no `index = 1` para que se vea la transicion lateral, que es
  /// la misma que hace el usuario al tocar la pestana.
  void _openCatalog() {
    BrandHeader.goHome(context);
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Logo y nombre devuelven al inicio. En `HomeScreen` no hay nada que
        // cerrar, asi que tambien sube al primer tab: si estabas en "Catalogo"
        // y tocas la marca, vuelves a "Inicio".
        title: BrandHeader(onTap: _goToFirstTab),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Inicio'),
            Tab(text: 'Catalogo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Cada tab conserva su propio scroll y su posicion al alternar entre
          // ellas: sin esto, `TabBarView` destruye la tab que sale de pantalla
          // y al volver hay que recargarla y volver arriba del todo.
          HomeTab(
            key: const PageStorageKey('home-tab'),
            controller: _catalog,
            onSearch: _openSearch,
            onOpenCategory: _openCategory,
            onOpenCatalog: _openCatalog,
          ),
          _CatalogTab(
            key: const PageStorageKey('catalog-tab'),
            controller: _catalog,
            onSearch: _openSearch,
            onOpenCatalog: _openCatalog,
          ),
        ],
      ),
    );
  }
}

/// Pestana de catalogo completo con filtro por categoria.
///
/// Es `StatefulWidget` solo para `AutomaticKeepAliveClientMixin`: mantiene viva
/// la pestana en el `TabBarView` y con ella la posicion del scroll y las
/// categorias ya cargadas.
class _CatalogTab extends StatefulWidget {
  const _CatalogTab({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onOpenCatalog,
  });

  final CatalogController controller;
  final VoidCallback onSearch;
  final VoidCallback? onOpenCatalog;

  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchField(onTap: widget.onSearch),
        CategoryChips(controller: widget.controller),
        Expanded(
          child: ProductGrid(
            controller: widget.controller,
            onOpenCatalog: widget.onOpenCatalog,
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
