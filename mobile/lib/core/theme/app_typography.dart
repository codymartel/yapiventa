import 'package:flutter/material.dart';

/// Estilos compartidos de la jerarquía visual superior del dashboard.
///
/// Antes cada módulo escribía su propio `fontSize` (había 16 tamaños distintos
/// para el mismo peso semántico). Aquí viven los tres niveles que TODOS los
/// encabezados de pantalla deben usar, para que Inicio, Productos, Plantilla
/// web, Configuración y Rubro compartan la misma jerarquía.
///
/// Ningún estilo fija color: cada módulo conserva su paleta (los módulos de
/// onboarding usan un fondo propio) y solo comparte tamaño, peso y ritmo.
class AppTypography {
  AppTypography._();

  /// Antetítulo en versalitas. Opcional: solo los onboarding lo usan.
  static const TextStyle screenEyebrow = TextStyle(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
  );

  /// Título principal de pantalla.
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  /// Subtítulo que explica la pantalla.
  static const TextStyle screenSubtitle = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  /// Nombre del negocio en la barra superior: discreto a propósito, porque la
  /// marca ya está en el sidebar y el título de la pantalla va debajo.
  static const TextStyle topBarBusiness = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
}
