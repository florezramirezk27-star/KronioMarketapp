import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/catalog_controller.dart';
import '../widgets/brand_header.dart';
import '../widgets/catalog_scope.dart';
import '../widgets/category_chips.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/product_grid.dart';
import '../widgets/sale_filter_bar.dart';
import '../widgets/search_field.dart';
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

  /// Destino marcado en la barra inferior: 0 Inicio, 1 Catalogo, 2 Carrito,
  /// 3 Perfil.
  ///
  /// No es lo mismo que [_tabController.index]: el Carrito y el Perfil no son
  /// pestanas, se empujan encima. Por eso hace falta un indice aparte que
  /// tambien los cubre. Si se usara el indice de las pestanas, tocar "Carrito"
  /// dejaria "Inicio" marcado abajo mientras se mira el carrito, que es
  /// justo la confusion que hace una barra inferior inutil.
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();

    // Volver al Inicio tiene que quitar los filtros.
    //
    // Las dos pestanas comparten un `CatalogController`, y los filtros viven
    // dentro de el. Antes no habia nada que los limpiara al cambiar de
    // pestana: se entraba a una categoria, se volvia al Inicio y la lista
    // seguia mostrando solo los productos de esa categoria. Y en el Inicio no
    // hay chips de categoria, asi que tampoco habia forma visible de quitarlo:
    // el usuario quedaba atrapado en un filtro que no habia pedido ahi.
    //
    // Se limpia al *llegar* al Inicio y no en `_openCatalog`, asi que da igual
    // como se llegue: tocando la pestana, deslizando, o con el logo.
    _tabController.addListener(_limpiarFiltroEnInicio);
    _tabController.addListener(_sincronizarBarraInferior);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.controller == null) {
      _catalogDelArbol ??= CatalogScope.of(context);
    }
  }

  /// Al deslizar entre pestanas, la barra tiene que seguir al usuario.
  void _sincronizarBarraInferior() {
    final fromTab = _tabController.index;
    if (fromTab > 1) return;
    if (_navIndex == fromTab) return;
    setState(() => _navIndex = fromTab);
  }

  void _limpiarFiltroEnInicio() {
    // Se usa el getter y no [_catalogDelArbol] para que tambien funcione con el
    // controller inyectado (tests). Solo toca `dependOnInheritedWidgetOfExactType`
    // si el de verdad vino del arbol, y ese ya quedo cacheado en
    // `didChangeDependencies`, que corre antes de que el usuario pueda tocar
    // nada.
    final catalog = _catalog;
    if (_tabController.index != 0) return;

    // `setCategory` y `setSaleOnly` ya son idempotentes, asi que llamarlas
    // varias veces durante la animacion de la pestana no dispara peticiones de
    // mas. Van sin `await` a proposito: el listener corre en cada tick de la
    // animacion del swipe, y esperar aqui bloquearia el listener.
    if (catalog.categoryId != null) {
      unawaited(catalog.setCategory(null));
    }

    // El filtro de ofertas se limpia tambien. El Inicio es el catalogo
    // completo por definicion, igual que con las categorias: si no, el banner
    // de ofertas y la lista harian cosas distintas y el usuario no tendria
    // forma de volver a ver el catalogo entero sin irse a la otra pestana.
    if (catalog.saleOnly) {
      unawaited(catalog.setSaleOnly(false));
    }
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

  /// Boton "Ver ofertas" del banner de la home.
  ///
  /// Pone el filtro de ofertas y salta al catalogo. Sin esto el boton seria una
  /// promesa sin destino: llevaria al catalogo completo y el usuario no veria
  /// las ofertas que el banner le acaba de prometer.
  void _openOffers() {
    BrandHeader.goHome(context);
    unawaited(_catalog.setSaleOnly(true));
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  /// Destino tocado en la barra inferior.
  ///
  /// Inicio y Catalogo son las pestanas; Carrito y Perfil se empujan encima y
  /// al volver la barra tiene que seguir marking la pestana de la que se salio,
  /// asi que el indice se queda en el ultimo destino de pestana.
  void _selectDestination(int index) {
    switch (index) {
      case 0:
        BrandHeader.goHome(context);
        if (_tabController.index != 0) _tabController.animateTo(0);

      case 1:
        _openCatalog();

      case 2:
        setState(() => _navIndex = 2);
        Navigator.of(context).pushNamed('/cart');

      case 3:
        setState(() => _navIndex = 3);
        Navigator.of(context).pushNamed('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tabController.index == 1) {
          // En Catalogo: back hardware va a Inicio, no sale de la app
          _tabController.animateTo(0);
        } else {
          // En Inicio: salir de la app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // Logo y nombre devuelven al inicio. En `HomeScreen` no hay nada que
          // cerrar, asi que tambien sube al primer tab: si estabas en "Catalogo"
          // y tocas la marca, vuelves a "Inicio".
          title: BrandHeader(onTap: _goToFirstTab),
          // Solo la busqueda. El carrito y el perfil pasaron a la barra inferior:
          // repetirlos aqui seria mostrar el mismo destino dos veces, y con tres
          // botones de accion el nombre de la marca se aprieta (ya se veia).
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar',
              onPressed: _openSearch,
            ),
            const SizedBox(width: 4),
          ],
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
              onOpenOffers: _openOffers,
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
        bottomNavigationBar: HomeBottomNav(
          currentIndex: _navIndex,
          onSelect: _selectDestination,
        ),
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
    // El TabBarView mantiene viva esta pestana, pero si el controller cambia
    // (p. ej. filtro de ofertas) el contenido tiene que reconstruirse. Usamos
    // AnimatedBuilder para escuchar al controller directamente.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchField(onTap: widget.onSearch),
            ),
            CategoryChips(controller: widget.controller),
            SaleFilterBar(controller: widget.controller),
            Expanded(
              child: ProductGrid(
                controller: widget.controller,
                onOpenCatalog: widget.onOpenCatalog,
              ),
            ),
          ],
        );
      },
    );
  }
}
