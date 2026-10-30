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
  static const muted = Color(0xFF9AA9C2);

  /// Solo para bordes y rellenos. Sobre el fondo da 1,7:1: NUNCA como texto
  /// (para textos de ayuda y placeholders usar [hint]).
  static const dim = Color(0xFF2A3A55);

  /// Texto de ayuda y placeholders: 5,3:1 sobre [card], 6,1:1 sobre [fondo].
  static const hint = Color(0xFF8191AA);

  /// Azul legible como texto o precio (7,9:1 sobre [card]). [blue] y [blueLt]
  /// quedan para fondos de botón y bordes.
  static const azulTexto = Color(0xFF8AB2FF);

  static const error = Color(0xFFF87171);
  static const ok = Color(0xFF4ADE80);

  /// Ámbar de los avisos que no bloquean: "Falta: …", equivalencias dudosas.
  static const aviso = Color(0xFFFBBF24);

  // En Kotlin usabas .copy(alpha = 0.18f). En Flutter es .withValues(alpha: ...)
  static Color border = blueLt.withValues(alpha: 0.45);

  // Niveles "sutil" y "medio" del mismo azul: los usa el rediseño de las
  // superficies nuevas (formularios, paneles, barra de acciones) donde un
  // borde al 45% satura la pantalla. No reemplazan a [border], que sigue
  // intacto para las superficies que ya lo usaban.
  static Color bordeSutil = blueLt.withValues(alpha: 0.14);
  static Color bordeMedio = blueLt.withValues(alpha: 0.30);
}