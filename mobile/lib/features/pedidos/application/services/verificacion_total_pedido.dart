import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../domain/models/linea_pedido.dart';
import '../../domain/models/pedido.dart';
import 'calculo_stock_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// CalculoPedido · VerificacionTotal
// ═════════════════════════════════════════════════════════════════════════
// La cuenta de un pedido, en céntimos enteros y con las mismas fórmulas de la
// tienda:
//
//   se cuenta  →  (precio + extras) × cantidad
//   por medida →  precio × cantidad ÷ referencia, hacia abajo (a favor del
//                 cliente), UNA sola vez por línea
//   total      →  subtotal + delivery − descuento (nunca menor que 0)
//
// El pedido llega de una tienda pública anónima: las reglas de Firestore no
// pueden comprobar el total, así que el panel lo recalcula con los precios
// ACTUALES al confirmar y avisa si no coincide (VerificacionTotal).
// Función pura, sin Flutter ni Firestore.
// ═════════════════════════════════════════════════════════════════════════
class VerificacionTotal {
  const VerificacionTotal({
    required this.totalGuardadoCentavos,
    required this.totalActualCentavos,
    this.lineasCambiadas = const [],
    this.sinProducto = const [],
  });

  final int totalGuardadoCentavos;
  final int totalActualCentavos;

  /// Líneas cuyo precio de hoy no da el subtotal guardado.
  final List<String> lineasCambiadas;

  /// Líneas cuyo producto ya no existe: se conserva su precio guardado.
  final List<String> sinProducto;

  bool get difiere => totalGuardadoCentavos != totalActualCentavos;
}

abstract final class CalculoPedido {
  static int subtotalLinea(LineaPedido linea) {
    if (linea.porMedida) {
      final referencia = linea.cantidadReferencia < 1
          ? 1
          : linea.cantidadReferencia;
      return (linea.precioCentavos * linea.cantidad) ~/ referencia;
    }
    var extras = 0;
    for (final extra in linea.extras) {
      extras += extra.precioCentavos;
    }
    return (linea.precioCentavos + extras) * linea.cantidad;
  }

  static int subtotal(List<LineaPedido> lineas) {
    var suma = 0;
    for (final linea in lineas) {
      suma += subtotalLinea(linea);
    }
    return suma;
  }

  static int total({
    required int subtotalCentavos,
    int deliveryCentavos = 0,
    int descuentoCentavos = 0,
  }) {
    final total = subtotalCentavos + deliveryCentavos - descuentoCentavos;
    return total < 0 ? 0 : total;
  }

  /// Recalcula el pedido con los precios de hoy. [buscar] entrega el producto
  /// (ya leído) o null si no existe.
  static VerificacionTotal verificar(
    Pedido pedido,
    Producto? Function(String productoId) buscar,
  ) {
    final cambiadas = <String>[];
    final sinProducto = <String>[];
    var subtotalActual = 0;

    for (final linea in pedido.lineas) {
      final guardada = subtotalLinea(linea);
      final producto = buscar(linea.productoId);
      final actual = producto == null
          ? null
          : _conPreciosDeHoy(linea, producto);
      if (actual == null) {
        sinProducto.add(linea.nombre);
        subtotalActual += guardada;
        continue;
      }
      final nuevo = subtotalLinea(actual);
      if (nuevo != guardada) cambiadas.add(linea.nombre);
      subtotalActual += nuevo;
    }

    return VerificacionTotal(
      totalGuardadoCentavos: pedido.totalCentavos,
      totalActualCentavos: total(
        subtotalCentavos: subtotalActual,
        deliveryCentavos: pedido.deliveryCentavos,
        descuentoCentavos: pedido.descuentoCentavos,
      ),
      lineasCambiadas: cambiadas,
      sinProducto: sinProducto,
    );
  }

  /// La línea con el precio vigente del producto; null si su fila ya no existe.
  static LineaPedido? _conPreciosDeHoy(LineaPedido linea, Producto producto) {
    var precio = producto.precioCentavos;
    if (producto.tieneModelos && !producto.esCombo) {
      final fila = CalculoStockPedido.filaDe(
        producto,
        linea.modeloId,
        linea.filaId,
      );
      if (fila == null) return null;
      precio = fila.precioCentavos;
    }
    return linea.copyWith(
      precioCentavos: precio,
      cantidadReferencia: linea.porMedida
          ? producto.cantidadReferenciaBase
          : null,
    );
  }
}
