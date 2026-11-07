import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// TransicionesPedido
// ═════════════════════════════════════════════════════════════════════════
// Qué sigue después de cada estado, qué botón se muestra y qué se puede
// hacer. Reglas puras, sin Flutter ni Firestore.
//
//   nuevo → confirmado → listo (recojo) | enCamino (delivery) → entregado
//
// Se cancela solo estando nuevo o confirmado (después el producto ya salió).
// Una venta de Caja ya entregada se anula (devuelve el stock y resta del día).
// Pasar de nuevo a confirmado es lo único que mueve stock.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TransicionesPedido {
  /// Horas sin confirmar a partir de las cuales un pedido nuevo se marca vencido.
  static const int horasParaVencer = 12;

  /// El estado que sigue, o null si ya no hay (entregado o cancelado).
  static EstadoPedido? siguiente(EstadoPedido estado, TipoEntrega entrega) {
    return switch (estado) {
      EstadoPedido.nuevo => EstadoPedido.confirmado,
      EstadoPedido.confirmado =>
        entrega == TipoEntrega.recojo
            ? EstadoPedido.listo
            : EstadoPedido.enCamino,
      EstadoPedido.enCamino || EstadoPedido.listo => EstadoPedido.entregado,
      EstadoPedido.entregado || EstadoPedido.cancelado => null,
    };
  }

  /// Texto del botón principal; vacío si no hay siguiente paso.
  static String etiquetaBoton(EstadoPedido estado, TipoEntrega entrega) {
    return switch (estado) {
      EstadoPedido.nuevo => 'Confirmar pedido',
      EstadoPedido.confirmado =>
        entrega == TipoEntrega.recojo
            ? 'Listo para recoger'
            : 'Enviar a domicilio',
      EstadoPedido.enCamino || EstadoPedido.listo => 'Marcar entregado',
      EstadoPedido.entregado || EstadoPedido.cancelado => '',
    };
  }

  /// Solo hasta confirmado: después el producto ya salió.
  static bool puedeCancelar(EstadoPedido estado) {
    return estado == EstadoPedido.nuevo || estado == EstadoPedido.confirmado;
  }

  /// Anular es para lo que YA se entregó, y solo en ventas registradas en
  /// Caja. Un pedido de la tienda entregado no se anula. (Lo que sigue en
  /// proceso se cancela, ver [puedeCancelar].)
  static bool puedeAnular(Pedido pedido) {
    return pedido.estado == EstadoPedido.entregado &&
        pedido.origen == OrigenPedido.mostrador;
  }

  /// Cobrar se puede marcar hasta después de entregar (pago contra entrega).
  static bool puedeCambiarPago(EstadoPedido estado) {
    return estado != EstadoPedido.cancelado;
  }

  /// true cuando el paso descuenta stock (solo nuevo → confirmado).
  static bool descuentaStock(EstadoPedido desde, EstadoPedido hacia) {
    return desde == EstadoPedido.nuevo && hacia == EstadoPedido.confirmado;
  }

  /// Cancelado que ya estaba pagado: el vendedor debe devolver el dinero.
  static EstadoReembolso reembolsoAlCancelar(Pedido pedido) {
    return pedido.estadoPago == EstadoPago.pagado
        ? EstadoReembolso.pendiente
        : EstadoReembolso.ninguno;
  }

  static bool puedeMarcarReembolsoHecho(Pedido pedido) {
    return pedido.estado == EstadoPedido.cancelado &&
        pedido.reembolso == EstadoReembolso.pendiente;
  }

  /// Nuevo y con más de [horasParaVencer] horas sin confirmar. Sin fecha
  /// (todavía escribiéndose) no se considera vencido.
  static bool estaVencido(Pedido pedido, DateTime ahora) {
    final fecha = pedido.fecha;
    if (pedido.estado != EstadoPedido.nuevo || fecha == null) return false;
    return ahora.difference(fecha) > const Duration(hours: horasParaVencer);
  }
}
