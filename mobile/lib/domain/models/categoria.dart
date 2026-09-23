// ═════════════════════════════════════════════════════════════════════════
// Categorias
// ═════════════════════════════════════════════════════════════════════════
// Catálogo inicial por rubro. Los rubros legacy conservan su valor almacenado,
// pero cargan el preset seguro de "Otros".
// ═════════════════════════════════════════════════════════════════════════

class Categorias {
  Categorias._();

  static const Map<String, List<String>> porRubro = {
    'Bodega': [
      'Abarrotes',
      'Bebidas',
      'Lácteos',
      'Limpieza',
      'Snacks',
      'Panadería',
    ],
    'Restaurante': [
      'Entradas',
      'Platos de fondo',
      'Bebidas',
      'Postres',
      'Menú del día',
    ],
    'Ropa': ['Hombre', 'Mujer', 'Niños', 'Accesorios', 'Calzado'],
    'Accesorios y regalos': ['General'],
    'Belleza y cuidado personal': ['General'],
    'Otros': ['General'],
  };

  /// Equivale a `Categorias.obtener(rubro)`.
  static List<String> obtener(String rubro) {
    final rubroPreset = rubro == 'Farmacia' || rubro == 'Ferretería'
        ? 'Otros'
        : rubro;
    return porRubro[rubroPreset] ?? const ['General'];
  }
}
