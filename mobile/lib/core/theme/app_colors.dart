import 'package:flutter/material.dart';

/// Paleta SeguriVent — migrada 1:1 de las constantes `svFondo`, `svSuperficie`,
/// etc. que tenías en LoginScreen.kt. Ahora vive en un solo lugar (core/theme)
/// para que TODAS las features la usen, no solo auth.
class AppColors {
  AppColors._(); // evita que alguien haga AppColors() por accidente

  static const fondo = Color(0xFF070C18);
  static const superficie = Color(0xFF0D1526);
  static const card = Color(0xFF111D33);
  static const navy = Color(0xFF1A3A6E);
  static const blue = Color(0xFF2457B3);
  static const blueLt = Color(0xFF3D72D4);
  static const texto = Color(0xFFE8EDF5);
  static const muted = Color(0xFF5B6E8C);
  static const dim = Color(0xFF2A3A55);
  static const error = Color(0xFFEF4444);

  // En Kotlin usabas .copy(alpha = 0.18f). En Flutter es .withValues(alpha: ...)
  static Color border = blueLt.withValues(alpha: 0.18);
}