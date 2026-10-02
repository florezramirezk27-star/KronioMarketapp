import 'dart:math';

import '../models/order.dart';
import 'api_exception.dart';
import 'api_service.dart';
import 'cart_service.dart';

/// Datos de entrega que pide el backend.
///
/// Los campos son los de `checkoutSchema` (Zod) del backend, no los de la clase
/// `CheckoutDto`: el que manda es el de Zod, porque es el que corre antes de
/// llegar al controlador. Un campo obligatorio de mas aqui produce un 400 con
/// el mensaje generico "Error de validación" y no se puede depurar.
class ShippingDetails {
  const ShippingDetails({
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    this.zip,
    this.email,
    this.docType,
    this.docNumber,
    this.notes,
  });

  final String name;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String? zip;
  final String? email;
  final String? docType;
  final String? docNumber;
  final String? notes;

  /// Arma el cuerpo de la peticion.
  ///
  /// Los opcionales se omiten cuando vienen vacios en vez de mandarse como
  /// `""`. No es solo limpieza: `shippingEmail` pasa por `z.email()`, y una
  /// cadena vacia ahi es un 400. El propio esquema lo admite con
  /// `.or(z.literal(''))`, pero mandarlo vacio es una forma de fallar sin
  /// querer.
  Map<String, dynamic> toBody(String idempotencyKey) {
    return {
      'idempotencyKey': idempotencyKey,
      'shippingName': name.trim(),
      'shippingPhone': phone.trim(),
      'shippingAddress': address.trim(),
      'shippingCity': city.trim(),
      'shippingState': state.trim(),
      if (_filled(zip)) 'shippingZip': zip!.trim(),
      if (_filled(email)) 'shippingEmail': email!.trim(),
      if (_filled(docType)) 'shippingDocType': docType!.trim(),
      if (_filled(docNumber)) 'shippingDocNumber': docNumber!.trim(),
      if (_filled(notes)) 'notes': notes!.trim(),
    };
  }

  /// Prepara el formulario con lo que ya sabe la cuenta.
  ///
  /// El nombre y el correo salen del perfil para que el comprador no los escriba
  /// a mano en cada pedido; el resto se escribe siempre.
  factory ShippingDetails.forUser({
    required String name,
    required String phone,
    required String address,
    required String city,
    required String state,
    String? email,
  }) {
    return ShippingDetails(
      name: name,
      phone: phone,
      address: address,
      city: city,
      state: state,
      email: email,
    );
  }

  static bool _filled(String? value) =>
      value != null && value.trim().isNotEmpty;
}

/// Lo que paso al intentar comprar, cuando no se pudo crear el pedido.
///
/// Se distinguen los casos porque la accion que corresponde es distinta: si el
/// problema es de stock hay que revisar el carrito, si es de red hay que
/// reintentar, y si el backend esta caido no hay nada que el usuario pueda
/// hacer.
enum CheckoutFailure {
  /// El backend dijo que falta stock o que el carrito quedo vacio.
  unavailable,

  /// No hay sesion. Hay que mandar a iniciar sesion antes de comprar.
  unauthenticated,

  /// El backend no esta disponible o la red fallo.
  network,

  /// El backend respondio algo que no tiene el formato esperado.
  unexpected,
}

/// Resultado del intento de compra: o un pedido, o la razon del fallo.
///
/// Se usa en vez de excepciones porque la pantalla de checkout tiene que
/// distinguir "reintenta" de "arregla tus datos" de "vuelve al carrito", y eso
/// no se puede decidir leyendo el texto de una excepcion.
class CheckoutOutcome {
  const CheckoutOutcome.success(this.result) : failure = null, message = '';

  const CheckoutOutcome.failed(this.failure, this.message) : result = null;

  final OrderResult? result;
  final CheckoutFailure? failure;

  /// Mensaje para mostrar al usuario, ya redactado.
  final String message;

  bool get isSuccess => result != null;
}

