import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kronio_app/controllers/catalog_controller.dart';
import 'package:kronio_app/services/api_service.dart';

/// Backend falso con dos categorias y dos productos.
MockClient _backend() => MockClient((request) async {
  if (request.url.path.endsWith('/categories')) {
    return http.Response(
      jsonEncode([
        {
          'id': 'c-moda',
          'name': 'Moda',
          'slug': 'moda',
          '_count': {'products': 1},
        },
        {
          'id': 'c-hogar',
          'name': 'Hogar',
          'slug': 'hogar',
          '_count': {'products': 1},
        },
      ]),
      200,
    );
  }

  final categoryId = request.url.queryParameters['categoryId'];
  final names = switch (categoryId) {
    'c-moda' => ['Camisa de lino'],
    'c-hogar' => ['Lampara de mesa'],
    _ => ['Camisa de lino', 'Lampara de mesa'],
  };

  return http.Response(
    jsonEncode({
      'items': [
        for (var i = 0; i < names.length; i++)
          {
            'id': 'p$i',
            'name': names[i],
            'slug': 'producto-$i',
            'price': '1000',
            'image': '',
            'stock': 10,
          },
      ],
      'total': names.length,
      'page': 1,
      'limit': 20,
      'totalPages': 1,
    }),
    200,
  );
});

Future<CatalogController> _cargado() async {
  final controller = CatalogController(
    api: ApiService(client: _backend(), baseUrl: 'http://localhost'),
  );
  await controller.load();
  return controller;
}

void main() {
  // Este bug era invisible en la UI y no lo causaba el filtro: era el
  // controller vaciando su propia lista de categorias al filtrar. Se pierdeian
  // las etiquetas *para siempre* (no solo durante la peticion), asi que ni
  // volver al Inicio las recuperaba: la tira de categorias no volvia a
  // aparecer en lo que resta de la sesion.
  group('la lista de categorias sobrevive a los filtros', () {
    test('no se borra al cambiar de categoria', () async {
      final controller = await _cargado();
      addTearDown(controller.dispose);

      expect(controller.categories, hasLength(2));

      await controller.setCategory('c-moda');

      expect(controller.categories, hasLength(2));
      expect(
        controller.categories.map((c) => c.id),
        containsAll(<String>['c-moda', 'c-hogar']),
      );
    });

    test('no se borra al volver a quitar el filtro', () async {
      final controller = await _cargado();
      addTearDown(controller.dispose);

      await controller.setCategory('c-moda');
      await controller.setCategory(null);

      expect(controller.categories, hasLength(2));
    });

    test('no se borra tras varias alternencias de filtro', () async {
      // El fallo era acumulativo: la primera vez se vaciaba y las siguientes
      // ya no tenian nada que vaciar, asi que el sintoma (categorias
      // desaparecidas) era permanente aunque el usuario siguiera tocando
      // filtros.
      final controller = await _cargado();
      addTearDown(controller.dispose);

      for (final id in <String?>['c-moda', 'c-hogar', null, 'c-moda', null]) {
        await controller.setCategory(id);
        expect(
          controller.categories,
          hasLength(2),
          reason: 'las categorias desaparecieron al filtrar por $id',
        );
      }
    });

    test('conserva el conteo de cada categoria', () async {
      // Sin esto la UI no puede decidir que categorias mostrar: `HomeTab` y
      // `CategoryChips` ocultan las que tienen `productCount == 0`, asi que un
      // conteo a cero las haria desaparecer de nuevo.
      final controller = await _cargado();
      addTearDown(controller.dispose);

      await controller.setCategory('c-moda');

      expect(controller.categories.map((c) => c.productCount), everyElement(1));
    });

    test('un refresh vuelve a pedir las categorias', () async {
      // El refresh, unlike el cambio de filtro, pide las dos cosas. Se comprueba
      // que el resultado nuevo replaces la lista en vez de acumularse.
      final controller = await _cargado();
      addTearDown(controller.dispose);

      await controller.refresh();

      expect(controller.categories, hasLength(2));
      expect(controller.products, hasLength(2));
    });
  });
}
