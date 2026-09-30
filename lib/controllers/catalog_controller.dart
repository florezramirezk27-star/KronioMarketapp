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

  /// Peticion en vuelo. Permite ignorar respuestas de requests ya descartados
  /// (por ejemplo si el usuario cambia de categoria mientras carga).
  int _requestId = 0;

  // --------------------------------------------------------------- Getters

  List<Product> get products => List.unmodifiable(_products);
  List<Category> get categories => List.unmodifiable(_categories);

  LoadStatus get status => _status;
  ApiException? get error => _error;
  bool get canRetry => _canRetry;

  int get total => _total;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get hasMore => _page < _totalPages;
  bool get isLoading => _status == LoadStatus.loading;
  bool get isEmpty => _status == LoadStatus.ready && _products.isEmpty;

  /// `true` si la lista vacia se debe a filtros, no a un catalogo vacio.
  bool get isFiltered => _search.isNotEmpty || _categoryId != null;

  bool get isLoadingMore => _loadingMore;
  String? get loadingMoreError => _loadingMoreError;

  String get search => _search;
  String? get categoryId => _categoryId;

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
      final categoriesResult = results.length > 1
          ? results[1] as List<Category>
          : _categories;

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