/// Compra y consulta de pedidos.
///
/// El flujo real del backend (verificado contra produccion):
///
///  1. El carrito vive en el **servidor**, por usuario: `GET /cart`,
///     `POST /cart/add`, `PATCH /cart/:id`, `DELETE /cart/:id`. El checkout lee
///     el carrito de la base de datos, **no** lo que mande el cliente.
///  2. `POST /orders/checkout` con los datos de entrega crea el pedido,
///     descuenta stock, llama a Dropi y encola los correos. Vacia el carrito.
///
/// Ese punto 1 es el que suele romper un checkout mal armado: si la app tiene un
/// carrito local (y lo tiene, ver [CartService]) y llama al checkout sin
/// volcarlo primero al servidor, el backend responde "Tu carrito está vacío".
/// Por eso [syncLocalCartToServer] va antes de [checkout] y no es opcional.
class CheckoutService {
  CheckoutService({required this.api});

  final ApiService api;

  /// Vuelca el carrito local al carrito del servidor.
  ///
  /// Compara contra lo que ya hay en el servidor y solo cambia lo que difiere,
  /// en vez de limpiar y volver a agregar todo: `DELETE /cart/:id` + `POST`
  /// en cada producto genera una ventana en la que el carrito del servidor
  /// queda vacio, y si el checkout corre ahi el pedido sale sin productos.
  ///
  /// Usa el `id` del item del servidor, no el `productId`, porque es con lo que
  /// funcionan `PATCH` y `DELETE`.
  ///
  /// Devuelve `true` si el carrito del servidor quedo igual que el local.
  Future<bool> syncLocalCartToServer(CartService cart) async {
    final local = cart.itemList;
    if (local.isEmpty) return true;

    final remote = await _fetchServerCart();

    // Se empareja por producto. El servidor no puede tener dos items del mismo
    // producto (el `productId` es unico en `CartItem`), asi que un mapa alcanza.
    final remoteByProduct = <String, Map<String, dynamic>>{};
    for (final item in remote) {
      final productId = item['productId']?.toString();
      if (productId != null) remoteByProduct[productId] = item;
    }

    for (final item in local) {
      final existing = remoteByProduct[item.product.id];

      if (existing == null) {
        await api.postJson(
          '/cart/add',
          body: {'productId': item.product.id, 'quantity': item.quantity},
        );
        continue;
      }

      final remoteQty = (existing['quantity'] as num?)?.toInt() ?? 0;
      if (remoteQty == item.quantity) continue;

      final itemId = existing['id']?.toString();
      if (itemId == null) continue;

      await api.patchJson('/cart/$itemId', body: {'quantity': item.quantity});
    }

    // Lo que este en el servidor y ya no este en el local se quita.
    final localIds = local.map((item) => item.product.id).toSet();
    for (final item in remote) {
      final productId = item['productId']?.toString();
      final itemId = item['id']?.toString();
      if (productId == null || itemId == null) continue;
      if (localIds.contains(productId)) continue;

      await api.deleteJson('/cart/$itemId');
    }

    return true;
  }

  /// Crea el pedido.
  ///
  /// [idempotencyKey] se genera si no se pasa. Es lo que evita el doble pedido:
  /// sin red, el backend se queda colgado, la app avisa y el usuario toca
  /// "Reintentar". Si la peticion **si** llego y la respuesta se perdio, el
  /// reintento con la misma clave devuelve el pedido que ya existe en vez de
  /// crear un segundo.
  ///
  /// Por eso la clave se genera **una vez por intento de compra** y se conserva
  /// mientras el usuario reintente: si se generara nueva en cada llamada, la
  /// idempotencia no serviria de nada.
  Future<CheckoutOutcome> checkout(ShippingDetails shipping) async {
    final key = _newIdempotencyKey();

    try {
      final body = await api.postJson(
        '/orders/checkout',
        body: shipping.toBody(key),
      );

      if (body is! Map<String, dynamic>) {
        return const CheckoutOutcome.failed(
          CheckoutFailure.unexpected,
          'El servidor respondio de forma inesperada. Intenta de nuevo.',
        );
      }

      return CheckoutOutcome.success(OrderResult.fromJson(body));
    } on ApiException catch (error) {
      return CheckoutOutcome.failed(_classify(error), _messageFor(error));
    } catch (_) {
      // Una excepcion que no es de la API (un bug de parseo, por ejemplo) no
      // debe llegar al usuario como un error de red sin explicar.
      return const CheckoutOutcome.failed(
        CheckoutFailure.unexpected,
        'Algo salio mal al crear tu pedido. Intenta de nuevo.',
      );
    }
  }

