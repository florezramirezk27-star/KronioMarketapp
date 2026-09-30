import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'api_exception.dart';

/// Cliente HTTP del backend de Kronio.
///
/// No se instancia de forma ad-hoc en las pantallas: se crea una vez y se
/// inyecta, para poder sustituirla por un doble en los tests y para no
/// duplicar clientes HTTP.
class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
          RegExp(r'/+$'),
          '',
        );

  final http.Client _client;

  /// `true` si este servicio creo el cliente y por lo tanto debe cerrarlo.
  final bool _ownsClient;

  final String baseUrl;

  /// Headers comunes.
  Map<String, String> get _headers => const {
        'Accept': 'application/json',
      };

  /// Libera el cliente HTTP. Solo hay que llamarlo si se creo internamente.
  void dispose() {
    if (_ownsClient) _client.close();
  }

  // ---------------------------------------------------------------- Productos

  /// Pagina de productos, con filtros opcionales.
  Future<PaginatedResult<Product>> fetchProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int? limit,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '${limit ?? AppConfig.productsPerPage}',
    };
    final trimmedSearch = search?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      query['search'] = trimmedSearch;
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query['categoryId'] = categoryId;
    }

    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: query);
    final body = await _getJson(uri);

    return PaginatedResult.fromJson(
      body,
      itemBuilder: (item) => Product.fromJson(item),
    );
  }

  /// Detalle de un producto por su slug. Lanza [ApiNotFoundException] si no existe.
  Future<Product> fetchProductBySlug(String slug) async {
    final uri = Uri.parse('$baseUrl/products/${Uri.encodeComponent(slug)}');
    final body = await _getJson(uri);
    if (body is! Map<String, dynamic>) {
      throw ApiFormatException(
        'La respuesta del producto no tiene el formato esperado.',
        uri: uri,
      );
    }
    return Product.fromJson(body);
  }

  // --------------------------------------------------------------- Categorias

  Future<List<Category>> fetchCategories() async {
    final uri = Uri.parse('$baseUrl/categories');
    final body = await _getJson(uri);

    if (body is! List) {
      throw ApiFormatException(
        'La respuesta de categorias no tiene el formato esperado.',
        uri: uri,
      );
    }

    return body
        .whereType<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList(growable: false);
  }

  // ------------------------------------------------------------------- Nucleo

  /// Hace el GET, aplica el timeout y devuelve el JSON ya decodificado.
  ///
  /// Cualquier falla se convierte en [ApiException] para que la UI nunca tenga
  /// que inspeccionar excepciones de libreria.
  Future<dynamic> _getJson(Uri uri) async {
    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiTimeoutException(
        'El servidor tardo demasiado en responder. Intenta de nuevo.',
        uri: uri,
      );
    } catch (error) {
      throw mapNetworkError(error, uri: uri);
    }

    if (response.statusCode != 200) {
      throw mapStatusCode(
        response.statusCode,
        uri: uri,
        body: response.body,
      );
    }

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiFormatException(
        'El servidor respondio con un formato que no pudimos leer.',
        uri: uri,
      );
    }
  }
}

/// Una pagina de resultados con su metadata de paginacion.
///
/// El backend responde
/// `{"items": [...], "total": N, "page": P, "limit": L, "totalPages": T}`,
/// pero tambien se acepta un array plano o la forma `{value, Count}` que usaba
/// antes, para no romperse si el contrato cambia.
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int total;

  /// `true` si hay al menos una pagina siguiente.
  bool get hasMore => page < totalPages;

  factory PaginatedResult.fromJson(
    dynamic body, {
    required T Function(Map<String, dynamic>) itemBuilder,
  }) {
    final List<dynamic> rawList;
    int page = 1;
    int totalPages = 1;
    int total = 0;
    int? totalPagesSent;

    if (body is List) {
      // Array plano: una sola pagina.
      rawList = body;
      total = body.length;
    } else if (body is Map) {
      final items = body['items'] ?? body['value'] ?? body['data'];
      if (items is! List) {
        throw ApiFormatException(
          'La respuesta del servidor no contiene la lista de productos.',
        );
      }
      rawList = items;
      page = _asInt(body['page']) ?? 1;
      total = _asInt(body['total']) ??
          _asInt(body['Count']) ??
          rawList.length;
      totalPagesSent = _asInt(body['totalPages']);
      totalPages = totalPagesSent ?? 1;
    } else {
      throw ApiFormatException(
        'Formato de respuesta inesperado del servidor de productos.',
      );
    }

    final parsed = rawList
        .whereType<Map<String, dynamic>>()
        .map(itemBuilder)
        .toList(growable: false);

    // Solo se deduce que hay mas paginas si el backend **no** informo
    // `totalPages`. Si lo informo y dice 1, se lo respeta: el catalogo puede
    // estar filtrado y la respuesta legitimately trae menos items que el total.
    if (totalPagesSent == null &&
        rawList.isNotEmpty &&
        rawList.length < total) {
      totalPages = page + 1;
    }

    return PaginatedResult(
      items: parsed,
      page: page,
      totalPages: totalPages,
      total: total,
    );
  }

  static int? _asInt(dynamic value) => switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v),
        _ => null,
      };
}
