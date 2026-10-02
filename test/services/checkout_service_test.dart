import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kronio_app/services/api_service.dart';
import 'package:kronio_app/services/cart_service.dart';
import 'package:kronio_app/services/checkout_service.dart';
import 'package:kronio_app/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente HTTP falso que ademas deja inspeccionar lo que se mando.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;

  /// Peticiones registradas, en orden.
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    requests.add(req);

    // El backend sirve la cookie CSRF en un GET a /auth. Sin esto, cualquier
    // metodo que mute se manda sin `X-CSRF-Token` y la prueba no esta probando
    // lo que dice probar.
    if (req.method == 'GET' && req.url.path.endsWith('/auth')) {
      return http.StreamedResponse(
        const Stream.empty(),
        200,
        headers: {
          'set-cookie': '__Host-csrf-token=token-de-prueba; Path=/; Secure',
        },
      );
    }

    final response = await handler(req);
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

Map<String, dynamic> _bodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

ShippingDetails _shipping() => const ShippingDetails(
  name: 'Kevin Prueba',
  phone: '3001234567',
  address: 'Calle 100 # 20-30',
  city: 'Bogota',
  state: 'Cundinamarca',
);

const _orderJson = {
  'id': 'o1',
  'numericId': 35,
  'total': '538000',
  'status': 'PENDING',
  'paymentMethod': 'CASH_ON_DELIVERY',
  'shippingName': 'Kevin Prueba',
  'createdAt': '2026-10-02T02:08:06.522Z',
  'items': [
    {
      'productId': 'p1',
      'quantity': 2,
      'price': '269000',
      'product': {'id': 'p1', 'name': 'Reloj'},
    },
  ],
  'dropi': {'success': true, 'message': 'ok', 'orderId': 1},
  'emails': {'customer': 'queued', 'admin': 'queued'},
};

Product _product(String id, {int stock = 10}) => Product(
  id: id,
  name: 'Producto $id',
  slug: 'producto-$id',
  price: 269000,
  image: '$id.jpg',
  stock: stock,
  active: true,
);

