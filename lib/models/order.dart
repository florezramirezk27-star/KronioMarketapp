/// Modelo de un pedido, tal como lo devuelve el backend.
///
/// El endpoint real es `POST /orders/checkout` (verificado contra la API en
/// produccion: crea el pedido, descuenta stock, llama a Dropi y manda los
/// correos). La respuesta es el objeto `Order` de Prisma tal cual, con tres
/// campos anadidos por el servicio:
///
/// ```json
/// {
///   "id": "cmuqbpxmi000yc731k4c6xqit",
///   "numericId": 35,
///   "total": "538000",
///   "status": "PENDING",
///   "paymentMethod": "CASH_ON_DELIVERY",
///   "shippingName": "...",
///   "items": [...],
///   "dropi": { "success": true, "message": "...", "orderId": 123 },
///   "emails": { "customer": "queued", "admin": "queued" }
/// }
/// ```
///
/// Ojo con dos detalles del formato, que son la fuente clasica de bugs:
///
///  - `total` llega como **string**, no como numero. Prisma `Decimal` se
///    serializa asi. Un `num.parse` a ciegas revienta si manana el backend
///    cambia a numero, y un `as double` revienta hoy.
///  - `numericId` es el numero que ve el cliente. El `id` es un `cuid` opaco y
///    nunca se muestra; el personal de soporte habla de "#35".
library;

/// Estados posibles de un pedido, en el orden del ciclo de vida.
///
/// El enum del backend es `PENDING -> PAID -> SHIPPED -> DELIVERED`, mas
/// `CANCELLED`. Para una tienda que cobra contra entrega, `PAID` no lo ve
/// nunca el cliente: se marca al entregar.
enum OrderStatus {
  pending,
  paid,
  shipped,
  delivered,
  cancelled,

  /// Un estado que el backend agrega despues y que la app no conoce todavia.
  ///
  /// No se cae a la primera opcion del enum porque eso seria mostrar "Pendiente"
  /// para un pedido que en realidad esta en algo raro. [OrderStatus.label] lo
  /// deja como "En proceso" y el estado crudo se conserva en
  /// [Order.rawStatus] por si hace falta depurar.
  unknown;

  /// Traduce el valor del enum de Prisma.
  ///
  /// `switch` con `default` en vez de un `tryParse`: un estado nuevo no puede
  /// romper la compilacion de la app.
  static OrderStatus fromRaw(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'PENDING':
        return OrderStatus.pending;
      case 'PAID':
        return OrderStatus.paid;
      case 'SHIPPED':
        return OrderStatus.shipped;
      case 'DELIVERED':
        return OrderStatus.delivered;
      case 'CANCELLED':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.unknown;
    }
  }

  /// Texto para mostrar al cliente.
  String get label => switch (this) {
    OrderStatus.pending => 'Pendiente',
    OrderStatus.paid => 'Pagado',
    OrderStatus.shipped => 'En camino',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.cancelled => 'Cancelado',
    OrderStatus.unknown => 'En proceso',
  };
}

/// Una linea del pedido.
class OrderLine {
  const OrderLine({
    required this.productId,
    required this.quantity,
    required this.price,
    this.name = '',
    this.image = '',
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    // El `product` viene embebido en el checkout pero no siempre en el listado:
    // `GET /orders/my-orders` incluye `items` con `product`, asi que se lee de
    // ahi y si no esta se deja el nombre vacio en vez de inventarlo.
    final product = json['product'];
    final productMap = product is Map<String, dynamic> ? product : const {};

    return OrderLine(
      productId: (json['productId'] ?? '').toString(),
      quantity: _toInt(json['quantity']) ?? 0,
      price: _toDouble(json['price']) ?? 0,
      name: (productMap['name'] ?? '').toString(),
      image: (productMap['image'] ?? '').toString(),
    );
  }

  final String productId;
  final int quantity;

  /// Precio unitario tal como se confirmo en la compra.
  final double price;

  /// Nombre del producto, si el backend lo incluyo.
  final String name;
  final String image;

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'price': price,
    'name': name,
    'image': image,
  };
}

/// Seguimiento del pedido.
///
/// Viene en `order.tracking` cuando Dropi ya respondio. `dropiGuideId` es el
/// numero de guia que se le da al cliente; `trackingUrl` es el link de
/// consulta.
class OrderTracking {
  const OrderTracking({
    this.carrier,
    this.dropiGuideId,
    this.trackingUrl,
    this.status = '',
    this.lastEvent = '',
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) => OrderTracking(
    carrier: _optional(json['carrier']),
    dropiGuideId: _optional(json['dropiGuideId']),
    trackingUrl: _optional(json['trackingUrl']),
    status: _optional(json['status']) ?? '',
    lastEvent: _optional(json['lastEvent']) ?? '',
  );

  final String? carrier;
  final String? dropiGuideId;
  final String? trackingUrl;
  final String status;
  final String lastEvent;

  /// `true` si hay algo concreto que mostrarle al cliente.
  bool get hasGuide => (dropiGuideId ?? '').isNotEmpty;
}

/// Resultado del checkout.
///
/// No es solo el pedido: el backend devuelve tambien si **Dropi** acepto el
/// envio y si los correos se encolaron. Esos dos datos deciden si la pantalla
/// de confirmacion celebra o pide esperar, asi que se conservan.
class OrderResult {
  const OrderResult({
    required this.order,
    this.dropiSuccess,
    this.dropiMessage = '',
    this.dropiOrderId,
    this.customerEmailQueued = false,
  });

