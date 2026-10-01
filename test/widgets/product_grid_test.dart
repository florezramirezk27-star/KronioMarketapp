import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kronio_app/controllers/catalog_controller.dart';
import 'package:kronio_app/services/api_service.dart';
import 'package:kronio_app/widgets/product_grid.dart';

/// Backend falso que sirve una sola pagina de [productCount] productos.
MockClient _backend({int productCount = 3}) => MockClient((request) async {
  if (request.url.path.endsWith('/categories')) {
    return http.Response('[]', 200);
  }

  return http.Response(
    jsonEncode({
      'items': [
        for (var i = 0; i < productCount; i++)
          {
            'id': 'p$i',
            'name': 'Producto $i',
            'slug': 'producto-$i',
            'price': '1000',
            'image': '',
            'stock': 10,
          },
      ],
      'total': productCount,
      'page': 1,
      'limit': 20,
      'totalPages': 1,
    }),
    200,
  );
});

Future<CatalogController> _loadedController({int productCount = 3}) async {
  final controller = CatalogController(
    api: ApiService(
      client: _backend(productCount: productCount),
      baseUrl: 'http://localhost',
    ),
  );
  await controller.load();
  return controller;
}

Widget _app(CatalogController controller, {Widget? header}) {
  return MaterialApp(
    home: Scaffold(
      body: ProductGrid(controller: controller, header: header),
    ),
  );
}

void main() {
  group('ProductGrid', () {
    testWidgets('con header renderiza el header y todos los productos', (
      tester,
    ) async {
      final controller = await _loadedController(productCount: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, header: const Text('HEADER')));
      await tester.pumpAndSettle();

      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('Producto 0'), findsOneWidget);
      expect(find.text('Producto 2'), findsOneWidget);
    });

    // El header ya se renderiza como sliver propio; si tambien se suma al
    // `childCount` del grid, la ultima celda intenta leer products[n] y revienta
    // con RangeError al hacer scroll.
    testWidgets('el header no cuenta como producto en el grid', (tester) async {
      final controller = await _loadedController(productCount: 2);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, header: const Text('HEADER')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('sin header renderiza los productos sin fallar', (
      tester,
    ) async {
      final controller = await _loadedController(productCount: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.text('Producto 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un catalogo vacio con header no falla', (tester) async {
      final controller = await _loadedController(productCount: 0);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, header: const Text('HEADER')));
      await tester.pumpAndSettle();

      expect(find.text('HEADER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
