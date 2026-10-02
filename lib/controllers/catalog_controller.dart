import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../models/product.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';

/// Estado de carga de un recurso.
enum LoadStatus { idle, loading, refreshing, ready, error }

/// Catalogo con paginacion, busqueda y filtro por categoria.
///
/// Reemplaza al patron `FutureBuilder` + `Future` guardado en el `State`.
///
/// El problema que resuelve: `FutureBuilder` solo vuelve a pedir cuando cambia
/// la identidad del `Future`. Con un `Future` fijo creado en `initState`, un
/// `setState(() {})` no dispara nada, asi que el pull-to-refresh y el boton
/// "Reintentar" no funcionaban. Aqui la recarga es un metodo explicito que
/// ademas evita las peticiones duplicadas.
class CatalogController extends ChangeNotifier {
  CatalogController({required this.api});

  /// Cliente de red. Se inyecta para poder usar un doble en los tests.
  final ApiService api;

  // ------------------------------------------------------------------ Estado

  final List<Product> _products = [];
  final List<Category> _categories = [];

  LoadStatus _status = LoadStatus.idle;
  ApiException? _error;
  bool _canRetry = false;

  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loadingMore = false;
  String? _loadingMoreError;

  String _search = '';
  String? _categoryId;
  bool _saleOnly = false;

  /// Peticion en vuelo. Permite ignorar respuestas de requests ya descartados
  /// (por ejemplo si el usuario cambia de categoria mientras carga).
  int _requestId = 0;

  // --------------------------------------------------------------- Getters

  List<Category> get categories => List.unmodifiable(_categories);

  LoadStatus get status => _status;
  ApiException? get error => _error;
  bool get canRetry => _canRetry;

  int get page => _page;
  int get totalPages => _totalPages;
  bool get hasMore => _page < _totalPages;
  bool get isLoading => _status == LoadStatus.loading;
  bool get isEmpty => _status == LoadStatus.ready && _products.isEmpty;

  /// `true` si la lista vacia se debe a filtros, no a un catalogo vacio.
  bool get isFiltered => _search.isNotEmpty || _categoryId != null || _saleOnly;

  bool get isLoadingMore => _loadingMore;
  String? get loadingMoreError => _loadingMoreError;

  String get search => _search;
  String? get categoryId => _categoryId;
  bool get saleOnly => _saleOnly;

  /// Productos ya cargados, sin ningun filtro aplicado.
  ///
  /// Lo usa el banner de ofertas de la home y **no** puede usar [products]: ese
  /// getter ya viene filtrado, asi que con el filtro de ofertas puesto el
  /// banner contaria como ofertas justamente los productos que el filtro dejo
  /// pasar, y diria "tienes 3 ofertas" cuando el filtro esta puesto a proposito.
  /// El banner tiene que ofrecer las ofertas de verdad que hay, no el recorte
  /// que el usuario eligio.
  List<Product> get loadedProducts => List.unmodifiable(_products);

  /// Productos que se muestran, ya con el filtro de ofertas aplicado.
  ///
  /// El filtro vive en el getter y no en [_products] a proposito: [_products]
  /// guarda lo que trajo el servidor, que con el filtro puesto es la pagina
  /// entera. Ver la nota de [setSaleOnly] para por que se filtra aqui.
  List<Product> get products => List.unmodifiable(
    _saleOnly ? _products.where((p) => p.hasDiscount) : _products,
  );

  /// Total que se le ensena al usuario.
  ///
  /// Con el filtro de ofertas puesto se cuenta sobre los productos ya cargados
  /// y no sobre el `total` del servidor, porque ese cuenta el catalogo completo
  /// (2 de cuyos 5 productos no tienen descuento real). Sin esto la pantalla de
  /// ofertas decia "3 de 5" y parecian faltar productos.
  int get total => _saleOnly ? _discountedCount : _total;

  /// Cuantos de los productos cargados tienen descuento real.
  ///
  /// Se compara `oldPrice > price`, no "tiene `oldPrice`". Hay productos en el
  /// catalogo cuyo precio **subio** (un reloj a $269.000 con referencia de
  /// $219.900): su `oldPrice` no es `null`, asi que el filtro del backend
  /// (`oldPrice IS NOT NULL`) los cuenta como oferta, pero no lo son. Marcar
  /// como rebajado un producto cuyo precio subio es una mentira al consumidor, y
  /// por eso el filtro se hace aqui y no solo en el servidor.
  int get _discountedCount => _products.where((p) => p.hasDiscount).length;

  // -------------------------------------------------------------- Acciones

  /// Primera carga. No hace nada si ya se cargo.
  Future<void> load() async {
    if (_status != LoadStatus.idle) return;
    await _fetch(reset: true);
  }

