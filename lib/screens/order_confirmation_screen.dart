import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'order_detail_screen.dart';

/// Confirmacion de un pedido recien creado.
///
/// Se abre con `pushReplacement` desde el checkout, asi que volver atras **no**
/// vuelve a la pantalla de confirmacion: el boton de "Volver al inicio" es el
/// unico salida, y el usuario no tiene forma de reenviar el pedido desde aca.
///
/// El total que se muestra es el que **devolvio el backend** en el
/// `POST /orders/checkout`, no el del carrito local. Puede haber una diferencia
/// si el precio cambio entre que se armo el carrito y se confirmo, y es al
/// backend al que le corresponde cobrar. Mostrar el total local taparia esa
/// diferencia y el usuario se enteraria al recibir el pedido.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.result});

  final OrderResult result;

  @override
  Widget build(BuildContext context) {
    final order = result.order;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedido confirmado'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _SuccessHeader(order: order),
          const SizedBox(height: 20),

          // El fallo de Dropi va **antes** del resumen del pedido, no al final.
          // El pedido existe y se cobro igual, pero si el envio no se tramito el
          // usuario tiene que saberlo ya, no despues de leer cinco lineas de
          // exito.
          if (result.hasShippingProblem) ...[
            _ShippingProblemBox(message: result.dropiMessage),
            const SizedBox(height: 16),
          ],

          _OrderCard(order: order),
          const SizedBox(height: 16),

          _NextSteps(order: order, emailQueued: result.customerEmailQueued),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    OrderDetailScreen(orderId: order.id, initialOrder: order),
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Ver seguimiento del pedido'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Volver a la tienda'),
          ),
        ],
      ),
    );
  }
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 36,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Tu pedido quedo registrado',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // El numero del pedido es lo primero que el usuario necesita si va a
        // escribir a soporte. Por eso va grande y no escondido en un detalle.
        Text(
          'Pedido #${order.numericId}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Resumen de lo pedido, con el total del servidor.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

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
            'Detalle del pedido',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (order.items.isNotEmpty) ...[
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
                        // El nombre puede venir vacio si el backend no incluyo el
                        // producto embebido; se muestra el id para que el cliente
                        // pueda identificar la linea de todos modos.
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
          ],

          _Row(
            label: 'Total a pagar',
            value: formatCop(order.total),
            emphasis: true,
          ),
          const SizedBox(height: 8),
          _Row(label: 'Estado', value: order.status.label),
          const SizedBox(height: 8),
          _Row(label: 'Pago', value: 'Contra entrega'),
          const SizedBox(height: 8),
          _Row(label: 'Envia a', value: order.shippingSummary),
          if (order.shippingPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Row(label: 'Telefono', value: order.shippingPhone),
          ],
          const SizedBox(height: 8),
          _Row(label: 'Fecha', value: _formatDate(order.createdAt)),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasis ? 15 : 13,
      fontWeight: emphasis ? FontWeight.bold : FontWeight.normal,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: style)),
      ],
    );
  }
}

/// Que pasa ahora y cuando llega.
///
/// Los plazos salen de los terminos y condiciones que se publicaron: la Ley
/// 2439 de 2024 fija 30 dias calendario como tope cuando no hay plazo pactado,
/// y 15 dias para la devolucion del retracto. Poner aqui un plazo que no
/// coincide con el documento legal es una contradiccion que la SIC detecta.
class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.order, required this.emailQueued});

  final Order order;
  final bool emailQueued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Que sigue ahora',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        _Step(
          icon: Icons.check_circle_outline,
          text: emailQueued
              ? 'Te enviamos un correo con la confirmacion del pedido.'
              : 'Tu pedido quedo registrado en el sistema.',
        ),
        const SizedBox(height: 8),
        _Step(
          icon: Icons.local_shipping_outlined,
          text: 'Estamos preparando tu pedido con el proveedor.',
        ),
        const SizedBox(height: 8),
        _Step(
          icon: Icons.payments_outlined,
          text:
              'Pagas el total en efectivo al transportador cuando lo '
              'recibas.',
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin plazo pactado, tu pedido se entrega dentro de los 30 dias '
                  'calendario siguientes a la confirmacion.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}

/// El pedido se creo pero el proveedor de envio lo rechazo.
///
/// Es un estado real y frecuente en dropshipping: el backend crea el pedido y
/// guarda `status: "ERROR"` en el tracking cuando Dropi no acepta el envio. El
/// pedido existe y hay que decirlo con claridad, sin inventar que "ya va en
/// camino" ni esconderlo detras de una pantalla de exito.
class _ShippingProblemBox extends StatelessWidget {
  const _ShippingProblemBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                size: 20,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tu pedido se registro, pero el envio quedo pendiente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estamos gestionando el despacho con el proveedor. Tu pedido esta '
            'guardado y lo vas a recibir. Si necesitas una fecha exacta, '
            'escribenos con tu numero de pedido.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 1),
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Detalle del sistema: $message',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
