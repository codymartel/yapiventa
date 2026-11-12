import '../../domain/models/pedido.dart';
import 'mensajes_accion_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextoEntregaPedido
// ═════════════════════════════════════════════════════════════════════════
// Cómo se lee la entrega de un pedido en su detalle:
//
//   Venta en tienda pedida antes  → «Recojo en tienda · vía WhatsApp»
//   Venta atendida en el local    → «En el local»
//   Recojo (web, ventas viejas de
//   Caja y «Para llevar»)         → «Recojo en tienda»
//   Delivery                      → «Av. Lima 123 · Centro (delivery 5,00)»
//
// Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextoEntregaPedido {
  static String de(Pedido pedido) {
    if (pedido.tipoEntrega == TipoEntrega.recojo) {
      final por = pedido.pedidoPor;
      if (por != null) return 'Recojo en tienda · vía ${por.etiqueta}';
      return pedido.enLocal ? 'En el local' : 'Recojo en tienda';
    }
    final lugar = [
      if (pedido.cliente.direccion.trim().isNotEmpty)
        pedido.cliente.direccion.trim(),
      if (pedido.zona.trim().isNotEmpty) pedido.zona.trim(),
    ].join(' · ');
    final delivery = pedido.deliveryCentavos > 0
        ? ' (delivery ${MensajesAccionPedido.dinero(pedido.deliveryCentavos)})'
        : '';
    return lugar.isEmpty ? 'Delivery$delivery' : '$lugar$delivery';
  }
}
