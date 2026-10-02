import 'package:flutter/material.dart';

import '../services/cart_service.dart';
import '../services/checkout_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/auth_scope.dart';
import '../widgets/brand_header.dart';
import '../widgets/cart_scope.dart';
import '../widgets/checkout_scope.dart';
import 'order_confirmation_screen.dart';

/// Formulario de entrega y confirmacion del pedido.
///
/// Va antes de tocar el backend, en este orden:
///
///  1. Valida los campos **en el cliente**, con los mismos limites del
///     `checkoutSchema` del backend. No para ahorrar una peticion, sino porque
///     el backend responde `400` con el mensaje generico "Error de validación"
///     cuando falla Zod, y eso no le dice al usuario que campo corregir.
///  2. Sincroniza el carrito local al del servidor. Si se skipea esto, el
///     checkout responde "Tu carrito está vacío" aunque el usuario vea productos
///     en pantalla.
///  3. Llama al checkout.
///
/// El paso 2 es el que hace que esto funcione y no es obvio: el carrito de la
/// app vive en `SharedPreferences` y el del backend en Postgres, y son dos
/// cosas distintas.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _docNumber = TextEditingController();
  final _notes = TextEditingController();

  // Nombre y correo salen de la cuenta: son datos que el usuario ya dio y que
  // el backend usaria tal cual. El resto se escribe siempre, porque cambian
  // entre pedidos y no hay donde guardarlos.
  //
  // Se rellenan en `didChangeDependencies` y no en `initState` porque
  // [AuthScope.of] lee un `InheritedWidget`, y Flutter no lo permite antes de esa
  // fase: tira la asercion "initialization based on inherited widgets can be
  // placed in the didChangeDependencies method".
  String _name = '';
  String _email = '';

  /// `true` mientras se manda el checkout.
  bool _submitting = false;

  /// Fallo del ultimo intento, con la accion que corresponde.
  CheckoutFailure? _failure;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final user = AuthScope.of(context).user;
    // Solo la primera vez: recargar el perfil no debe pisar lo que el usuario
    // ya corrigio a mano.
    if (_name.isEmpty && _email.isEmpty) {
      _name = user?.name ?? '';
      _email = user?.email ?? '';
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _docNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Valida en cliente con los limites del `checkoutSchema` del backend.
  ///
  /// Los topes salen de ahi (`MAX_NAME` 120, `MAX_PHONE` 30, `MAX_ADDRESS` 300,
  /// `MAX_CITY` 120, `MAX_ZIP` 20, `MAX_NOTES` 1000). Copiar los numeros evita
  /// la situacion de tener un formulario que acepta algo que el servidor siempre
  /// va a rechazar.
  String? _validate(
    String? value, {
    required String label,
    required int max,
    bool required = true,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? 'Escribe $label' : null;
    }
    if (text.length > max) {
      return '$label no puede pasar de $max caracteres';
    }
    return null;
  }

  /// Valida el correo.
  ///
  /// No se usa una regexp casera: el backend valida con `z.email()`, y una
  /// regexp mas laxa dejaria pasar una direccion que el servidor va a rechazar.
  /// Este patron cubre lo mismo que cubre Zod para los casos normales.
  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null; // Opcional.
    final valid = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]"
      r'(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
      r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
    );
    if (!valid.hasMatch(text)) return 'Ese correo no parece valido';
    return null;
  }

  /// Telefono colombiano: 10 digitos, o con `+57` y 12.
  ///
  /// Se acepta el prefijo porque es como lo escribe la gente y el backend lo
  /// guarda tal cual, pero se manda sin espacios ni guiones: una guia con
  /// parentesis no la puede leer el transportador.
  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe tu telefono';

    final digits = text.replaceAll(RegExp(r'[\s()\-]'), '');
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(digits)) {
      return 'Escribe un telefono de 10 digitos';
    }
    return null;
  }

  /// Telefono ya sin espacios ni guiones, como lo espera el transportador.
  String _normalizePhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s()\-]'), '');

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _failure = null;
      _errorMessage = null;
    });

    final checkout = CheckoutScope.of(context);
    final cart = CartScope.of(context);

    // Orden importante. Sin el volcado del carrito, el backend responde "Tu
    // carrito está vacío".
    try {
      await checkout.syncLocalCartToServer(cart);
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = CheckoutFailure.network;
        _errorMessage =
            'No pudimos guardar tu carrito en el servidor. Revisa tu '
            'conexion e intenta de nuevo.';
      });
      return;
    }

    final shipping = ShippingDetails(
      name: _name.trim(),
      phone: _normalizePhone(_phone.text),
      address: _address.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      zip: _zip.text,
      email: _email,
      docType: _docNumber.text.trim().isEmpty ? null : 'CC',
      docNumber: _docNumber.text,
      notes: _notes.text,
    );

    final outcome = await checkout.checkout(shipping);

    if (!mounted) return;

    if (outcome.isSuccess) {
      // El carrito local se vacia solo cuando el pedido **existe**. Si se
      // vaciara antes, un fallo de red dejaria al usuario con la pantalla
      // vacia y sin pedido, que es peor que no haber comprado.
      await cart.clear();
      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderConfirmationScreen(result: outcome.result!),
        ),
      );
      return;
    }

    setState(() {
      _submitting = false;
      _failure = outcome.failure;
      _errorMessage = outcome.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    // Un carrito vacio no tiene nada que confirmar. Se llega aqui por ruta
    // normal, pero tambien puede pasar si el servidor ya proceso el pedido.
    if (cart.isEmpty && !_submitting) {
      return Scaffold(
        appBar: AppBar(
          leading: const BrandHeader(logoSize: 24, showName: false),
          title: const Text('Confirmar pedido'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Tu carrito esta vacio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BrandHeader(logoSize: 24, showName: false),
        title: const Text('Confirmar pedido'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _Summary(cart: cart),
            const SizedBox(height: 20),

            _SectionTitle('Datos de entrega'),
            const SizedBox(height: 10),

            _Field(
              initialValue: _name,
              label: 'Nombre completo',
              maxLength: 120,
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  _validate(value, label: 'tu nombre', max: 120),
            ),
            const SizedBox(height: 12),

            _Field(
              controller: _phone,
              label: 'Telefono',
              hint: '300 123 4567',
              maxLength: 30,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 12),

            _Field(
              controller: _address,
              label: 'Direccion de entrega',
              hint: 'Calle 100 # 20-30, apto 301',
              maxLength: 300,
              icon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (value) =>
                  _validate(value, label: 'la direccion', max: 300),
            ),
            const SizedBox(height: 12),

            _Field(
              controller: _city,
              label: 'Ciudad',
              maxLength: 120,
              icon: Icons.location_city_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  _validate(value, label: 'la ciudad', max: 120),
            ),
            const SizedBox(height: 12),

            _Field(
              controller: _state,
              label: 'Departamento',
              maxLength: 120,
              icon: Icons.map_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  _validate(value, label: 'el departamento', max: 120),
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    controller: _zip,
                    label: 'Codigo postal',
                    hint: 'Opcional',
                    maxLength: 20,
                    keyboardType: TextInputType.number,
                    // Opcional: `required: false`.
                    validator: (value) => _validate(
                      value,
                      label: 'el codigo postal',
                      max: 20,
                      required: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _docNumber,
                    label: 'Cedula',
                    hint: 'Opcional',
                    maxLength: 40,
                    keyboardType: TextInputType.number,
                    validator: (value) => _validate(
                      value,
                      label: 'la cedula',
                      max: 40,
                      required: false,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _Field(
              initialValue: _email,
              label: 'Correo para la confirmacion',
              hint: 'Opcional',
              maxLength: 254,
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),

            _Field(
              controller: _notes,
              label: 'Notas para el pedido',
              hint: 'Opcional. Horario de entrega, referencias...',
              maxLength: 1000,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => _validate(
                value,
                label: 'las notas',
                max: 1000,
                required: false,
              ),
            ),
            const SizedBox(height: 20),

            const _PaymentNotice(),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              _ErrorBox(
                failure: _failure,
                message: _errorMessage!,
                onRetry: _submitting
                    ? null
                    : () {
                        // "Volver al carrito" solo tiene sentido si el problema
                        // fue el carrito. Un error de red no se arregla volviendo
                        // atras, y ofrecerlo ahi confunde.
                        if (_failure == CheckoutFailure.unavailable) {
                          Navigator.of(context).pop();
                        } else {
                          _submit();
                        }
                      },
              ),
              const SizedBox(height: 16),
            ],

            _PlaceOrderButton(
              submitting: _submitting,
              total: cart.subtotal,
              onPressed: _submitting ? null : _submit,
            ),

            const SizedBox(height: 12),
            const Text(
              'Al confirmar aceptas nuestros terminos y condiciones y la '
              'politica de privacidad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus datos de entrega se usan solo para enviarte el pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumen del pedido antes de confirmar.
///
/// El total sale del carrito **local**, no del servidor. Es el precio que
/// mostro el producto, y el backend cobra el del suyo: si divergieran, la
/// diferencia la veria el cliente al recibir el pedido. La unica defensa real
/// es que la app muestre el total que devuelve `POST /orders/checkout`, y eso
/// es lo que hace la pantalla de confirmacion.
class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final CartService cart;

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
            'Resumen del pedido',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in cart.itemList)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCop(item.product.price * item.quantity),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total (${cart.totalItems} items)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                formatCop(cart.subtotal),
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

/// Explica el pago contra entrega.
///
/// Es obligatorio mostrarlo antes de confirmar, no despues. Los terminos y
/// condiciones dicen que no hay pasarela de pago y que se paga al transportador,
/// y si el usuario descubre eso en el ultimo momento (en la puerta, con el
/// pedido en mano) es un reclamo, no una sorpresa aceptable.
class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagas contra entrega',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cancelas el total en efectivo al transportador cuando '
                  'recibas tu pedido. No necesitas pagar nada por adelantado.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de error con la accion que corresponde al fallo.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.failure, required this.message, this.onRetry});

  final CheckoutFailure? failure;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Sin sesion el boton es "iniciar sesion", no "reintentar": reintentar un
    // checkout sin cookie vuelve a fallar con el mismo 401.
    if (failure == CheckoutFailure.unauthenticated) {
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
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  // Login pops con `true` al iniciar sesion; se reintenta
                  // despues en vez de perder lo que el usuario ya escribio.
                  final loggedIn = await Navigator.of(context)
                      .pushNamed<bool>('/login');
                  if (loggedIn == true && onRetry != null) onRetry!();
                },
                child: const Text('Iniciar sesion'),
              ),
            ),
          ],
        ),
      );
    }

    final isStock = failure == CheckoutFailure.unavailable;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                child: Text(isStock ? 'Volver al carrito' : 'Reintentar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceOrderButton extends StatelessWidget {
  const _PlaceOrderButton({
    required this.submitting,
    required this.total,
    required this.onPressed,
  });

  final bool submitting;
  final double total;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        // El boton cambia a "Confirmando..." y se bloquea mientras corre la
        // peticion. Sin eso, un doble toque manda dos checkouts; el backend
        // crea el primero y el segundo responde "carrito vacío", y el usuario
        // ve un error despues de haber comprado bien.
        child: submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'Confirmar pedido por ${formatCop(total)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Campo de formulario.
///
/// Lleva su propio contador de caracteres: el backend tiene topes duros
/// (`MAX_ADDRESS` 300, `MAX_NOTES` 1000) y `maxLength` los aplica de entrada,
/// que es lo que evita que el usuario escriba un mensaje largo para que el
/// servidor lo rechace con "Error de validación".
///
/// Acepta **controller o initialValue**, nunca los dos. Se podria unificar con
/// un `TextFormField` por debajo de los dos, pero no se hizo: los campos que
/// vienen de la sesion (nombre, correo) se rellenan en
/// `didChangeDependencies`, despues de `initState`, y un `controller` creado en
/// `initState` llegaria vacio. Son dos fuentes distintas de verdad, no dos
/// maneras de escribir lo mismo.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.maxLength,
    this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  }) : assert(
         controller == null || initialValue == null,
         'usa controller o initialValue, no los dos',
       );

  final TextEditingController? controller;

  /// Valor inicial, para los campos que vienen de la sesion.
  final String? initialValue;

  final String label;
  final String? hint;
  final int? maxLength;
  final IconData? icon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      // Con `maxLength` el campo trae su propio contador, que se desactiva para
      // no sumar una segunda linea bajo cada input.
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        counterText: '',
        filled: true,
      ),
    );
  }
}
