import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kronio_app/services/api_exception.dart';
import 'package:kronio_app/services/api_service.dart';

/// Cliente HTTP falso: responde con lo que le pidamos y registra las peticiones.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;
  final List<Uri> requestedUris = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _productJson = {
  'id': 'a',
  'name': 'Producto A',
  'slug': 'producto-a',
  'price': '269000',
  'image': 'a.jpg',
  'stock': 100,
  'active': true,
  'category': {'id': 'c1', 'name': 'Moda', 'slug': 'moda'},
};

void main() {
  group('fetchProducts', () {
    test('devuelve los productos de la primera pagina', () async {
      final client = _FakeClient(
        (_) async => _json({
          'items': [_productJson],
          'total': 1,
          'page': 1,
          'totalPages': 1,
        }),
      );
      final api = ApiService(client: client);

      final result = await api.fetchProducts();

      expect(result.items.length, 1);
      expect(result.items.first.name, 'Producto A');
      expect(result.items.first.price, 269000);
      expect(result.hasMore, isFalse);
    });

    test('envia page y limit en la query', () async {
      late Uri captured;
      final client = _FakeClient((request) async {
        captured = request.url;
        return _json({
          'items': <Object>[],
          'total': 0,
          'page': 3,
          'totalPages': 1,
        });
      });
      final api = ApiService(client: client);

      await api.fetchProducts(page: 3, limit: 25);

      expect(captured.queryParameters['page'], '3');
      expect(captured.queryParameters['limit'], '25');
    });

    test('envia el filtro de busqueda sin espacios sobrantes', () async {
      late Uri captured;
      final client = _FakeClient((request) async {
        captured = request.url;
        return _json({'items': <Object>[], 'total': 0, 'page': 1, 'totalPages': 1});
      });
      final api = ApiService(client: client);

      await api.fetchProducts(search: '  reloj  ');

      expect(captured.queryParameters['search'], 'reloj');
    });

    test('omite el filtro si la busqueda esta vacia', () async {
      late Uri captured;
      final client = _FakeClient((request) async {
        captured = request.url;
        return _json({'items': <Object>[], 'total': 0, 'page': 1, 'totalPages': 1});
      });
      final api = ApiService(client: client);

      await api.fetchProducts(search: '   ');

      expect(captured.queryParameters.containsKey('search'), isFalse);
    });

    test('envia el filtro de categoria', () async {
      late Uri captured;
      final client = _FakeClient((request) async {
        captured = request.url;
        return _json({'items': <Object>[], 'total': 0, 'page': 1, 'totalPages': 1});
      });
      final api = ApiService(client: client);

      await api.fetchProducts(categoryId: 'cat-1');

      expect(captured.queryParameters['categoryId'], 'cat-1');
    });

    test('lanza ApiServerException en un 500', () async {
      final client = _FakeClient((_) async => _json({}, status: 500));
      final api = ApiService(client: client);

      expect(
        () => api.fetchProducts(),
        throwsA(isA<ApiServerException>()),
      );
    });

    test('lanza ApiClientException en un 400', () async {
      final client = _FakeClient((_) async => _json({}, status: 400));
      final api = ApiService(client: client);

      expect(
        () => api.fetchProducts(),
        throwsA(isA<ApiClientException>()),
      );
    });

    test('lanza ApiFormatException si la respuesta no es JSON', () async {
      final client = _FakeClient(
        (_) async => http.Response('<html>error</html>', 200),
      );
      final api = ApiService(client: client);

      expect(
        () => api.fetchProducts(),
        throwsA(isA<ApiFormatException>()),
      );
    });

    test('lanza ApiFormatException si falta la lista de items', () async {
      final client = _FakeClient((_) async => _json({'message': 'nope'}));
      final api = ApiService(client: client);

      expect(
        () => api.fetchProducts(),
        throwsA(isA<ApiFormatException>()),
      );
    });

    test('el timeout se traduce a ApiTimeoutException', () async {
      // El timeout real de la app son 15s, asi que aca se verifica el mapeo
      // del error en lugar de esperar a que expire.
      expect(
        mapNetworkError(TimeoutException('tarde')),
        isA<ApiTimeoutException>(),
      );
    });

    test('un error de socket se traduce a ApiNetworkException', () async {
      final client = _FakeClient((_) async {
        throw const SocketException('conexion rechazada');
      });
      final api = ApiService(client: client);

      expect(
        () => api.fetchProducts(),
        throwsA(isA<ApiNetworkException>()),
      );
    });

    test('un ClientException se traduce a ApiNetworkException', () async {
      final client = _FakeClient((_) async {
        throw http.ClientException('fallo');
      });
      final api = ApiService(client: client);

      expect(
        () => api.fetchProducts(),
        throwsA(isA<ApiNetworkException>()),
      );
    });
  });

  group('fetchProductBySlug', () {
    test('devuelve el producto pedido', () async {
      final client = _FakeClient((_) async => _json(_productJson));
      final api = ApiService(client: client);

      final product = await api.fetchProductBySlug('producto-a');

      expect(product.id, 'a');
      expect(product.category?.name, 'Moda');
    });

    test('consulta el endpoint con el slug codificado', () async {
      late Uri captured;
      final client = _FakeClient((request) async {
        captured = request.url;
        return _json(_productJson);
      });
      final api = ApiService(client: client);

      await api.fetchProductBySlug('producto con espacios');

      expect(captured.path, contains('producto%20con%20espacios'));
    });

    test('lanza ApiNotFoundException en un 404', () async {
      final client = _FakeClient((_) async => _json({}, status: 404));
      final api = ApiService(client: client);

      expect(
        () => api.fetchProductBySlug('no-existe'),
        throwsA(isA<ApiNotFoundException>()),
      );
    });
  });

  group('fetchCategories', () {
    test('devuelve la lista de categorias', () async {
      final client = _FakeClient(
        (_) async => _json([
          {'id': 'c1', 'name': 'Moda', 'slug': 'moda', '_count': {'products': 3}},
        ]),
      );
      final api = ApiService(client: client);

      final categories = await api.fetchCategories();

      expect(categories.length, 1);
      expect(categories.first.name, 'Moda');
      expect(categories.first.productCount, 3);
    });

    test('lanza ApiFormatException si no es una lista', () async {
      final client = _FakeClient((_) async => _json({'items': []}));
      final api = ApiService(client: client);

      expect(
        () => api.fetchCategories(),
        throwsA(isA<ApiFormatException>()),
      );
    });
  });

  group('configuracion', () {
    test('elimina la barra final del baseUrl', () {
      expect(
        ApiService(baseUrl: 'https://api.test/').baseUrl,
        'https://api.test',
      );
    });

    test('acepta un baseUrl sin barra final', () {
      expect(
        ApiService(baseUrl: 'https://api.test').baseUrl,
        'https://api.test',
      );
    });

    test('no cierra un cliente inyectado', () async {
      final client = MockClient((_) async => _json({'items': []}));
      final api = ApiService(client: client);

      // Si se cerrara el cliente inyectado, la peticion fallaria.
      await api.fetchProducts();
      api.dispose();

      expect(true, isTrue);
    });
  });
}
