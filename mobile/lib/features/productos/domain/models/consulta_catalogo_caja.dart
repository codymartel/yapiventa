// ═════════════════════════════════════════════════════════════════════════
// ConsultaCatalogoCaja
// ═════════════════════════════════════════════════════════════════════════
// Lo que el cajero pide al catálogo de Caja: qué filtros y en qué orden. Se
// trae de 20 en 20 (las páginas siguientes llevan el cursor).
// ═════════════════════════════════════════════════════════════════════════

/// Frecuentes = los que más ventas tienen (en un negocio nuevo, los más
/// recientes); Recientes = los últimos creados; Nombre = de la A a la Z.
enum OrdenCatalogoCaja { frecuentes, recientes, nombre }

class ConsultaCatalogoCaja {
  const ConsultaCatalogoCaja({
    this.texto = '',
    this.tipo,
    this.categoria,
    this.orden = OrdenCatalogoCaja.frecuentes,
  });

  /// Lo escrito en el buscador. Con menos de 2 letras no filtra.
  final String texto;

  /// Uno de `CamposCatalogoProducto.tipos`, o null para todos.
  final String? tipo;

  /// La categoría exacta del producto, o null para todas.
  final String? categoria;

  /// Con texto, siempre se ordena por nombre (el orden elegido no se usa).
  final OrdenCatalogoCaja orden;
}
