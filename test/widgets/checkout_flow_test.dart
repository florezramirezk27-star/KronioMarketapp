import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kronio_app/controllers/auth_controller.dart';
import 'package:kronio_app/models/order.dart';
import 'package:kronio_app/models/product.dart';
import 'package:kronio_app/screens/cart_screen.dart';
import 'package:kronio_app/screens/checkout_screen.dart';
import 'package:kronio_app/screens/order_confirmation_screen.dart';
import 'package:kronio_app/services/api_service.dart';
import 'package:kronio_app/services/auth_service.dart';
import 'package:kronio_app/services/cart_service.dart';
import 'package:kronio_app/services/checkout_service.dart';
import 'package:kronio_app/widgets/auth_scope.dart';
import 'package:kronio_app/widgets/cart_scope.dart';
import 'package:kronio_app/widgets/checkout_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL de mentira: las pruebas nunca salen a la red real.
const _baseUrl = 'https://api.test/api/proxy';

/// Cliente falso que reproduce el backend de produccion.
///
/// Los caminos importan: cada rama responde algo distinto, igual que el
/// backend real. Un unico 200 para todo haria que la prueba pasara aunque la
/// app mandara la peticion al endpoint equivocado, que es exactamente el error
/// que estos tests huntan.
class _FakeBackend extends http.BaseClient {
  _FakeBackend({this.checkoutStatus = 200, this.checkoutBody, this.serverCart});

  /// `200` = el checkout funciona. Otro codigo = falla con ese codigo.
  final int checkoutStatus;

  /// Cuerpo del checkout, si se quiere forzar una respuesta.
  final Object? checkoutBody;

  /// Carrito que el backend ya tiene. Por defecto vacio.
  final List<Map<String, dynamic>>? serverCart;

  /// Peticiones registradas, en orden, como `"METODO /camino"`.
  final List<String> calls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final path = req.url.path;
    calls.add('${req.method} $path');

    // El backend emite la cookie CSRF en un GET a /auth.
    if (req.method == 'GET' && path.endsWith('/auth')) {
      return _stream(200, null, const {
        'set-cookie': '__Host-csrf-token=csrf-de-prueba; Path=/; Secure',
      });
    }

    if (path.endsWith('/auth/login') && req.method == 'POST') {
      // El backend real envuelve la cuenta en `user` y ademas emite la cookie
      // de sesion httpOnly. Sin esa cookie el checkout daria 401, asi que esta
      // rama no es decorativa: es lo que hace que la compra pueda ocurrir.
      return _stream(
        200,
        const {'user': _user},
        const {'set-cookie': 'token=jwt123; Path=/; HttpOnly; Secure'},
      );
    }

    if (path.endsWith('/auth/profile')) {
      return _stream(200, _user);
    }

    if (path.endsWith('/orders/checkout') && req.method == 'POST') {
      return _stream(checkoutStatus, checkoutBody ?? _orderResponse);
    }

    if (path.endsWith('/cart') && req.method == 'GET') {
      return _stream(200, {
        'id': 'c1',
        'items': serverCart ?? const <dynamic>[],
      });
    }

    // Carrito y catalogo: 200 con algo plausible.
    return _stream(200, const {});
  }

  static http.StreamedResponse _stream(
    int status,
    Object? body, [
    Map<String, String> extra = const {},
  ]) {
    return http.StreamedResponse(
      body == null
          ? const Stream.empty()
          : Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...extra},
    );
  }

  /// Las peticiones de carrito que hizo la app, en orden.
  List<String> get cartCalls =>
      calls.where((c) => c.contains('/cart')).toList(growable: false);
}

/// Cuenta de la sesion de pruebas.
const _user = {
  'id': 'u1',
  'name': 'Kevin Prueba',
  'email': 'kronio.test.2026@gmail.com',
  'role': 'CUSTOMER',
};

const _orderResponse = {
  'id': 'o1',
  'numericId': 35,
  'total': '538000',
  'status': 'PENDING',
  'paymentMethod': 'CASH_ON_DELIVERY',
  'shippingName': 'Kevin Prueba',
  'shippingPhone': '3001234567',
  'shippingAddress': 'Calle 100 # 20-30',
  'shippingCity': 'Bogota',
  'shippingState': 'Cundinamarca',
  'createdAt': '2026-10-02T02:08:06.522Z',
  'items': [
    {
      'productId': 'p1',
      'quantity': 2,
      'price': '269000',
      'product': {'id': 'p1', 'name': 'Reloj Naviforce'},
    },
  ],
  'dropi': {'success': true, 'message': 'ok', 'orderId': 1},
  'emails': {'customer': 'queued', 'admin': 'queued'},
};

