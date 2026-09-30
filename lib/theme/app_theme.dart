import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema de Kronio Market.
///
/// Se generan las dos variantes (claro y oscuro) desde la misma funcion para que
/// no se desincronicen. `ThemeMode.system` en `MaterialApp` deja que el sistema
/// operativo decida.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight
          ? AppColors.surfaceLight
          : const Color(0xFF17130F),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? Colors.white : const Color(0xFF1F1A16),
        foregroundColor: isLight
            ? AppColors.textPrimary
            : const Color(0xFFF9FAFB),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isLight ? AppColors.textPrimary : const Color(0xFFF9FAFB),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: AppTypography.fontFamily,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          // Minimo 48dp para cumplir el objetivo tactil de Material.
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 48),
        ),
      ),
      // Chrome por defecto de Material 3: mucho mas consistente entre
      // plataformas que los defaults legacy.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.surfaceLight
            : Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? Colors.white
            : Colors.white.withValues(alpha: 0.08),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isLight ? AppColors.textPrimary : const Color(0xFFF9FAFB),
        ),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      // `floating` hace que varios SnackBars simultaneos se apilen en lugar de
      // pisarse entre si, y los saca de la barra de navegacion inferior.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xFF111827)
            : const Color(0xFF374151),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
