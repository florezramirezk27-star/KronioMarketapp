import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/models/order.dart';

/// Body tal como lo devuelve `POST /orders/checkout` en produccion.
///
/// Esta fixture es una **captura real** de la respuesta del backend
/// (verificado contra la API desplegada), no algo inventado. Por eso conserva
/// las dos trampas del formato: el `total` como string y el `numericId` que es
/// el numero que ve el cliente.
Map<String, dynamic> _checkoutResponse({
  Object total = '538000',
  String status = 'PENDING',
  Object? dropi = const <String, dynamic>{
    'success': true,
    'message': 'Pedido creado en el proveedor',
    'orderId': 987654,
  },
  Object? emails = const <String, dynamic>{
    'customer': 'queued',
    'admin': 'queued',
  },
}) {
  return {
    'id': 'cmuqbpxmi000yc731k4c6xqit',
    'numericId': 35,
    'userId': 'cmuqbojfi000oc731eya6c9wj',
    'total': total,
    'status': status,
    'paymentMethod': 'CASH_ON_DELIVERY',
    'shippingName': 'Kevin Prueba',
    'shippingPhone': '3001234567',
    'shippingAddress': 'Calle 100 # 20-30',
    'shippingCity': 'Bogota',
    'shippingState': 'Cundinamarca',
    'shippingZip': null,
    'shippingEmail': 'kronio.test.2026@gmail.com',
    'notes': null,
    'idempotencyKey': null,
    'createdAt': '2026-10-02T02:08:06.522Z',
    'updatedAt': '2026-10-02T02:08:06.522Z',
    'items': [
      {
        'id': 'oi1',
        'orderId': 'cmuqbpxmi000yc731k4c6xqit',
        'productId': 'cmubhhnth0006j5e8awhf8qnw',
        'quantity': 2,
        'price': '269000',
        'product': {
          'id': 'cmubhhnth0006j5e8awhf8qnw',
          'name': 'Reloj Naviforce Casual Nf8028',
          'image': 'reloj.jpg',
        },
      },
    ],
    'dropi': ?dropi,
    'emails': ?emails,
  };
}

