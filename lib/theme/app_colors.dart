import 'package:flutter/material.dart';

/// Paleta y tokens de marca de Kronio Market.
///
/// Fuente unica de verdad para los colores: la usan el tema, y se replican en
/// `web/manifest.json`, el splash nativo de Android/iOS y `web/index.html`.
class AppColors {
  const AppColors._();

  /// Naranja de marca (orange-600). Botones, AppBar activo, precio.
  static const Color primary = Color(0xFFEA580C);

  /// Naranja claro (orange-500). Gradientes.
  static const Color primaryLight = Color(0xFFF97316);

  /// Fondo de superficie en modo claro (orange-50).
  static const Color surfaceLight = Color(0xFFFFF7ED);

  /// Texto principal (gray-900).
  static const Color textPrimary = Color(0xFF111827);

  /// Texto secundario y placeholders (gray-600).
  static const Color textSecondary = Color(0xFF6B7280);

  /// Borde de tarjetas y separadores (gray-200).
  static const Color border = Color(0xFFE5E7EB);

  /// Semanticos.
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFEA580C);
}

/// Tipografia de la app.
///
/// No se declara ninguna familia de fuente personalizada: la app usa la fuente
/// por defecto de la plataforma, que respeta la preferencia del sistema.
///
/// Para sumar una familia (por ejemplo Geist) hay que:
///  1. Copiar los `.ttf` a `assets/fonts/`.
///  2. Declararlos en `pubspec.yaml` bajo `flutter: fonts:`.
///  3. Referenciar el nombre de familia en `fontFamily`.
///
/// Referenciar una familia no declarada NO lanza error: Flutter cae en
/// silencio a la fuente del sistema, asi que un typo es invisible.
class AppTypography {
  const AppTypography._();

  /// Familia de fuente global. `null` = fuente por defecto de la plataforma.
  static const String? fontFamily = null;
}