void main() {
  // El `CartService` persiste en `SharedPreferences`, que necesita su mock
  // antes de cargar nada. Sin esto `load()` devuelve un carrito con lo que
  // hubiera de otra prueba.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ShippingDetails.toBody', () {
    test('manda los campos obligatorios con el nombre que espera Zod', () {
      final body = _shipping().toBody('clave-uuid');

      expect(body['shippingName'], 'Kevin Prueba');
      expect(body['shippingPhone'], '3001234567');
      expect(body['shippingAddress'], 'Calle 100 # 20-30');
      expect(body['shippingCity'], 'Bogota');
      expect(body['shippingState'], 'Cundinamarca');
      expect(body['idempotencyKey'], 'clave-uuid');
    });

    test('omite los opcionales vacios en vez de mandarlos como ""', () {
      // `shippingEmail` pasa por `z.email()`. Una cadena vacia ahi es un 400 con
      // el mensaje generico "Error de validacion", que no dice que campo fallo.
      final body = _shipping().toBody('clave');

      expect(body.containsKey('shippingZip'), isFalse);
      expect(body.containsKey('shippingEmail'), isFalse);
      expect(body.containsKey('notes'), isFalse);
      expect(body.containsKey('shippingDocType'), isFalse);
    });

    test('manda los opcionales que si tienen contenido', () {
      final details = ShippingDetails(
        name: 'Kevin',
        phone: '3001234567',
        address: 'Calle 1 # 2-3',
        city: 'Bogota',
        state: 'Bogota D.C.',
        zip: '110111',
        email: 'kronio.test.2026@gmail.com',
        docType: 'CC',
        docNumber: '123456',
        notes: '  Entregar en la manana  ',
      );

      final body = details.toBody('clave');

      expect(body['shippingZip'], '110111');
      expect(body['shippingEmail'], 'kronio.test.2026@gmail.com');
      expect(body['notes'], 'Entregar en la manana');
    });

    test('recorta espacios que el usuario dejo pegados', () {
      // Un " Bogota " con espacios se guardaria asi en la base y el
      // transportador no lo encuentra.
      final details = ShippingDetails(
        name: '  Kevin  ',
        phone: '3001234567',
        address: ' Calle 1 ',
        city: ' Bogota ',
        state: ' Bogota D.C. ',
        zip: '   ',
      );

      final body = details.toBody('clave');

      expect(body['shippingName'], 'Kevin');
      expect(body['shippingCity'], 'Bogota');
      expect(body.containsKey('shippingZip'), isFalse);
    });
  });

  group('CheckoutService.checkout', () {
    test('crea el pedido y devuelve el numero que ve el cliente', () async {
      final client = _FakeClient((_) async => _json(_orderJson));
      final service = CheckoutService(api: ApiService(client: client));

      final outcome = await service.checkout(_shipping());

      expect(outcome.isSuccess, isTrue);
      expect(outcome.result!.order.numericId, 35);
      expect(outcome.result!.order.total, 538000);
      expect(outcome.result!.shippingDispatched, isTrue);
    });

    test('manda la idempotencyKey en formato UUID v4', () async {
      // El backend valida con `z.string().uuid()`. Una clave mal formada es un
      // 400 y el cliente no tendria forma de saber por que.
      final client = _FakeClient((_) async => _json(_orderJson));
      final service = CheckoutService(api: ApiService(client: client));

      await service.checkout(_shipping());

      final post = client.requests.firstWhere(
        (r) => r.method == 'POST' && r.url.path.endsWith('/orders/checkout'),
      );
      final key = _bodyOf(post)['idempotencyKey'] as String;

      expect(
        key,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}'
            r'-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('dos intentos seguidos usan claves distintas', () async {
      // Si la clave fuera fija, el segundo reintento devolveria el mismo pedido
      // y el usuario no podria comprar dos veces. Si fuera identica por
      // coincidence logica, la idempotenciaeria.
      final client = _FakeClient((_) async => _json(_orderJson));
      final service = CheckoutService(api: ApiService(client: client));

      await service.checkout(_shipping());
      await service.checkout(_shipping());

      final keys = client.requests
          .where((r) => r.method == 'POST' && r.url.path.endsWith('/checkout'))
          .map((r) => _bodyOf(r)['idempotencyKey'])
          .toList();

      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(2));
    });

    test(
      'traduce "carrito vacio" sin dejar el mensaje crudo del servidor',
      () async {
        final client = _FakeClient(
          (_) async => _json({
            'statusCode': 400,
            'message': 'Tu carrito está vacío',
          }, status: 400),
        );
        final service = CheckoutService(api: ApiService(client: client));

        final outcome = await service.checkout(_shipping());

        expect(outcome.isSuccess, isFalse);
        expect(outcome.failure, CheckoutFailure.unavailable);
        // El mensaje tiene que estar en espanol y sin caracteres raros.
        expect(outcome.message, isNot(contains('á')));
        expect(outcome.message.toLowerCase(), contains('carrito'));
      },
    );

    test(
      'un fallo de validacion se clasifica como problema del cliente',
      () async {
        // El backend responde este texto generico cuando falla Zod, que es un
        // 400 indistinguible por codigo del "carrito vacio".
        final client = _FakeClient(
          (_) async => _json({
            'statusCode': 400,
            'message': 'Error de validación',
          }, status: 400),
        );
        final service = CheckoutService(api: ApiService(client: client));

        final outcome = await service.checkout(_shipping());

        expect(outcome.failure, CheckoutFailure.unavailable);
        expect(outcome.message.toLowerCase(), contains('datos de entrega'));
      },
    );

    test('sin sesion el fallo es de sesion, no de red', () async {
      // Distinguir esto importa: un 401 se arregla iniciando sesion, un error de
      // red se arregla reintentando. Mostrar "reintentá" ante un 401 nunca
      // funciona.
      final client = _FakeClient(
        (_) async => _json({'message': 'Unauthorized'}, status: 401),
      );
      final service = CheckoutService(api: ApiService(client: client));

      final outcome = await service.checkout(_shipping());

      expect(outcome.failure, CheckoutFailure.unauthenticated);
      expect(outcome.message.toLowerCase(), contains('sesion'));
    });

    test('un 403 por CSRF se trata como sesion caida', () async {
      // En este backend el 403 del checkout es casi siempre token CSRF
      // invalido, o sea la sesion se cayo. Pedir login de nuevo es lo correcto.
      final client = _FakeClient(
        (_) async => _json({'message': 'CSRF token inválido'}, status: 403),
      );
      final service = CheckoutService(api: ApiService(client: client));

      final outcome = await service.checkout(_shipping());

      expect(outcome.failure, CheckoutFailure.unauthenticated);
    });

    test(
      'el limite de 10 por minuto no se reporta como caida del servidor',
      () async {
        // El checkout tiene throttle de 10/min. Decirle al cliente "el servidor
        // esta teniendo problemas" cuando lo que hay es que espere 10 segundos
        // manda a soporte por nada.
        final client = _FakeClient(
          (_) async => _json({
            'statusCode': 429,
            'message': 'ThrottlerException: Too Many',
          }, status: 429),
        );
        final service = CheckoutService(api: ApiService(client: client));

        final outcome = await service.checkout(_shipping());

        expect(outcome.message.toLowerCase(), contains('espera'));
      },
    );

    test('un timeout advierte que el pedido pudo quedar registrado', () async {
      // Es el caso peligroso: la peticion si pudo llegar y la respuesta se
      // perdio. Sin este aviso el cliente reintenta y compra dos veces.
      final client = _FakeClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return _json(_orderJson);
      });
      final service = CheckoutService(
        api: ApiService(
          client: client,
          requestTimeout: const Duration(milliseconds: 50),
        ),
      );

      final outcome = await service.checkout(_shipping());

      expect(outcome.failure, CheckoutFailure.network);
      expect(outcome.message.toLowerCase(), contains('pudo quedar registrado'));
    });

    test('una respuesta que no es un mapa no se toma por un pedido', () async {
      final client = _FakeClient((_) async => _json(['algo', 'raro']));
      final service = CheckoutService(api: ApiService(client: client));

      final outcome = await service.checkout(_shipping());

      expect(outcome.isSuccess, isFalse);
      expect(outcome.failure, CheckoutFailure.unexpected);
    });

    test('no filtra excepciones que no son de la API', () async {
      // Un bug de parseo no debe llegar al usuario como "error de red".
      final client = _FakeClient((_) => throw http.ClientException('fallo'));
      final service = CheckoutService(api: ApiService(client: client));

      final outcome = await service.checkout(_shipping());

      expect(outcome.isSuccess, isFalse);
      expect(outcome.message, isNotEmpty);
    });
  });

  group('CheckoutService.syncLocalCartToServer', () {
    test('sube al servidor lo que solo esta en el carrito local', () async {
      // Este es el paso que hace que el checkout funcione: el backend lee el
      // carrito de la base de datos, no el de la app. Sin esto responde "tu
      // carrito esta vacio" aunque el usuario vea productos en pantalla.
      final cart = await CartService.load();
      await cart.add(_product('p1', stock: 10));

      final client = _FakeClient(
        (_) async => _json({'id': 'c1', 'items': <dynamic>[]}),
      );
      final service = CheckoutService(api: ApiService(client: client));

      await service.syncLocalCartToServer(cart);

      final add = client.requests.firstWhere(
        (r) => r.method == 'POST' && r.url.path.endsWith('/cart/add'),
      );
      final body = _bodyOf(add);
      expect(body['productId'], 'p1');
      expect(body['quantity'], 1);
    });

    test('no hace nada si el carrito esta vacio', () async {
      // Una peticion de mas a un carrito vacio seria una condicion de carrera:
      // el backend responderia "carrito vacio" y el checkout fallaria por
      // culpa de la app.
      final cart = await CartService.load();
      final client = _FakeClient((_) async => _json({'items': <dynamic>[]}));
      final service = CheckoutService(api: ApiService(client: client));

      final result = await service.syncLocalCartToServer(cart);

      expect(result, isTrue);
      expect(client.requests, isEmpty);
    });

    test('iguala la cantidad con PATCH cuando ya existe el item', () async {
      // Agregar de nuevo duplicaria el producto: `productId` es unico en
      // `CartItem` y el backend rechazaria el segundo add.
      final cart = await CartService.load();
      await cart.add(_product('p1', stock: 10));
      await cart.add(_product('p1', stock: 10));

      final client = _FakeClient(
        (_) async => _json({
          'id': 'c1',
          'items': [
            {'id': 'ci1', 'productId': 'p1', 'quantity': 1},
          ],
        }),
      );
      final service = CheckoutService(api: ApiService(client: client));

      await service.syncLocalCartToServer(cart);

      final patch = client.requests.firstWhere(
        (r) => r.method == 'PATCH' && r.url.path.endsWith('/cart/ci1'),
      );
      expect(_bodyOf(patch)['quantity'], 2);
      expect(
        client.requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/cart/add'),
        ),
        isEmpty,
      );
    });

    test('no manda PATCH cuando la cantidad ya coincide', () async {
      // Reenviar todo en cada intento genera trafico inutil y, con el throttle
      // de 10/min del checkout, uno de los dos puede rebotarse.
      final cart = await CartService.load();
      await cart.add(_product('p1', stock: 10));

      final client = _FakeClient(
        (_) async => _json({
          'id': 'c1',
          'items': [
            {'id': 'ci1', 'productId': 'p1', 'quantity': 1},
          ],
        }),
      );
      final service = CheckoutService(api: ApiService(client: client));

      await service.syncLocalCartToServer(cart);

      expect(client.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test(
      'borra del servidor lo que el usuario quito del carrito local',
      () async {
        // Si no, el backend cobra por productos que el cliente ya no quiere: el
        // total del pedido sale del carrito del servidor.
        final cart = await CartService.load();
        await cart.add(_product('p1', stock: 10));

        final client = _FakeClient(
          (_) async => _json({
            'id': 'c1',
            'items': [
              {'id': 'ci1', 'productId': 'p1', 'quantity': 1},
              {'id': 'ci2', 'productId': 'p2', 'quantity': 3},
            ],
          }),
        );
        final service = CheckoutService(api: ApiService(client: client));

        await service.syncLocalCartToServer(cart);

        final deletes = client.requests
            .where((r) => r.method == 'DELETE')
            .map((r) => r.url.path)
            .toList();
        expect(deletes, hasLength(1));
        expect(deletes.single, endsWith('/cart/ci2'));
      },
    );

    test('no borra lo que sigue en el carrito local', () async {
      // El caso inverso del anterior: un DELETE de mas deja al usuario sin su
      // producto en el servidor y el checkout sale sin nada.
      final cart = await CartService.load();
      await cart.add(_product('p1', stock: 10));
      await cart.add(_product('p2', stock: 10));

      final client = _FakeClient(
        (_) async => _json({
          'id': 'c1',
          'items': [
            {'id': 'ci1', 'productId': 'p1', 'quantity': 1},
            {'id': 'ci2', 'productId': 'p2', 'quantity': 1},
          ],
        }),
      );
      final service = CheckoutService(api: ApiService(client: client));

      await service.syncLocalCartToServer(cart);

      expect(client.requests.where((r) => r.method == 'DELETE'), isEmpty);
    });

    test('no borra y no agrega en la misma pasada', () async {
      // El orden importa. Si se borrara primero lo que no esta en el local, el
      // carrito del servidor quedaria vacio durante la ventana antes de agregar
      // lo nuevo, y un checkout que corra ahi sale sin productos.
      final cart = await CartService.load();
      await cart.add(_product('nuevo', stock: 10));

      final methods = <String>[];
      final client = _FakeClient((request) async {
        methods.add(request.method);
        return _json({
          'id': 'c1',
          'items': [
            {'id': 'ciViejo', 'productId': 'viejo', 'quantity': 1},
          ],
        });
      });
      final service = CheckoutService(api: ApiService(client: client));

      await service.syncLocalCartToServer(cart);

      final addIndex = methods.indexOf('POST');
      final deleteIndex = methods.indexOf('DELETE');
      expect(addIndex, isNonNegative);
      expect(deleteIndex, isNonNegative);
      expect(addIndex, lessThan(deleteIndex));
    });
  });

  group('CheckoutService.myOrders', () {
    test('devuelve los pedidos del usuario', () async {
      final client = _FakeClient(
        (_) async => _json({
          'items': [_orderJson],
          'total': 1,
          'page': 1,
          'totalPages': 1,
        }),
      );
      final service = CheckoutService(api: ApiService(client: client));

      final orders = await service.myOrders();

      expect(orders, hasLength(1));
      expect(orders.single.numericId, 35);
    });

    test('una respuesta sin items devuelve lista vacia', () async {
      // El usuario sin pedidos no es un error: es la pantalla de "aun no has
      // comprado nada", no un cartel de fallo.
      final client = _FakeClient((_) async => _json({'items': <dynamic>[]}));
      final service = CheckoutService(api: ApiService(client: client));

      expect(await service.myOrders(), isEmpty);
    });

    test('un cuerpo inesperado no revienta la pantalla', () async {
      final client = _FakeClient((_) async => _json('no soy un objeto'));
      final service = CheckoutService(api: ApiService(client: client));

      expect(await service.myOrders(), isEmpty);
    });
  });

  group('CheckoutService.orderById', () {
    test('devuelve el pedido pedido', () async {
      final client = _FakeClient((_) async => _json(_orderJson));
      final service = CheckoutService(api: ApiService(client: client));

      final order = await service.orderById('o1');

      expect(order.numericId, 35);
    });

    test('escapa el id en la URL', () async {
      // Sin escapar, un id raro rompe la ruta. Es defensa barata.
      final client = _FakeClient((_) async => _json(_orderJson));
      final service = CheckoutService(api: ApiService(client: client));

      await service.orderById('o1/../admin');

      expect(
        client.requests.single.url.path,
        endsWith('/orders/o1%2F..%2Fadmin'),
      );
    });
  });
}