void main() {
  group('Order.fromJson', () {
    test('lee el total que llega como string', () {
      // El punto de todo el modelo: Prisma serializa `Decimal` como texto. Un
      // `as double` revienta aca.
      final order = Order.fromJson(_checkoutResponse());

      expect(order.total, 538000);
    });

    test('acepta el total si el backend pasa a mandarlo como numero', () {
      // Blindaje a futuro: el fixture de la DB es `Decimal`, pero cambiarlo a
      // `Float` es un cambio de una linea en el schema que no deberia romper la
      // app.
      final order = Order.fromJson(_checkoutResponse(total: 538000.0));

      expect(order.total, 538000);
    });

    test('muestra el numericId, no el cuid', () {
      // El `id` es opaco y nunca se muestra; soporte habla de "#35".
      final order = Order.fromJson(_checkoutResponse());

      expect(order.numericId, 35);
      expect(order.id, 'cmuqbpxmi000yc731k4c6xqit');
    });

    test('degrada a cero si el total no se puede interpretar', () {
      // Un total ilegible no puede romper la pantalla: se muestra 0 y el pedido
      // sigue siendo visible con su numero.
      final order = Order.fromJson(_checkoutResponse(total: 'no-es-un-numero'));

      expect(order.total, 0);
      expect(order.numericId, 35);
    });

    test('lee los items con el producto embebido', () {
      final order = Order.fromJson(_checkoutResponse());

      expect(order.items, hasLength(1));
      expect(order.items.first.name, 'Reloj Naviforce Casual Nf8028');
      expect(order.items.first.quantity, 2);
      expect(order.items.first.price, 269000);
      expect(order.items.first.total, 538000);
    });

    test('no explota si el producto no viene embebido', () {
      // `GET /orders/my-orders` incluye `product`, pero no hay garantia de que
      // la forma no cambie. Un nombre vacio es mejor que una excepcion.
      final json = _checkoutResponse();
      (json['items'] as List).first.remove('product');

      final order = Order.fromJson(json);

      expect(order.items.first.name, isEmpty);
      expect(order.items.first.productId, 'cmubhhnth0006j5e8awhf8qnw');
    });

    test('los null de envio se vuelven cadena vacia', () {
      final order = Order.fromJson(_checkoutResponse()..['shippingZip'] = null);

      expect(order.shippingZip, isEmpty);
      expect(order.shippingName, 'Kevin Prueba');
    });

    test('ignora items que no son mapas', () {
      // La lista del fixture se construye con mapas literales, asi que es
      // `List<Map<String, Object>>` y no admite un string. Se reescribe entera
      // como `List<dynamic>` para poder meter basura a proposito.
      final json = _checkoutResponse();
      final items = <dynamic>[
        ...json['items']! as List<dynamic>,
        'basura',
        42,
        null,
      ];
      json['items'] = items;

      final order = Order.fromJson(json);

      expect(order.items, hasLength(1));
    });
  });

  group('Order.shippingSummary', () {
    test('une direccion, ciudad y departamento', () {
      final order = Order.fromJson(_checkoutResponse());

      expect(order.shippingSummary, 'Calle 100 # 20-30, Bogota, Cundinamarca');
    });

    test('dice que no hay direccion en vez de mostrar una cadena vacia', () {
      // Una linea de texto vacia en la confirmacion parece un error de la app.
      final json = _checkoutResponse()
        ..['shippingAddress'] = ''
        ..['shippingCity'] = ''
        ..['shippingState'] = '';

      final order = Order.fromJson(json);

      expect(order.shippingSummary, 'Sin direccion registrada');
    });

    test('omite las partes vacias en vez de dejar comas sueltas', () {
      // Un join sin filtrar produce "Calle 1, , Bogota" si falta un dato.
      final json = _checkoutResponse()..['shippingState'] = '';

      final order = Order.fromJson(json);

      expect(order.shippingSummary, 'Calle 100 # 20-30, Bogota');
    });
  });

  group('OrderStatus', () {
    test('traduce los cinco estados del enum de Prisma', () {
      expect(OrderStatus.fromRaw('PENDING'), OrderStatus.pending);
      expect(OrderStatus.fromRaw('PAID'), OrderStatus.paid);
      expect(OrderStatus.fromRaw('SHIPPED'), OrderStatus.shipped);
      expect(OrderStatus.fromRaw('DELIVERED'), OrderStatus.delivered);
      expect(OrderStatus.fromRaw('CANCELLED'), OrderStatus.cancelled);
    });

    test('un estado nuevo no rompe la app', () {
      // Si el backend agrega un estado, la app tiene que seguir compilando y
      // funcionando. Por eso el parseo es un `switch` con `default`, no un
      // `tryParse` que devuelve null.
      final status = OrderStatus.fromRaw('REFUNDED');

      expect(status, OrderStatus.unknown);
      expect(status.label, 'En proceso');
    });

    test('el enum no le gana a un valor en minusculas', () {
      // Prisma devuelve mayusculas, pero un cambio ahi no debe romper la UI.
      expect(OrderStatus.fromRaw('shipped'), OrderStatus.shipped);
    });

    test('los labels no muestran el nombre crudo del enum', () {
      expect(OrderStatus.pending.label, 'Pendiente');
      expect(OrderStatus.shipped.label, 'En camino');
      expect(OrderStatus.cancelled.label, 'Cancelado');
    });
  });

  group('OrderResult', () {
    test('marca el envio como despachado cuando Dropi acepta', () {
      final result = OrderResult.fromJson(_checkoutResponse());

      expect(result.shippingDispatched, isTrue);
      expect(result.hasShippingProblem, isFalse);
      expect(result.dropiOrderId, '987654');
    });

    test('reporta el problema cuando el proveedor rechaza', () {
      // Estado real de dropshipping: el pedido existe y se cobra igual, pero
      // no se envia. Ocultarlo seria mentirle al cliente.
      final result = OrderResult.fromJson(
        _checkoutResponse(
          dropi: const {
            'success': false,
            'message': 'Dropi error: sin stock',
            'orderId': null,
          },
        ),
      );

      expect(result.hasShippingProblem, isTrue);
      expect(result.shippingDispatched, isFalse);
      expect(result.dropiMessage, 'Dropi error: sin stock');
    });

    test('no confunde "sin proveedor" con "el proveedor fallo"', () {
      // `success: null` es un pedido con productos propios. Pintarlo como error
      // seria alarmar al cliente por nada.
      final result = OrderResult.fromJson(
        _checkoutResponse(
          dropi: const {
            'success': null,
            'message': 'Pedido sin productos de proveedor; no aplica Dropi',
            'orderId': null,
          },
        ),
      );

      expect(result.dropiSuccess, isNull);
      expect(result.hasShippingProblem, isFalse);
    });

    test('el pedido existe aunque el proveedor falle', () {
      // El numero de pedido es lo que el cliente necesita para escribir a
      // soporte. Si la pantalla de error lo oculta, el cliente no puede reclamar.
      final result = OrderResult.fromJson(
        _checkoutResponse(dropi: const {'success': false, 'message': 'x'}),
      );

      expect(result.order.numericId, 35);
    });

    test('no explota si no vienen los bloques dropi ni emails', () {
      final json = _checkoutResponse()
        ..remove('dropi')
        ..remove('emails');

      final result = OrderResult.fromJson(json);

      expect(result.dropiSuccess, isNull);
      expect(result.customerEmailQueued, isFalse);
      expect(result.order.numericId, 35);
    });
  });

  group('OrderTracking', () {
    test('solo dice que hay guia cuando hay numero', () {
      const vacio = OrderTracking();
      expect(vacio.hasGuide, isFalse);

      final conGuia = OrderTracking.fromJson({
        'carrier': 'Interrapidisimo',
        'dropiGuideId': 'IU123456789CO',
        'trackingUrl': 'https://rastreo.example/IU123456789CO',
        'status': 'CREATED',
        'lastEvent': 'Pedido entregado al transportador',
      });
      expect(conGuia.hasGuide, isTrue);
      expect(conGuia.carrier, 'Interrapidisimo');
    });

    test('una guia vacia no cuenta como guia', () {
      // El backend puede mandar `dropiGuideId: ""` en vez de `null`. Mostrar
      // "Numero de guia: " en blanco queda peor que no mostrar la seccion.
      final tracking = OrderTracking.fromJson({
        'dropiGuideId': '   ',
        'carrier': '   ',
      });

      expect(tracking.hasGuide, isFalse);
      expect(tracking.carrier, isNull);
    });
  });
}
