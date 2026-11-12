import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Tema de la app. Hoy solo existe el oscuro; el claro entra después sobre
/// los mismos tokens de [AppColors]. Solo fija lo que antes cada pantalla
/// repetía (fondo, diálogos, tarjetas, campos); las pantallas que ya definen
/// su propio estilo lo conservan.
class AppTheme {
  AppTheme._();

  static ThemeData get oscuro {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fondo,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.blue,
        onPrimary: Colors.white,
        secondary: AppColors.blueLt,
        surface: AppColors.superficie,
        onSurface: AppColors.texto,
        error: AppColors.error,
        outline: AppColors.border,
      ),
      // Los avisos flotan sobre el contenido: pegados abajo tapaban los
      // botones fijos de las hojas y de las listas.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: AppColors.bordeSutil, space: 1),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.bordeSutil),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.bordeMedio),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.hint),
        errorStyle: TextStyle(color: AppColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTactil),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTactil),
        ),
      ),
    );
  }
}
