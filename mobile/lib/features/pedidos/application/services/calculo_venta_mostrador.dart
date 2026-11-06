import '../../domain/models/descuento_pago.dart';
import '../../domain/models/linea_pedido.dart';
import 'verificacion_total_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// CalculoVentaMostrador
// ═════════════════════════════════════════════════════════════════════════
// La cuenta de una venta de Caja, en céntimos enteros y con las mismas
// fórmulas del pedido de la tienda:
//
//   línea     →  (precio + extras) × cantidad; por medida, precio × cantidad
//                ÷ referencia hacia abajo, UNA vez por línea
//   subtotal  →  suma de las líneas
//   descuento →  porcentaje: se redondea HACIA ARRIBA (a favor del cliente);
//                monto fijo: nunca más que el subtotal; solo desde el mínimo
//                y sobre el subtotal (el delivery no tiene descuento)
//   total     →  subtotal + delivery − descuento, nunca menor que 0
//
// Función pura, sin Flutter ni Firestore.
// ═════════════════════════════════════════════════════════════════════════
class VentaCalculada {
  const VentaCalculada({
    required this.lineas,
    required this.subtotalCentavos,
    required this.deliveryCentavos,
    required this.descuentoCentavos,
    required this.totalCentavos,
  });

  /// Las líneas con su subtotal ya calculado.
  final List<LineaPedido> lineas;
  final int subtotalCentavos;
  final int deliveryCentavos;
  final int descuentoCentavos;
  final int totalCentavos;
}

abstract final class CalculoVentaMostrador {
  /// 100 % en centésimas de punto: el tope de un descuento por porcentaje.
  static const int cienPorCiento = 10000;

  static VentaCalculada calcular({
    required List<LineaPedido> lineas,
    int deliveryCentavos = 0,
    DescuentoPago descuento = DescuentoPago.ninguno,
  }) {
    final delivery = deliveryCentavos < 0 ? 0 : deliveryCentavos;
    final conSubtotal = [
      for (final linea in lineas)
        if (linea.cantidad > 0)
          linea.copyWith(subtotalCentavos: CalculoPedido.subtotalLinea(linea)),
    ];
    final subtotal = CalculoPedido.subtotal(conSubtotal);
    final descuentoCentavos = descuentoDe(subtotal, descuento);
    return VentaCalculada(
      lineas: conSubtotal,
      subtotalCentavos: subtotal,
      deliveryCentavos: delivery,
      descuentoCentavos: descuentoCentavos,
      totalCentavos: CalculoPedido.total(
        subtotalCentavos: subtotal,
        deliveryCentavos: delivery,
        descuentoCentavos: descuentoCentavos,
      ),
    );
  }

  /// El descuento que corresponde a [subtotalCentavos] (nunca mayor que él).
  static int descuentoDe(int subtotalCentavos, DescuentoPago descuento) {
    if (subtotalCentavos <= 0) return 0;
    if (descuento.tipo == TipoDescuentoPago.ninguno || descuento.valor <= 0) {
      return 0;
    }
    if (subtotalCentavos < descuento.minimoCentavos) return 0;

    final bruto = switch (descuento.tipo) {
      TipoDescuentoPago.porcentaje => _porcentajeHaciaArriba(
        subtotalCentavos,
        descuento.valor > cienPorCiento ? cienPorCiento : descuento.valor,
      ),
      TipoDescuentoPago.montoFijo => descuento.valor,
      TipoDescuentoPago.ninguno => 0,
    };
    return bruto > subtotalCentavos ? subtotalCentavos : bruto;
  }

  /// subtotal × centésimas ÷ 10 000, redondeado hacia arriba una sola vez.
  static int _porcentajeHaciaArriba(int subtotalCentavos, int centesimas) {
    return (subtotalCentavos * centesimas + cienPorCiento - 1) ~/ cienPorCiento;
  }
}
