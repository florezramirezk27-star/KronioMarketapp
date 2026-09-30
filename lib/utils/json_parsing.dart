/// Helpers para leer campos del JSON del backend sin que un tipo inesperado
/// reviente la app.
///
/// El backend es NestJS + Prisma, asi que un campo numerico puede llegar como
/// numero, como string, o ausente segun la consulta. Estos helpers absorben las
/// tres variantes.
library;

/// Lee un valor como string no vacio.
String asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

/// Lee un valor como int. Acepta `12`, `12.0` y `"12"`.
int? asInt(dynamic value) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };

/// Lee un valor como double nullable. Acepta `12.5`, `"12.5"` y `null`.
double? asDoubleOrNull(dynamic value) => switch (value) {
      // `num` cubre `int` y `double`; el caso `double` seria inalcanzable.
      num v => v.toDouble(),
      String v => double.tryParse(v.trim()),
      _ => null,
    };

/// Lee un valor como double. Acepta `12.5`, `"12.5"` y `null` (devuelve
/// [fallback]).
double asDouble(dynamic value, {double fallback = 0}) =>
    asDoubleOrNull(value) ?? fallback;

/// Lee una lista de strings, descartando entradas vacias.
List<String> asStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

/// Convierte un valor monetario del backend a [double].
///
/// El backend manda el precio como string (`"269000"`), no como numero. Por
/// robustez tambien acepta numero, y ambos estilos de separador decimal
/// (`"1.234,56"` y `"1,234.56"`), eligiendo el que sea coherente en lugar de
/// normalizar a ciegas y convertir `"1.234"` en `1.234`.
double parseMoney(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();

  var raw = value.toString().trim();
  if (raw.isEmpty) return 0;

  // Fuera espacios y simbolos de moneda habituales.
  raw = raw.replaceAll(RegExp(r'[\s$€£]'), '');

  final hasComma = raw.contains(',');
  final hasDot = raw.contains('.');

  if (hasComma && hasDot) {
    // El separador que aparece mas a la derecha es el decimal.
    final decimalIndex = raw.lastIndexOf(',') > raw.lastIndexOf('.')
        ? raw.lastIndexOf(',')
        : raw.lastIndexOf('.');
    final thousandsSeparator = raw.lastIndexOf(',') > raw.lastIndexOf('.')
        ? '.'
        : ',';

    final integerPart =
        raw.substring(0, decimalIndex).replaceAll(thousandsSeparator, '');
    final decimalPart = raw.substring(decimalIndex + 1);
    raw = '$integerPart.$decimalPart';
  } else if (hasComma) {
    // "1234,56" -> decimal. "1,234" es ambiguo, pero en COP no se usan comas
    // como separador de miles, asi que se interpreta como decimal.
    raw = raw.replaceAll(',', '.');
  }

  return double.tryParse(raw) ?? 0;
}
