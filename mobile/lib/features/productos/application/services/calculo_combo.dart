import '../../domain/models/estructura_producto.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// CalculoCombo
// ═════════════════════════════════════════════════════════════════════════
// Lo que se calcula de un combo a partir de sus partes. El combo NO tiene
// stock propio: el stock vive en cada producto y aquí solo se mira. Todo en
// enteros, sin redondeos. Función pura, sin Flutter.
//
//   suma  = Σ precio de la parte × cantidad
//   stock = el menor de (stock de la parte ÷ cantidad), con piso
//           (una parte con stock infinito no limita; si todas lo son, el
//           combo tampoco).
// ═════════════════════════════════════════════════════════════════════════
class ResultadoCombo {
  const ResultadoCombo({
    this.sumaCentavos,
    this.stock,
    this.ilimitado = false,
    this.limita = '',
    this.sinDatos = false,
  });

  /// Lo que suman las partes (céntimos). null si falta algún producto.
  final int? sumaCentavos;

  /// Cuántos combos se pueden armar. null = sin límite o sin datos.
  final int? stock;

  /// Todas las partes tienen stock infinito.
  final bool ilimitado;

  /// Nombre de la parte que limita el stock («Gaseosa 500 ml»).
  final String limita;

  /// Falta algún producto de las partes (no se cargó o se borró).
  final bool sinDatos;

  bool get agotado => stock != null && stock! <= 0;
}

class CalculoCombo {
  CalculoCombo._();

  static ResultadoCombo calcular(
    List<ParteCombo> partes,
    Producto? Function(String productoId) buscar,
  ) {
    var suma = 0;
    var sinDatos = false;
    int? menor;
    var limita = '';

    for (final parte in partes) {
      if (parte.cantidad < 1) continue;
      final producto = buscar(parte.productoId);
      final fila = producto == null ? null : _fila(producto, parte);
      final conFilas = producto != null && producto.tieneModelos;
      if (producto == null || (conFilas && fila == null)) {
        sinDatos = true;
        continue;
      }
      final precio = fila?.precioCentavos ?? producto.precioCentavos;
      suma += _importe(producto, precio, parte.cantidad);

      final stock = _stock(producto, fila);
      if (stock == null) continue;
      final alcanza = stock ~/ parte.cantidad;
      if (menor == null || alcanza < menor) {
        menor = alcanza;
        limita = parte.nombre.isEmpty ? producto.nombre : parte.nombre;
      }
    }

    return ResultadoCombo(
      sumaCentavos: sinDatos ? null : suma,
      stock: sinDatos ? null : menor,
      ilimitado: !sinDatos && menor == null && partes.isNotEmpty,
      limita: limita,
      sinDatos: sinDatos,
    );
  }

  /// La fila elegida de un producto con variables; null si no la tiene.
  static FilaVenta? _fila(Producto producto, ParteCombo parte) {
    for (final modelo in producto.modelos) {
      if (modelo.id != parte.modeloId) continue;
      for (final fila in modelo.filas) {
        if (fila.id == parte.filaId) return fila;
      }
    }
    return null;
  }

  /// null = stock infinito (no limita). Una parte por medida se cuenta en su
  /// unidad BASE (g, ml...), igual que al descontar el stock en un pedido.
  static int? _stock(Producto producto, FilaVenta? fila) {
    if (producto.esStockInfinito) return null;
    if (producto.esPorMedida) {
      return fila == null ? producto.stockBase ?? 0 : fila.stockBase ?? 0;
    }
    return fila?.stock ?? producto.stock;
  }

  /// Lo que cuesta [cantidad] de una parte. Por medida, el precio es el de
  /// [cantidadReferenciaBase] unidades base: se divide hacia abajo, una vez.
  static int _importe(Producto producto, int precioCentavos, int cantidad) {
    if (!producto.esPorMedida) return precioCentavos * cantidad;
    final referencia = producto.cantidadReferenciaBase < 1
        ? 1
        : producto.cantidadReferenciaBase;
    return (precioCentavos * cantidad) ~/ referencia;
  }
}
