// ═════════════════════════════════════════════════════════════════════════
// Categorias
// ═════════════════════════════════════════════════════════════════════════
// Migración de tu `object Categorias`. Mismos rubros y valores que tu
// Kotlin, EXCEPTO:
//   - Se QUITÓ "Tecnología" (descartado en la investigación de mercado)
//   - Se AGREGÓ "Ferretería" — categorías investigadas con fuentes reales
//     (Pulpos, Prolyam, Apiworking): Herramientas, Materiales de
//     Construcción, Eléctricos, Plomería, Pinturas, Tornillería.
//     Ver conversación para las citas completas.
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
    'Farmacia': [
      'Medicamentos',
      'Vitaminas',
      'Higiene Personal',
      'Bebés',
      'Primeros Auxilios',
    ],
    'Restaurante': [
      'Entradas',
      'Platos de fondo',
      'Bebidas',
      'Postres',
      'Menú del día',
    ],
    'Ropa': [
      'Hombre',
      'Mujer',
      'Niños',
      'Accesorios',
      'Calzado',
    ],
    // NUEVO — reemplaza a "Tecnología". Categorías investigadas con
    // fuentes reales (Pulpos, Prolyam, Apiworking): la categorización
    // operativa que usan ferreterías reales, organizada por tipo de uso,
    // no por marca.
    'Ferretería': [
      'Herramientas',
      'Materiales de Construcción',
      'Eléctricos',
      'Plomería',
      'Pinturas',
      'Tornillería',
    ],
    'Otros': [
      'General',
    ],
  };

  /// Equivale a `Categorias.obtener(rubro)`.
  static List<String> obtener(String rubro) {
    return porRubro[rubro] ?? const ['General'];
  }
}