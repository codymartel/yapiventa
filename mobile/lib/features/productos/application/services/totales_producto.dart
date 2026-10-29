import '../../domain/models/estructura_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// TotalesProducto
// ═════════════════════════════════════════════════════════════════════════
// Los totales de un producto con modelos. SE CALCULAN, nunca se escriben a
// mano: el stock vive en las filas y el modelo solo muestra su suma (con
// candado en la pantalla). Todo en enteros. Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
class TotalesProducto {
  TotalesProducto._();

  /// El precio "desde": el menor entre las filas con precio. 0 si no hay.
  static int precioDesdeCentavos(List<ModeloProducto> modelos) {
    var desde = 0;
    for (final modelo in modelos) {
      for (final fila in modelo.filas) {
        if (fila.precioCentavos <= 0) continue;
        if (desde == 0 || fila.precioCentavos < desde) {
          desde = fila.precioCentavos;
        }
      }
    }
    return desde;
  }

  /// Suma del stock (unidades) de las filas de un modelo.
  static int stockDelModelo(ModeloProducto modelo) {
    return modelo.filas.fold(0, (suma, fila) => suma + fila.stock);
  }

  /// Suma del stock en unidad base (g, ml…) de las filas de un modelo.
  static int stockBaseDelModelo(ModeloProducto modelo) {
    return modelo.filas.fold(0, (suma, fila) => suma + (fila.stockBase ?? 0));
  }

  static int stockTotal(List<ModeloProducto> modelos) {
    return modelos.fold(0, (suma, modelo) => suma + stockDelModelo(modelo));
  }

  static int stockBaseTotal(List<ModeloProducto> modelos) {
    return modelos.fold(0, (suma, modelo) => suma + stockBaseDelModelo(modelo));
  }
}
