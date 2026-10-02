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

  // El filtro de ofertas del boton "Ver ofertas" del banner de la home.
  group('filtro de ofertas', () {
    // Reproduce los tres casos reales del catalogo: dos con descuento de
    // verdad, uno cuyo precio **subio** (tiene `oldPrice` pero no es una
    // rebaja). El tercero es el que importa: si el filtro se apoyara solo en
    // "tiene oldPrice", apareceria en la lista de ofertas un producto que no
    // esta rebajado, y el usuario veria "en oferta" algo que no lo esta.
    MockClient backendConDescuentos() => MockClient((request) async {
      if (request.url.path.endsWith('/categories')) {
        return http.Response(jsonEncode([]), 200);
      }

      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'rebaja',
              'name': 'Con descuento real',
              'slug': 'a',
              'price': '80000',
              'oldPrice': '100000',
              'image': '',
              'stock': 10,
            },
            {
              'id': 'subio',
              'name': 'El precio subio',
              'slug': 'b',
              'price': '269000',
              'oldPrice': '219900',
              'image': '',
              'stock': 10,
            },
          ],
          'total': 2,
          'page': 1,
          'limit': 20,
          'totalPages': 1,
        }),
        200,
      );
    });

    Future<CatalogController> conDescuentos() async {
      final controller = CatalogController(
        api: ApiService(
          client: backendConDescuentos(),
          baseUrl: 'http://localhost',
        ),
      );
      await controller.load();
      return controller;
    }

    test('sin el filtro salen todos los productos', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      expect(controller.saleOnly, isFalse);
      expect(controller.products, hasLength(2));
    });

    test('deja solo los que tienen descuento real', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      await controller.setSaleOnly(true);

      expect(controller.products, hasLength(1));
      expect(controller.products.single.name, 'Con descuento real');
    });

    // El caso de los productos cuyo precio subio. El filtro del backend
    // (`oldPrice IS NOT NULL`) los cuenta como oferta y no deberian aparecer.
    test('excluye los productos cuyo precio subio', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      await controller.setSaleOnly(true);

      expect(
        controller.products.map((p) => p.name),
        isNot(contains('El precio subio')),
      );
    });

    // Sin esto la pantalla de ofertas decia "1 de 2" y parecian faltar
    // productos: el `total` del servidor cuenta el catalogo entero.
    test(
      'el total cuenta los productos con descuento, no los del servidor',
      () async {
        final controller = await conDescuentos();
        addTearDown(controller.dispose);

        await controller.setSaleOnly(true);

        expect(controller.total, 1);
      },
    );

    test('el total vuelve a ser el del catalogo al quitar el filtro', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      await controller.setSaleOnly(true);
      await controller.setSaleOnly(false);

      expect(controller.products, hasLength(2));
      expect(controller.total, 2);
    });

    // El banner de la home necesita las ofertas reales aunque el filtro este
    // puesto. Si usara `products` (que ya viene filtrado) contaria como
    // "oferta" justamente lo que el filtro dejo pasar.
    test('loadedProducts ignora el filtro, para el banner', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      await controller.setSaleOnly(true);

      expect(controller.loadedProducts, hasLength(2));
    });

    // Un filtro sin salida visible ya dejo atrapado al usuario una vez. Sin
    // `isFiltered` la barra de aviso no se sabria cuando mostrarse.
    test('un catalogo con solo ofertas cuenta como filtrado', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      expect(controller.isFiltered, isFalse);

      await controller.setSaleOnly(true);

      expect(controller.isFiltered, isTrue);
    });

    // Idempotente: el listener de la pestana de Inicio llama en cada tick de la
    // animacion del swipe, y cada llamada suelta una notificacion.
    test('poner el filtro dos veces notifica una sola vez', () async {
      final controller = await conDescuentos();
      addTearDown(controller.dispose);

      var avisos = 0;
      controller.addListener(() => avisos++);

      await controller.setSaleOnly(true);
      await controller.setSaleOnly(true);

      expect(avisos, 1);
    });
  });
}
