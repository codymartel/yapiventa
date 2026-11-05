import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/repositories/repositorio_pedidos.dart';
import '../services/transiciones_pedido.dart';

/// Pasa el pedido al estado que sigue: confirmado → listo (recojo) o en camino
/// (delivery) → entregado. Confirmar no va por aquí porque mueve stock: usa
/// `ConfirmarPedido`.
///
/// Al entregar, [cobrado] marca el pago en la misma transacción (el pago
/// contra entrega es común). Devuelve el estado al que pasó.
class AvanzarPedido {
  const AvanzarPedido(this._repositorio);

  final RepositorioPedidos _repositorio;

  Future<EstadoPedido> call({
    required String negocioId,
    required Pedido pedido,
    bool cobrado = false,
  }) async {
    if (pedido.id.trim().isEmpty) {
      throw ArgumentError('El pedido debe tener un identificador.');
    }
    final siguiente = TransicionesPedido.siguiente(
      pedido.estado,
      pedido.tipoEntrega,
    );
    if (siguiente == null) {
      throw StateError('El pedido ya no tiene un paso siguiente.');
    }
    if (siguiente == EstadoPedido.confirmado) {
      throw ArgumentError('Confirmar mueve stock: usa ConfirmarPedido.');
    }
    if (cobrado && siguiente != EstadoPedido.entregado) {
      throw ArgumentError('Solo se marca cobrado al entregar.');
    }
    await _repositorio.avanzar(
      negocioId,
      pedido.id,
      siguiente,
      pago: cobrado ? EstadoPago.pagado : null,
    );
    return siguiente;
  }
}
