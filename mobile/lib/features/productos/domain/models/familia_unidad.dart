// ═════════════════════════════════════════════════════════════════════════
// FamiliaUnidad
// ═════════════════════════════════════════════════════════════════════════
// Familia física a la que pertenece una cantidad. Fase 1 del dominio de
// cantidades. Solo conteo puede convivir con ModoVenta.presentacion; el
// resto de familias se usa con ModoVenta.medida.
// ═════════════════════════════════════════════════════════════════════════
enum FamiliaUnidad {
  /// Se cuenta en unidades enteras (también sirve pares, docenas...).
  conteo,

  /// Peso. Internamente se representa siempre en gramos.
  peso,

  /// Volumen. Internamente se representa siempre en mililitros.
  volumen,

  /// Longitud. Internamente se representa siempre en milímetros.
  longitud,

  /// Superficie. Internamente se representa siempre en centímetros cuadrados.
  area,
}
