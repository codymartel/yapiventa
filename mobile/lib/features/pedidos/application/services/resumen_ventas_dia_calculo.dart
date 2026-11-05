import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/resumen_ventas_dia.dart';
import 'texto_lineas_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// ResumenVentasDiaCalculo
// ═════════════════════════════════════════════════════════════════════════
// Lo que se suma al resumen del día cuando un pedido se confirma o se entrega.
// Funciones puras: las usa el repositorio dentro de su transacción.
// ═════════════════════════════════════════════════════════════════════════
abstract final class ResumenVentasDiaCalculo {
  /// Cuántos entregados recientes guarda el resumen.
  static const int maximoRecientes = 5;

  /// Minutos que tardó en confirmarse (de la llegada a ahora). null si el
  /// pedido no tiene fecha todavía. Nunca negativo: un reloj atrasado no
  /// resta minutos al promedio.
  static int? minutosParaConfirmar(DateTime? llegada, DateTime ahora) {
    if (llegada == null) return null;
    final minutos = ahora.difference(llegada).inMinutes;
    return minutos < 0 ? 0 : minutos;
  }

  /// El registro que se guarda al entregar [pedido].
  static EntregadoReciente entregadoDe(Pedido pedido, DateTime ahora) {
    final cliente = pedido.cliente.nombre.trim();
    return EntregadoReciente(
      pedidoId: pedido.id,
      clave: pedido.clave,
      cliente: cliente.isEmpty ? 'Cliente' : cliente,
      productos: TextoLineasPedido.resumen(pedido.lineas),
      totalCentavos: pedido.totalCentavos,
      metodoPago: pedido.metodoPago.trim(),
      cobrado: pedido.estadoPago == EstadoPago.pagado,
      hora: ahora,
    );
  }

  /// [nuevo] va primero; si el mismo pedido ya estaba, se reemplaza; se guardan
  /// como máximo [maximoRecientes].
  static List<EntregadoReciente> conNuevoEntregado(
    List<EntregadoReciente> actuales,
    EntregadoReciente nuevo,
  ) {
    return [
      nuevo,
      for (final e in actuales)
        if (e.pedidoId != nuevo.pedidoId) e,
    ].take(maximoRecientes).toList();
  }
}
