import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/brand_header.dart';
import '../widgets/checkout_scope.dart';

/// Detalle de un pedido, con su estado de seguimiento.
///
/// Acepta el pedido ya cargado ([initialOrder]) para pintar de inmediato y
/// despues refrescar contra el backend. Sin eso, abrir el detalle desde la
/// confirmacion mostraria un spinner y un "no encontramos nada" durante el
/// tiempo que tarda la red, cuando el dato ya esta en memoria.
///
/// El refresco es best-effort: si falla se conserva lo que habia. Un error de
/// red no debe borrar el numero de pedido que el cliente ya leyo, que es
/// justo lo que necesita para escribir a soporte.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;

  /// Pedido ya en memoria, si viene de la confirmacion.
  final Order? initialOrder;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order? _order;
  bool _refreshing = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    // Solo se consulta si no came con el pedido en mano.
    if (_order == null) unawaited(_refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    try {
      final fresh = await CheckoutScope.of(context).orderById(widget.orderId);
      if (_disposed) return;
      setState(() => _order = fresh);
    } catch (_) {
      // Se ignora a proposito: el pedido inicial ya se muestra y un fallo de
      // red no debe dejar la pantalla vacia.
    } finally {
      if (!_disposed) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        leading: const BrandHeader(logoSize: 24, showName: false),
        title: Text(order == null ? 'Pedido' : 'Pedido #${order.numericId}'),
      ),
      body: order == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No pudimos cargar el pedido. Revisa tu conexion e '
                  'intenta de nuevo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _StatusCard(order: order),
                  const SizedBox(height: 16),
                  _TrackingCard(order: order),
                  const SizedBox(height: 16),
                  _ItemsCard(order: order),
                  const SizedBox(height: 16),
                  _ShippingCard(order: order),
                  if (_refreshing) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Estado del pedido.
///
/// El estado va con color: "Cancelado" en rojo y "Entregado" en verde se leen
/// de un vistazo, y con el nombre del estado en un solo color el cliente tiene
/// que detener la vista a leerlo.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      OrderStatus.cancelled => AppColors.danger,
      OrderStatus.delivered => AppColors.success,
      OrderStatus.shipped || OrderStatus.paid => AppColors.primary,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_iconFor(order.status), size: 28, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusHint(order.status),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(OrderStatus status) => switch (status) {
    OrderStatus.pending => Icons.hourglass_empty,
    OrderStatus.paid => Icons.payments_outlined,
    OrderStatus.shipped => Icons.local_shipping_outlined,
    OrderStatus.delivered => Icons.check_circle_outline,
    OrderStatus.cancelled => Icons.cancel_outlined,
    OrderStatus.unknown => Icons.help_outline,
  };

  /// Que significa el estado, en la palabra del cliente.
  ///
  /// Un "Pendiente" sin explicar parece una app trabada. Sayendo que el pago
  /// es contra entrega y por eso el pedido sigue pendiente hasta la entrega,
  /// el mismo dato deja de ser una queja.
  static String _statusHint(OrderStatus status) => switch (status) {
    OrderStatus.pending =>
      'Tu pedido esta confirmado. Pagas al transportador cuando lo recibas.',
    OrderStatus.paid => 'El pago ya fue recibido.',
    OrderStatus.shipped => 'Tu pedido va en camino.',
    OrderStatus.delivered => 'Tu pedido fue entregado.',
    OrderStatus.cancelled =>
      'Este pedido fue cancelado. Si no lo solicitaste, escribenos.',
    OrderStatus.unknown => 'Tu pedido esta en proceso.',
  };
}

/// Seguimiento del envio.
///
/// No se muestra la caja cuando no hay guia: una seccion vacia con el titulo
/// "Seguimiento" y un guion le dice al cliente que algo falta, cuando lo real es
/// que el proveedor aun no ha asignado numero de guia, que es normal.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final tracking = order.tracking;
    if (tracking == null || !tracking.hasGuide) return const SizedBox.shrink();

    final hasUrl = (tracking.trackingUrl ?? '').isNotEmpty;

    return _Card(
      title: 'Seguimiento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((tracking.carrier ?? '').isNotEmpty) ...[
            _Line(label: 'Transportadora', value: tracking.carrier!),
            const SizedBox(height: 8),
          ],
          _Line(label: 'Numero de guia', value: tracking.dropiGuideId!),
          if (tracking.lastEvent.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Line(label: 'Ultimo evento', value: tracking.lastEvent),
          ],
          if (hasUrl) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openTracking(context, tracking.trackingUrl!),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Rastrear en la transportadora'),
            ),
          ],
        ],
      ),
    );
  }

  void _openTracking(BuildContext context, String url) {
    // No se puede abrir el link sin `url_launcher`, que no esta en el proyecto.
    // Se muestra la URL para que el cliente la copie, en vez de un boton que no
    // hace nada.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copia este enlace para rastrear tu pedido:\n$url'),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Productos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${line.quantity}x',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.name.isEmpty
                          ? 'Producto ${line.productId}'
                          : line.name,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCop(line.total),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                formatCop(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Datos de entrega',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.shippingName.isNotEmpty)
            _Line(label: 'Recibe', value: order.shippingName),
          if (order.shippingPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Line(label: 'Telefono', value: order.shippingPhone),
          ],
          const SizedBox(height: 8),
          _Line(label: 'Direccion', value: order.shippingSummary),
          const SizedBox(height: 8),
          const _Line(label: 'Pago', value: 'Contra entrega'),
          const SizedBox(height: 12),
          const Text(
            'Revisa estos datos antes de que salga tu pedido. Si algo esta mal, '
            'escribenos con tu numero de pedido.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}
