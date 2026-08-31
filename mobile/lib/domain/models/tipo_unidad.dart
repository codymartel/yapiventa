// ═════════════════════════════════════════════════════════════════════════
// TipoUnidad + UnidadInfo
// ═════════════════════════════════════════════════════════════════════════
// Migración directa de tu Kotlin: enum TipoUnidad + data class UnidadInfo.
// Sin cambios de lógica, solo sintaxis Dart.
// ═════════════════════════════════════════════════════════════════════════

/// Equivale a tu `enum class TipoUnidad`.
enum TipoUnidad {
  /// Permite decimales (ej. 1.5 kg, 0.25 galón, 0.5 docena)
  fraccionaria,

  /// Solo enteros (ej. 2 unidades, 3 pares)
  entera,
}

/// Equivale a tu `data class UnidadInfo`.
class UnidadInfo {
  final String nombre;
  final TipoUnidad tipo;
  final List<String> fraccionesPermitidas;

  /// true = unidad rara, se puede colapsar en la UI (mismo uso que en Kotlin).
  final bool esOpcional;

  const UnidadInfo({
    required this.nombre,
    required this.tipo,
    this.fraccionesPermitidas = const [],
    this.esOpcional = false,
  });
}