  /// Pedidos del usuario, del mas nuevo al mas viejo.
  Future<List<Order>> myOrders() async {
    final body = await api.getJson('/orders/my-orders');

    final items = body is Map<String, dynamic> ? body['items'] : null;
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(Order.fromJson)
        .toList(growable: false);
  }

  /// Un pedido puntual.
  Future<Order> orderById(String id) async {
    final body = await api.getJson('/orders/${Uri.encodeComponent(id)}');
    if (body is! Map<String, dynamic>) {
      throw const ApiFormatException('El pedido no tiene el formato esperado.');
    }
    return Order.fromJson(body);
  }

  /// Items del carrito en el servidor.
  Future<List<Map<String, dynamic>>> _fetchServerCart() async {
    final body = await api.getJson('/cart');
    if (body is! Map<String, dynamic>) return const [];

    final items = body['items'];
    if (items is! List) return const [];

    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Clasifica el fallo para que la UI sepa que ofrecer.
  ///
  /// [CheckoutFailure.unavailable] es el unico que hace que el boton diga
  /// "Volver al carrito" en vez de "Reintentar": volver atras solo sirve si el
  /// problema eran los productos. Todo lo demas se reintenta en el sitio.
  CheckoutFailure _classify(ApiException error) {
    // 403 included: en este backend un 403 en el checkout es casi siempre CSRF
    // invalido, o sea la sesion se cayo, no que el usuario no pueda comprar.
    if (error.statusCode == 401 || error.statusCode == 403) {
      return CheckoutFailure.unauthenticated;
    }

    if (error.statusCode == 400 ||
        error.statusCode == 409 ||
        error.statusCode == 422) {
      return CheckoutFailure.unavailable;
    }

    return CheckoutFailure.network;
  }

  /// Redacta el mensaje.
  ///
  /// El backend responde `{"statusCode":400,"message":"Error de validación"}` o
  /// `{"message":"Tu carrito está vacío"}`. Se traducen los que se pueden
  /// resolver desde el boton de reintentar y el resto se muestra el texto tal
  /// cual: inventar un mensaje "amigable" sobre un error que no se entiende
  /// hace que soporte tenga menos informacion, no mas.
  String _messageFor(ApiException error) {
    final server = error.serverMessage?.toLowerCase() ?? '';

    if (server.contains('carrito está vacío') ||
        server.contains('carrito esta vacio')) {
      return 'Tu carrito quedo vacio en el servidor. Revisa los productos e '
          'intenta de nuevo.';
    }

    if (server.contains('stock') || server.contains('disponible')) {
      return 'Uno de los productos ya no tiene existencias. Revisa tu carrito '
          'e intentalo de nuevo.';
    }

    if (server.contains('validación') ||
        server.contains('validacion') ||
        server.contains('requerido')) {
      return 'Faltan datos de entrega o alguno esta mal escrito. Revisalos e '
          'intenta de nuevo.';
    }

    if (error.statusCode == 401) {
      return 'Tu sesion expiro. Inicia sesion de nuevo para confirmar el '
          'pedido.';
    }

    // El checkout tiene un limite de 10/min. Un doble toque o un reintento
    // seguido lo puede tumbar, y decir "el servidor esta teniendo problemas"
    // seria mentira: lo que hay que hacer es esperar unos segundos.
    if (error.statusCode == 429) {
      return 'Demasiados intentos seguidos. Espera unos segundos e intenta '
          'de nuevo.';
    }

    if (error is ApiTimeoutException) {
      return 'El servidor tardo demasiado. Tu pedido pudo quedar registrado: '
          'revisa "Mis pedidos" antes de intentar otra vez.';
    }

    if (error.statusCode != null && error.statusCode! >= 500) {
      return 'El servidor tiene problemas en este momento. Intenta de nuevo en '
          'unos minutos.';
    }

    return error.message;
  }

  /// UUID v4, que es lo que valida `z.string().uuid()`.
  ///
  /// Se genera aca en vez de anadir la dependencia `uuid` por una funcion de
  /// 20 lineas. `Random.secure()` porque esta clave protege de crear dos
  /// pedidos con el mismo UUID, y un `Random()` normal sembrado con la hora
  /// sirve para eso justo donde no debe.
  static String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Version 4 y variante RFC 4122, que son los dos bits que el validador mira.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
