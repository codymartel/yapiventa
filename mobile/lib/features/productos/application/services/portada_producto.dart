import '../../domain/models/estructura_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// PortadaProducto
// ═════════════════════════════════════════════════════════════════════════
// La foto de un producto con modelos. Con variables NO hay "foto principal" y
// "fotos secundarias": cada modelo tiene la suya, obligatoria, y la portada
// (la que ven la lista del panel y la tienda) es la del primer modelo.
// Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
class PortadaProducto {
  PortadaProducto._();

  /// El modelo que da la portada: el primero que tiene foto. null si ninguno
  /// la tiene (productos sin modelos o modelos antiguos sin foto).
  static ModeloProducto? deModelos(List<ModeloProducto> modelos) {
    for (final modelo in modelos) {
      if (modelo.urlImagen.isNotEmpty) return modelo;
    }
    return null;
  }
}
