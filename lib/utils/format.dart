import 'package:intl/intl.dart';

/// Formatea un monto en pesos colombianos: `$ 269.000`.
///
/// Usa [intl] en vez de contar digitos a mano. La version anterior partia el
/// numero en caracteres y colocaba el separador cada 3 posiciones desde la
/// derecha, lo que rompia con negativos (`-5000` -> `-.5000`) y truncaba los
/// decimales sin avisar.
///
/// El simbolo va delante, como es la convencion en Colombia. Por eso se arma el
/// string a mano en vez de usar `NumberFormat.currency`, que en `es_CO` coloca
/// la moneda despues (`269.000 $`).
///
/// [withDecimals] muestra los centavos cuando el monto los tiene. Por defecto se
/// omiten porque en COP casi todo el mundo redondea.
String formatCop(num value, {bool withDecimals = false}) {
  final isNegative = value < 0;
  final formatter = NumberFormat(
    withDecimals ? '#,##0.00' : '#,##0',
    'es_CO',
  );
  // El signo va delante del simbolo (`-$ 5.000`), no entre el simbolo y el
  // numero (`$ -5.000`).
  final sign = isNegative ? '-' : '';
  return '$sign\$ ${formatter.format(value.abs())}';
}

/// Formatea un entero con separadores de miles: `1,234`.
String formatCount(num value) => NumberFormat.decimalPattern('es_CO').format(value);