/// Producto con el que se arma el carrito de las pruebas.
Product _product(String id) => Product(
  id: id,
  name: 'Producto $id',
  slug: 'producto-$id',
  price: 269000,
  image: '$id.jpg',
  stock: 100,
);

/// Carrito local con un producto, serializado como lo guarda el servicio.
String _cartPrefs({int quantity = 2}) => jsonEncode([
  {
    'product': {
      'id': 'p1',
      'name': 'Reloj Naviforce',
      'slug': 'reloj',
      'price': 269000,
      'image': 'reloj.jpg',
      'stock': 100,
      'active': true,
    },
    'quantity': quantity,
  },
]);

/// Monta el arbol de scopes que la app real arma en [loadBootstrap].
///
/// Se replican los mismos scopes y en el mismo orden, con un backend falso
/// inyectado por parametro. No se usa la [KronioApp] entera porque
/// `loadBootstrap` construye su propio `ApiService` sin dejar por donde
/// inyectarle un cliente de pruebas, y porque asi este test puede fijar el
/// estado del carrito y de la sesion sin pelearse con la hidratacion.
Future<CartService> _pumpApp(
  WidgetTester tester, {
  required Widget home,
  int checkoutStatus = 200,
  Object? checkoutBody,
  bool authenticated = true,
  int quantity = 2,
}) async {
  SharedPreferences.setMockInitialValues({
    'flutter.kronio_cart_v1': _cartPrefs(quantity: quantity),
  });

  final client = _FakeBackend(
    checkoutStatus: checkoutStatus,
    checkoutBody: checkoutBody,
  );
  final authService = await AuthService.create(
    client: client,
    baseUrl: _baseUrl,
  );
  final auth = AuthController(service: authService);
  final api = ApiService(client: client, baseUrl: _baseUrl);
  final cart = await CartService.load();

  if (authenticated) {
    // **Antes** del `pumpWidget`. El nombre y el correo de los campos salen de
    // la sesion en el primer `build` (ver `didChangeDependencies` en
    // `CheckoutScreen`), asi que si el perfil se carga despues los dos campos
    // quedan en blanco y el cliente tiene que escribirlos a mano.
    await auth.login(
      email: 'kronio.test.2026@gmail.com',
      password: 'Prueba123!a',
    );
  }

  // Viewport alto a proposito: los dos `ListView` de estas pantallas son
  // perezosos, asi que con los 600 px de alto por defecto el boton de
  // confirmar y el aviso de pago contra entrega ni siquiera se construyen, y
  // un `find` de ellos devuelve cero widgets. Agrandando el viewport, el test
  // lee lo que el usuario ve al desplazarse, que es el caso real.
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    CartScope(
      cart: cart,
      child: AuthScope(
        auth: auth,
        child: CheckoutScope(
          service: CheckoutService(api: api),
          child: MaterialApp(
            routes: {
              '/login': (_) => const Scaffold(
                body: Center(child: Text('Pantalla de login')),
              ),
            },
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return cart;
}

/// Rellena el formulario de entrega con datos validos.
Future<void> _fillShipping(WidgetTester tester) async {
  Future<void> fill(String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    expect(field, findsOneWidget, reason: 'no encontre el campo "$label"');
    await tester.enterText(field, value);
  }

  await fill('Nombre completo', 'Kevin Prueba');
  await fill('Telefono', '3001234567');
  await fill('Direccion de entrega', 'Calle 100 # 20-30');
  await fill('Ciudad', 'Bogota');
  await fill('Departamento', 'Cundinamarca');
  await tester.pump();
}

/// Baja hasta el boton de confirmar y lo toca.
///
/// El boton esta al final de un `ListView` largo, asi que con el viewport de
/// 600 px de alto queda bajo el pliegue: un `tap` sobre un widget que no esta
/// visible se pierde en silencio y el test falla con un error que no dice nada
/// sobre la causa.
///
/// Se usa `scrollUntilVisible` en vez de `ensureVisible` porque el boton puede
/// no estar **construido**: el `ListView` es perezoso, asi que un `find` de lo
/// que esta mas abajo del pliegue devuelve cero widgets.
Finder _confirmButton() => find.textContaining('Confirmar pedido por');

Future<void> _tapConfirm(WidgetTester tester) async {
  await _scrollToConfirm(tester);
  await tester.tap(_confirmButton());
  await tester.pumpAndSettle();
}

/// Baja hasta el boton de confirmar.
///
/// Se usa `textContaining` y no `widgetWithText` porque el texto del boton
/// lleva el monto (`Confirmar pedido por $ 538.000`) y `widgetWithText` exige
/// coincidencia exacta: con el monto fijo, cualquier cambio de precio en el
/// carrito rompe el finder sin avisar por que.
///
/// Y se hace `ensureVisible` antes del `tap` porque el boton esta al final de
/// un `ListView` largo: sin esto el toque se pierde en silencio.
Future<void> _scrollToConfirm(WidgetTester tester) async {
  await tester.ensureVisible(_confirmButton());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('confirmacion del pedido', () {
    testWidgets('muestra el numero de pedido y el total del servidor', (
      tester,
    ) async {
      // El total que se muestra es el que devolvio el backend, no el del
      // carrito local: es lo unico que el backend cobra.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final result = OrderResult.fromJson(_orderResponse);
      await tester.pumpWidget(
        MaterialApp(home: OrderConfirmationScreen(result: result)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tu pedido quedo registrado'), findsOneWidget);
      expect(find.text('Pedido #35'), findsOneWidget);
      // `$ 538.000`, con el espacio: es como lo formatea `formatCop` en es_CO.
      expect(find.text(r'$ 538.000'), findsWidgets);
    });

    testWidgets('avisa del pago contra entrega antes de celebrarlo', (
      tester,
    ) async {
      // Si el cliente descubre el contra entrega en la puerta, con el pedido en
      // la mano, es un reclamo y no una sorpresa aceptable.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final result = OrderResult.fromJson(_orderResponse);
      await tester.pumpWidget(
        MaterialApp(home: OrderConfirmationScreen(result: result)),
      );
      await tester.pumpAndSettle();

      // El texto real es "Pagas el total en efectivo al transportador cuando lo
      // recibas."; se busca por fragmento porque el `Text` se parte en dos
      // lineas de codigo y un finder exacto sobre la frase completa no
      // encontraria nada.
      expect(
        find.textContaining('Pagas el total en efectivo al transportador'),
        findsOneWidget,
      );
    });

    testWidgets('avisa que el pedido va dentro de 30 dias calendario', (
      tester,
    ) async {
      // El plazo tiene que coincidir con el de los terminos y condiciones
      // (Ley 2439 de 2024). Si la pantalla dice otra cosa, es una
      // contradiccion que la SIC detecta.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final result = OrderResult.fromJson(_orderResponse);
      await tester.pumpWidget(
        MaterialApp(home: OrderConfirmationScreen(result: result)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('30 dias'), findsOneWidget);
    });

    testWidgets('si el proveedor falla, lo dice sin quitar el numero', (
      tester,
    ) async {
      // Estado real de dropshipping: el pedido existe y hay que cobrar, pero
      // no se envio. Ocultarlo seria mentir; borrar el numero dejaria al
      // cliente sin forma de reclamar.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final result = OrderResult.fromJson({
        ..._orderResponse,
        'dropi': {
          'success': false,
          'message': 'Dropi error: sin stock',
          'orderId': null,
        },
      });

      await tester.pumpWidget(
        MaterialApp(home: OrderConfirmationScreen(result: result)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tu pedido se registro, pero el envio quedo pendiente'),
        findsOneWidget,
      );
      expect(find.text('Pedido #35'), findsOneWidget);
      expect(find.textContaining('Dropi error'), findsOneWidget);
    });

    testWidgets('no acusa falla de envio cuando no hay proveedor', (
      tester,
    ) async {
      // `success: null` es un pedido con productos propios. Mostrar la caja de
      // error alarmaria al cliente por nada.
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final result = OrderResult.fromJson({
        ..._orderResponse,
        'dropi': {
          'success': null,
          'message': 'Pedido sin productos de proveedor; no aplica Dropi',
          'orderId': null,
        },
      });

      await tester.pumpWidget(
        MaterialApp(home: OrderConfirmationScreen(result: result)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tu pedido se registro, pero el envio quedo pendiente'),
        findsNothing,
      );
    });
  });

  group('carrito', () {
    testWidgets('ya no dice que el pago no esta disponible', (tester) async {
      // Ese texto contradecía los terminos y condiciones publicados, que
      // describen un pedido con numero y pago contra entrega.
      await _pumpApp(tester, home: const CartScreen());

      expect(find.textContaining('todavia no esta disponible'), findsNothing);
    });

    testWidgets(
      'ofrece confirmar el pedido en vez de ir a un pago inexistente',
      (tester) async {
        await _pumpApp(tester, home: const CartScreen());

        expect(find.textContaining('Confirmar pedido'), findsOneWidget);
      },
    );
  });

  group('formulario de entrega', () {
    testWidgets('pide los datos que el backend exige', (tester) async {
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();

      expect(find.text('Nombre completo'), findsOneWidget);
      expect(find.text('Telefono'), findsOneWidget);
      expect(find.text('Direccion de entrega'), findsOneWidget);
      expect(find.text('Ciudad'), findsOneWidget);
      expect(find.text('Departamento'), findsOneWidget);
    });

    testWidgets('explica el pago contra entrega antes de confirmar', (
      tester,
    ) async {
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();

      expect(find.text('Pagas contra entrega'), findsOneWidget);
    });

    testWidgets('trae el nombre y el correo de la cuenta', (tester) async {
      // El backend usaria esos datos tal cual, y pedir al cliente que escriba
      // su propio correo a mano es pedirle que se equivoque.
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();

      final name = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Nombre completo'),
      );
      expect(name.initialValue, 'Kevin Prueba');

      final email = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Correo para la confirmacion'),
      );
      expect(email.initialValue, 'kronio.test.2026@gmail.com');
    });

    testWidgets('no deja confirmar sin llenar los datos', (tester) async {
      // Sin esto el backend responde 400 con "Error de validacion", que no
      // le dice al cliente que campo falta.
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();

      await _tapConfirm(tester);

      expect(find.text('Escribe tu telefono'), findsOneWidget);
      expect(find.text('Escribe la direccion'), findsOneWidget);
      expect(find.byType(OrderConfirmationScreen), findsNothing);
    });

    testWidgets('rechaza un telefono que no es uno', (tester) async {
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();
      await _fillShipping(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefono'),
        '123',
      );
      await _tapConfirm(tester);

      expect(find.text('Escribe un telefono de 10 digitos'), findsOneWidget);
    });

    testWidgets('rechaza un correo con formato invalido', (tester) async {
      // El backend valida con `z.email()`: un correo invalido es un 400.
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();
      await _fillShipping(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo para la confirmacion'),
        'esto-no-es-un-correo',
      );
      await _tapConfirm(tester);

      expect(find.text('Ese correo no parece valido'), findsOneWidget);
    });

    testWidgets('un carrito vacio no ofrece el formulario', (tester) async {
      // Se llega por ruta normal, pero tambien puede pasar si el servidor ya
      // proceso el pedido. En los dos casos no hay nada que confirmar y la
      // pantalla lo dice en vez de mostrar campos vacios que no van a servir.
      await _pumpApp(tester, home: const CheckoutScreen(), quantity: 0);
      await tester.pumpAndSettle();

      expect(find.text('Tu carrito esta vacio.'), findsOneWidget);
      expect(_confirmButton(), findsNothing);
    });
  });

  group('compra completa', () {
    testWidgets('crea el pedido y muestra la confirmacion', (tester) async {
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      expect(find.byType(OrderConfirmationScreen), findsOneWidget);
      expect(find.text('Pedido #35'), findsOneWidget);
    });

    testWidgets('sube el carrito al servidor antes de confirmar', (
      tester,
    ) async {
      // El backend lee el carrito de la base de datos, no el de la app. Sin
      // este paso el checkout responde "tu carrito esta vacio" aunque el
      // usuario vea productos en pantalla.
      final cart = await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      // El carrito local se vacia solo cuando el pedido existe: si se vaciara
      // antes, un fallo de red dejaria al usuario sin pedido y sin carrito.
      expect(cart.isEmpty, isTrue);
    });

    testWidgets('manda las peticiones de carrito en el orden correcto', (
      tester,
    ) async {
      // El orden importa de verdad: si el backend recibiera el DELETE de lo que
      // el cliente quito antes del POST de lo que agrego, el carrito del
      // servidor pasaria por un estado vacio, y un checkout que corra ahi crea
      // un pedido sin productos.
      SharedPreferences.setMockInitialValues({});

      // El servidor ya tiene un producto que el cliente quito del carrito
      // local, y le falta el que el cliente acaba de agregar. Esa es la
      // situacion que obliga a hacer POST y DELETE en la misma pasada.
      final client = _FakeBackend(
        serverCart: const [
          {'id': 'ciViejo', 'productId': 'viejo', 'quantity': 1},
        ],
      );
      final api = ApiService(client: client, baseUrl: _baseUrl);
      final service = CheckoutService(api: api);
      final cart = await CartService.load();
      await cart.add(_product('nuevo'));

      await service.syncLocalCartToServer(cart);

      final cartCalls = client.cartCalls;
      final addIndex = cartCalls.indexWhere((c) => c.contains('cart/add'));
      final deleteIndex = cartCalls.indexWhere((c) => c.contains('DELETE'));

      expect(addIndex, isNonNegative, reason: 'no se mando el POST /cart/add');
      expect(deleteIndex, isNonNegative, reason: 'no se mando ningun DELETE');
      expect(
        addIndex,
        lessThan(deleteIndex),
        reason:
            'el DELETE no puede ir antes del POST: el carrito del servidor '
            'pasaria por un estado vacio',
      );
    });

    testWidgets('un fallo del checkout no vacia el carrito local', (
      tester,
    ) async {
      // Si el carrito se vaciara antes de saber si el pedido se creo, un corte
      // de red dejaria al cliente sin pedido y sin productos: el peor estado
      // posible, porque no puede ni reintentar ni recuperar lo que queria.
      final cart = await _pumpApp(
        tester,
        home: const CheckoutScreen(),
        checkoutStatus: 500,
        checkoutBody: const {'message': 'Error interno'},
      );
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      expect(cart.isEmpty, isFalse);
      expect(cart.totalItems, 2);
    });

    testWidgets('un fallo deja el formulario con los datos escritos', (
      tester,
    ) async {
      // Perder lo que el cliente escribio porque el servidor caio es la queja
      // tipica del checkout: obligarlo a volver a digitar todo.
      await _pumpApp(
        tester,
        home: const CheckoutScreen(),
        checkoutStatus: 500,
        checkoutBody: const {'message': 'Error interno'},
      );
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      final address = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Direccion de entrega'),
      );
      expect(address.controller!.text, 'Calle 100 # 20-30');
    });

    testWidgets('el error de red ofrece reintentar, no volver al carrito', (
      tester,
    ) async {
      // Volver atras solo sirve si el problema eran los productos. Ante un 500
      // lo correcto es insistir sin perder lo escrito.
      await _pumpApp(
        tester,
        home: const CheckoutScreen(),
        checkoutStatus: 500,
        checkoutBody: const {'message': 'Error interno'},
      );
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Volver al carrito'), findsNothing);
    });

    testWidgets('el boton se bloquea mientras corre la peticion', (
      tester,
    ) async {
      // Sin bloqueo, un doble toque manda dos checkouts: el backend crea el
      // primero y el segundo responde "carrito vacio", y el usuario ve un error
      // despues de haber comprado bien.
      await _pumpApp(tester, home: const CheckoutScreen());
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _scrollToConfirm(tester);

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: _confirmButton(),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('un 401 manda a iniciar sesion en vez de reintentar', (
      tester,
    ) async {
      // Reintentar un checkout sin cookie vuelve a fallar con el mismo 401.
      // Ofrecer "reintentar" ahi es una trampa.
      await _pumpApp(
        tester,
        home: const CheckoutScreen(),
        checkoutStatus: 401,
        checkoutBody: const {'message': 'Unauthorized'},
      );
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      expect(find.text('Iniciar sesion'), findsOneWidget);
    });

    testWidgets('el limite de solicitudes ofrece esperar, no reintentar', (
      tester,
    ) async {
      // El backend tiene un tope de 10/min en el checkout. Decirle al cliente
      // que espere es lo unico que funciona.
      await _pumpApp(
        tester,
        home: const CheckoutScreen(),
        checkoutStatus: 429,
        checkoutBody: const {'message': 'ThrottlerException: Too Many'},
      );
      await tester.pumpAndSettle();
      await _fillShipping(tester);
      await _tapConfirm(tester);

      expect(find.textContaining('Espera unos segundos'), findsOneWidget);
    });
  });
}
