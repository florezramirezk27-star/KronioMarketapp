import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronio_app/controllers/catalog_controller.dart';
import 'package:kronio_app/screens/home_screen.dart';
import 'package:kronio_app/services/api_service.dart';
import 'package:kronio_app/services/cart_service.dart';
import 'package:kronio_app/widgets/cart_scope.dart';

/// Backend falso con dos categorias.
///
/// Filtra de verdad por `categoryId`, igual que el backend, para que el test
/// falle si el filtro no viaja en la peticion y no solo si el estado local se
/// ensucia.
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

Future<void> _pestanaInicio(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'Inicio'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Viewport grande: `ProductGrid` es perezoso y las pestanas se montan en un
  // `TabBarView`, asi que con el tamano normal los productos de la segunda
  // pagina ni se construyen y los tests pasan sin comprobar nada.
  /// Monta [HomeScreen] con el controller dado.
  ///
  /// No hay que liberar el controller a mano: se lo paso a `HomeScreen`, que lo
  /// destruye en su `dispose` porque no vino del arbol de widgets. Liberarlo
  /// tambien desde aqui lo destrucia dos veces.
  Future<void> pumpPantalla(
    WidgetTester tester,
    CatalogController controller,
  ) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      // `CartScope` va porque el `AppBar` de `HomeScreen` trae `CartButton`, que
      // lo lee del arbol: sin el, la pantalla ni siquiera construye.
      MaterialApp(
        home: CartScope(
          cart: await CartService.load(),
          child: HomeScreen(controller: controller),
        ),
      ),
    );
  }

  group('volver al Inicio tras elegir una categoria', () {
    // Este es el sintoma que reporto el usuario: entrar en una categoria y
    // volver al inicio dejaba la lista con los productos de esa categoria.
    // La causa era que las dos pestanas comparten un `CatalogController` y el
    // filtro de categoria vive dentro de el, sin que nadie lo limpiera al
    // cambiar de pestana.
    testWidgets('el Inicio vuelve a mostrar todos los productos', (
      tester,
    ) async {
      final controller = await _cargado();
      await pumpPantalla(tester, controller);
      await tester.pumpAndSettle();

      expect(find.text('Camisa de lino'), findsOneWidget);
      expect(find.text('Lampara de mesa'), findsOneWidget);

      // Entra a una categoria tocando su burbuja en el Inicio.
      await tester.tap(find.text('Moda'));
      await tester.pumpAndSettle();

      await _pestanaInicio(tester);

      expect(find.text('Camisa de lino'), findsOneWidget);
      expect(find.text('Lampara de mesa'), findsOneWidget);
      expect(controller.categoryId, isNull);
    });

    testWidgets('elegir categoria deja la pestana Catalogo filtrada', (
      tester,
    ) async {
      // El filtro no se pierde de vista: se aplica en la pestana que si tiene
      // los chips, donde el usuario ve que esta filtrado y puede tocar
      // "Todos". En el Inicio no hay chips, asi que un filtro ahi queda sin
      // forma de quitarse.
      final controller = await _cargado();
      await pumpPantalla(tester, controller);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moda'));
      await tester.pumpAndSettle();

      expect(find.text('Camisa de lino'), findsOneWidget);
      expect(find.text('Lampara de mesa'), findsNothing);
      expect(controller.categoryId, 'c-moda');
    });

    testWidgets('volver a entrar en la categoria es volver a filtrar', (
      tester,
    ) async {
      // Decidido que el filtro es de la pestana Catalogo y no sobrevive al
      // passage por el Inicio. No es un descuido: el Inicio es "el catalogo
      // completo" por definicion, y un filtro invisible ahi solo confunde.
      // Este test fija esa decision para que no se cambie por accidente.
      final controller = await _cargado();
      await pumpPantalla(tester, controller);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moda'));
      await tester.pumpAndSettle();

      await _pestanaInicio(tester);
      await tester.tap(find.widgetWithText(Tab, 'Catalogo'));
      await tester.pumpAndSettle();

      expect(controller.categoryId, isNull);
      expect(find.text('Camisa de lino'), findsOneWidget);
      expect(find.text('Lampara de mesa'), findsOneWidget);
    });

    testWidgets('el chip Todos del catalogo sigue quitando el filtro', (
      tester,
    ) async {
      final controller = await _cargado();
      await pumpPantalla(tester, controller);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moda'));
      await tester.pumpAndSettle();

      // Coincidencia exacta a proposito: el pie de pagina dice "Todos los
      // derechos reservados" y `textContaining` lo agarra tambien. Con dos
      // coincidencias el tap es ambiguo y el finder escoge la primera.
      await tester.tap(find.text('Todos (1)'));
      await tester.pumpAndSettle();

      expect(controller.categoryId, isNull);
      expect(find.text('Camisa de lino'), findsOneWidget);
      expect(find.text('Lampara de mesa'), findsOneWidget);
    });

    testWidgets('el pull-to-refresh del Inicio no reactiva un filtro viejo', (
      tester,
    ) async {
      // El Inicio se dibuja con el filtro limpio, asi que un refresco tiene
      // que seguir pidiendo el catalogo completo. Si el filtro volviera a
      // colarse, el refresco traeria solo esa categoria.
      final controller = await _cargado();
      await pumpPantalla(tester, controller);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moda'));
      await tester.pumpAndSettle();

      await _pestanaInicio(tester);
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 320));
      await tester.pumpAndSettle();

      expect(controller.categoryId, isNull);
      expect(find.text('Camisa de lino'), findsOneWidget);
      expect(find.text('Lampara de mesa'), findsOneWidget);
    });
  });
}