  /// Vuelve a pedir todo desde cero. Es lo que ejecutan el pull-to-refresh y el
  /// boton "Reintentar".
  Future<void> refresh() async {
    await _fetch(reset: true);
  }

  /// Reintenta una carga fallida.
  Future<void> retry() async {
    if (!_canRetry) return;
    await _fetch(reset: true);
  }

  Future<void> setSearch(String query) async {
    final value = query.trim();
    if (value == _search) return;
    _search = value;
    await _fetch(reset: true);
  }

  Future<void> setCategory(String? categoryId) async {
    final value = (categoryId == null || categoryId.isEmpty)
        ? null
        : categoryId;
    if (value == _categoryId) return;
    _categoryId = value;
    await _fetch(reset: true);
  }

  /// Muestra solo los productos con descuento real.
  ///
  /// No vuelve a pedir la pagina: el filtro se aplica sobre [_products] en el
  /// getter [products]. Es exactamente igual que el de busqueda del servidor en
  /// cuanto a que se resuelve al instante, pero sin red.
  ///
  /// **Limitacion conocida:** el backend tiene un parametro `?onSale=true` que
  /// aplica `oldPrice IS NOT NULL`, y ya funciona en el codigo local, pero
  /// **no esta desplegado**: en produccion se ignora y devuelve el catalogo
  /// completo. Por eso el filtro se hace del lado del cliente. Cuando se
  /// despliegue, hay que pasar el parametro en `ApiService.fetchProducts` y
  /// quitar el `where` de aqui, porque el del servidor no distingue un
  /// descuento real de un precio que subio.
  Future<void> setSaleOnly(bool value) async {
    if (value == _saleOnly) return;
    _saleOnly = value;
    notifyListeners();
  }

  /// Trae la pagina siguiente. No hace nada si ya se llego al final o si hay
  /// una carga en curso.
  Future<void> loadMore() async {
    if (_loadingMore || !hasMore || _status != LoadStatus.ready) return;

    _loadingMore = true;
    _loadingMoreError = null;
    notifyListeners();

    final nextPage = _page + 1;
    final requestId = ++_requestId;

    try {
      final result = await api.fetchProducts(
        page: nextPage,
        search: _search,
        categoryId: _categoryId,
      );

      // La respuesta es de una peticion vieja: se descarta.
      if (requestId != _requestId) return;

      _products.addAll(result.items);
      _page = result.page;
      _totalPages = result.totalPages;
      _total = result.total;
    } on ApiException catch (e) {
      if (requestId != _requestId) return;
      // No se cae toda la lista: el error de "cargar mas" se muestra aparte.
      _loadingMoreError = e.message;
    } catch (_) {
      if (requestId != _requestId) return;
      _loadingMoreError = 'No pudimos cargar mas productos.';
    } finally {
      if (requestId == _requestId) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  // --------------------------------------------------------------- Interno

  Future<void> _fetch({required bool reset}) async {
    final requestId = ++_requestId;
    final isFirstLoad = _products.isEmpty;

    _status = isFirstLoad
        ? LoadStatus.loading
        : (reset ? LoadStatus.refreshing : _status);
    _error = null;
    notifyListeners();

    try {
      // Productos y categorias van en paralelo: son endpoints distintos y
      // ninguno depende del otro.
      final results = await Future.wait([
        api.fetchProducts(page: 1, search: _search, categoryId: _categoryId),
        if (!reset || _categories.isEmpty) api.fetchCategories(),
      ]);

      if (requestId != _requestId) return;

      final productsResult = results[0] as PaginatedResult<Product>;

      // Cuando no se pidieron categorias (porque ya las hay) se conserva la
      // lista actual. Ojo: no se devuelve `_categories` directamente como
      // fallback, porque abajo se hace `_categories..clear()..addAll(...)` y
      // `clear()` sobre la misma lista que se va a rellenar la deja vacia
      // para siempre. Eso se ve como "la tira de categorias desaparece al
      // entrar a una categoria", y ya no volvia ni refrescando. Se copia.
      final categoriesResult = results.length > 1
          ? results[1] as List<Category>
          : List<Category>.of(_categories);

      _products
        ..clear()
        ..addAll(productsResult.items);
      _page = productsResult.page;
      _totalPages = productsResult.totalPages;
      _total = productsResult.total;
      _categories
        ..clear()
        ..addAll(categoriesResult);

      _status = LoadStatus.ready;
      _error = null;
      _canRetry = false;
    } on ApiException catch (e) {
      if (requestId != _requestId) return;
      _status = LoadStatus.error;
      _error = e;
      _canRetry = e.canRetry;
    } catch (_) {
      if (requestId != _requestId) return;
      _status = LoadStatus.error;
      _error = null;
      _canRetry = true;
    } finally {
      if (requestId == _requestId) notifyListeners();
    }
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
