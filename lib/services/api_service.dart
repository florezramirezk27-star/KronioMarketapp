import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'api_exception.dart';
import 'cookie_jar.dart';

/// Cliente HTTP del backend de Kronio.
///
/// No se instancia de forma ad-hoc en las pantallas: se crea una vez y se
/// inyecta, para poder sustituirla por un doble en los tests y para no
/// duplicar clientes HTTP.
///
/// Ademas de GET, sabe hacer POST con la sesion por cookies del backend:
///  - reenvia las cookies guardadas en el [cookieJar],
///  - antes de un POST consigue la cookie CSRF si no la tiene,
///  - manda `X-CSRF-Token` en los metodos que no son GET/HEAD/OPTIONS,
///  - si recibe 401, intenta refrescar la sesion una vez y reintenta.
class ApiService {
  ApiService({
    http.Client? client,
    String? baseUrl,
    CookieJar? cookieJar,
    this.onCookiesChanged,
    this.onUnauthorized,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       cookieJar = cookieJar ?? CookieJar(),
       baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
         RegExp(r'/+$'),
         '',
       );

  final http.Client _client;

  /// `true` si este servicio creo el cliente y por lo tanto debe cerrarlo.
  final bool _ownsClient;

  final String baseUrl;

  /// Cookies de sesion y CSRF. Se comparte con quien persista la sesion.
  final CookieJar cookieJar;

  /// Se llama despues de cada respuesta que trajo cookies, para persistirlas.
  final Future<void> Function()? onCookiesChanged;

  /// Intenta renovar la sesion. Devuelve `true` si quedo renovada y conviene
  /// reintentar la peticion original.
  final Future<bool> Function()? onUnauthorized;

  /// Nombres que usa el backend para la cookie CSRF. El prefijo `__Host-` es el
  /// de produccion (exige Secure y Path=/); el otro es de desarrollo.
  static const csrfCookieNames = ['__Host-csrf-token', 'csrf-token'];

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
    final body = await _send(method: 'GET', uri: uri);

    return PaginatedResult.fromJson(
      body,
      itemBuilder: (item) => Product.fromJson(item),
    );
  }

  /// Detalle de un producto por su slug. Lanza [ApiNotFoundException] si no existe.
  Future<Product> fetchProductBySlug(String slug) async {
    final uri = Uri.parse('$baseUrl/products/${Uri.encodeComponent(slug)}');
    final body = await _send(method: 'GET', uri: uri);
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
    final body = await _send(method: 'GET', uri: uri);

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

  /// GET que devuelve el JSON ya decodificado.
  Future<dynamic> getJson(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _send(method: 'GET', uri: uri);
  }

  /// POST JSON. Es el que usan auth y, mas adelante, el checkout.
  ///
  /// [allowRefresh] se apaga para login, registro y refresh: ahi un 401
  /// significa "credenciales malas" o "no hay sesion", no "sesion vencida", y
  /// reintentar con un refresh seria un bucle.
  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool allowRefresh = true,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      method: 'POST',
      uri: uri,
      body: body,
      allowRefresh: allowRefresh,
    );
  }

  /// Hace la peticion, aplica el timeout y devuelve el JSON ya decodificado.
  ///
  /// Cualquier falla se convierte en [ApiException] para que la UI nunca tenga
  /// que inspeccionar excepciones de libreria.
  Future<dynamic> _send({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
    bool isRetry = false,
    bool allowRefresh = true,
  }) async {
    final isUnsafe = !const {'GET', 'HEAD', 'OPTIONS'}.contains(method);

    // El backend exige CSRF en los metodos que mutan. La cookie se obtiene con
    // un GET a /auth, que es lo que hace tambien el frontend web.
    if (isUnsafe && _csrfToken() == null) {
      await _primeCsrfToken();
    }

    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';

    final cookieHeader = cookieJar.headerFor(uri);
    if (cookieHeader != null) headers['Cookie'] = cookieHeader;

    if (isUnsafe) {
      final csrf = _csrfToken();
      if (csrf != null) headers['X-CSRF-Token'] = csrf;
    }

    late final http.Response response;
    try {
      response = await _dispatch(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiTimeoutException(
        'El servidor tardo demasiado en responder. Intenta de nuevo.',
        uri: uri,
      );
    } catch (error) {
      throw mapNetworkError(error, uri: uri);
    }

    await _absorbCookies(uri, response);

    if (response.statusCode == 401 &&
        allowRefresh &&
        !isRetry &&
        onUnauthorized != null) {
      final refreshed = await onUnauthorized!();
      if (refreshed) {
        return _send(
          method: method,
          uri: uri,
          body: body,
          isRetry: true,
          allowRefresh: false,
        );
      }
    }

    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw mapStatusCode(status, uri: uri, body: response.body);
    }

    // 204 y respuestas sin cuerpo (por ejemplo el logout) no tienen JSON.
    if (response.bodyBytes.isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiFormatException(
        'El servidor respondio con un formato que no pudimos leer.',
        uri: uri,
      );
    }
  }

  Future<http.Response> _dispatch({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) {
    switch (method) {
      case 'POST':
        return _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      case 'GET':
      default:
        return _client.get(uri, headers: headers);
    }
  }

  /// Pide un CSRF nuevo con `GET /auth`, que es como el backend lo emite.
  ///
  /// Si falla no se propaga: el POST que sigue fallara con el mensaje del
  /// servidor, que es mas util que un error de este paso intermedio.
  Future<void> _primeCsrfToken() async {
    try {
      await _send(
        method: 'GET',
        uri: Uri.parse('$baseUrl/auth'),
        allowRefresh: false,
        isRetry: true, // evita cualquier recursion
      );
    } on ApiException {
      // Se ignora a proposito; ver comentario de arriba.
    }
  }

  String? _csrfToken() {
    for (final name in csrfCookieNames) {
      final value = cookieJar.valueOf(name);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _absorbCookies(Uri uri, http.Response response) async {
    final setCookies = <String>[];
    response.headers.forEach((key, value) {
      if (key.toLowerCase() == 'set-cookie') setCookies.add(value);
    });
    if (setCookies.isEmpty) return;

    cookieJar.absorb(uri, setCookies);
    await onCookiesChanged?.call();
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
      total = _asInt(body['total']) ?? _asInt(body['Count']) ?? rawList.length;
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
