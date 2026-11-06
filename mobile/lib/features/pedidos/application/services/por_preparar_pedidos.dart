import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'texto_lineas_pedido.dart';

/// Un producto (con su modelo y fila) y cuánto hay que preparar en total.
class ItemPorPreparar {
  const ItemPorPreparar({
    required this.nombre,
    required this.cantidad,
    required this.porMedida,
  });

  final String nombre;

  /// Unidades, o unidad base (g, ml…) si se vende por medida.
  final int cantidad;
  final bool porMedida;

  /// «×2» o «350».
  String get cantidadTexto => porMedida ? '$cantidad' : '×$cantidad';
}

// ═════════════════════════════════════════════════════════════════════════
// PorPrepararPedidos
// ═════════════════════════════════════════════════════════════════════════
// «Por preparar ahora»: la suma de lo pedido en los pedidos nuevos y
// confirmados YA cargados (los que ya salieron no hay que prepararlos). Todo
// en enteros. Un producto por modelo y fila, ordenado por nombre. Pura.
// ═════════════════════════════════════════════════════════════════════════
abstract final class PorPrepararPedidos {
  static List<ItemPorPreparar> sumar(Iterable<Pedido> pedidos) {
    final porClave = <String, ItemPorPreparar>{};
    for (final pedido in pedidos) {
      if (pedido.estado != EstadoPedido.nuevo &&
          pedido.estado != EstadoPedido.confirmado) {
        continue;
      }
      for (final linea in pedido.lineas) {
        final clave = '${linea.productoId}|${linea.modeloId}|${linea.filaId}';
        final anterior = porClave[clave];
        porClave[clave] = ItemPorPreparar(
          nombre: TextoLineasPedido.nombre(linea),
          cantidad: (anterior?.cantidad ?? 0) + linea.cantidad,
          porMedida: linea.porMedida,
        );
      }
    }
    return porClave.values.toList()..sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
  }
}