  factory OrderResult.fromJson(Map<String, dynamic> json) {
    final dropi = json['dropi'];
    final dropiMap = dropi is Map<String, dynamic> ? dropi : const {};
    final emails = json['emails'];
    final emailsMap = emails is Map<String, dynamic> ? emails : const {};

    final rawSuccess = dropiMap['success'];
    return OrderResult(
      order: Order.fromJson(json),
      // `success` llega como null cuando el producto no es de un proveedor.
      dropiSuccess: rawSuccess is bool ? rawSuccess : null,
      dropiMessage: (dropiMap['message'] ?? '').toString(),
      dropiOrderId: _optional(dropiMap['orderId']),
      customerEmailQueued: emailsMap['customer'] == 'queued',
    );
  }

  final Order order;

  /// `null` cuando el pedido no incluye productos de proveedor, `false` cuando
  /// Dropi lo rechazo.
  final bool? dropiSuccess;

  final String dropiMessage;
  final String? dropiOrderId;
  final bool customerEmailQueued;

  /// El envio quedo tramitado con el proveedor.
  bool get shippingDispatched => dropiSuccess == true;

  /// El pedido se creo pero el proveedor fallo.
  ///
  /// Es un estado real y frecuente en dropshipping, y hidinglo seria mentir:
  /// el cliente ve que su pedido existe pero no llega nunca.
  bool get hasShippingProblem => dropiSuccess == false;
}

/// Un pedido del usuario.
class Order {
  const Order({
    required this.id,
    required this.numericId,
    required this.total,
    required this.status,
    required this.createdAt,
    this.paymentMethod = '',
    this.shippingName = '',
    this.shippingPhone = '',
    this.shippingAddress = '',
    this.shippingCity = '',
    this.shippingState = '',
    this.shippingZip = '',
    this.items = const [],
    this.tracking,
    this.rawStatus = '',
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(OrderLine.fromJson)
              .toList(growable: false)
        : const <OrderLine>[];

    final rawTracking = json['tracking'];

    return Order(
      id: (json['id'] ?? '').toString(),
      numericId: _toInt(json['numericId']) ?? 0,
      total: _toDouble(json['total']) ?? 0,
      status: OrderStatus.fromRaw(json['status'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      shippingName: _optional(json['shippingName']) ?? '',
      shippingPhone: _optional(json['shippingPhone']) ?? '',
      shippingAddress: _optional(json['shippingAddress']) ?? '',
      shippingCity: _optional(json['shippingCity']) ?? '',
      shippingState: _optional(json['shippingState']) ?? '',
      shippingZip: _optional(json['shippingZip']) ?? '',
      items: items,
      tracking: rawTracking is Map<String, dynamic>
          ? OrderTracking.fromJson(rawTracking)
          : null,
      rawStatus: (json['status'] ?? '').toString(),
    );
  }

  /// `cuid` interno. No se muestra nunca.
  final String id;

  /// Numero que ve el cliente ("Pedido #35"). Dropi lo exige entero.
  final int numericId;

  /// Total del pedido.
  final double total;

  final OrderStatus status;

  /// Estado tal como vino del backend, para depurar estados desconocidos.
  final String rawStatus;

  final DateTime createdAt;

  /// `CASH_ON_DELIVERY` es el unico valor que la app envia.
  final String paymentMethod;

  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String shippingCity;
  final String shippingState;
  final String shippingZip;

  final List<OrderLine> items;
  final OrderTracking? tracking;

  /// Numero de unidades, no de lineas.
  int get totalItems => items.fold(0, (sum, line) => sum + line.quantity);

  /// Direccion en una sola linea, para pintar en un subtitulo.
  String get shippingSummary {
    final parts = [
      shippingAddress,
      shippingCity,
      shippingState,
    ].where((part) => part.isNotEmpty).join(', ');
    return parts.isEmpty ? 'Sin direccion registrada' : parts;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'numericId': numericId,
    'total': total,
    'status': rawStatus,
    'createdAt': createdAt.toIso8601String(),
    'paymentMethod': paymentMethod,
    'shippingName': shippingName,
    'shippingPhone': shippingPhone,
    'shippingAddress': shippingAddress,
    'shippingCity': shippingCity,
    'shippingState': shippingState,
    'shippingZip': shippingZip,
    'items': [for (final line in items) line.toJson()],
  };
}

/// Lee un numero que puede venir como `int`, `double` o `String`.
///
/// El backend serializa los `Decimal` de Prisma como string (`"538000"`), pero
/// un cambio futuro podria mandarlos como numero. Aceptar los tres evita que
/// el carrito se rompa por un cambio de formato en el servidor.
double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Vacio y `null` se normalizan a `null`.
///
/// El backend declara casi todos los campos de envio como `String?` y devuelve
/// `null` cuando no los mandaron. Devolver `''` seria igual de valido, pero
/// `null` deja distinguir "no lo mandamos" de "mandamos una cadena en blanco",
/// que es la diferencia entre un formulario mal llenado y uno incompleto.
String? _optional(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
