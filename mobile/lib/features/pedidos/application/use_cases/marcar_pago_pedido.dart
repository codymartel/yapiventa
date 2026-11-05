import '../../domain/models/estado_pedido.dart';
import '../../domain/repositories/repositorio_pedidos.dart';

/// Marca un pedido como cobrado o pendiente de cobro. Se puede hacer hasta
/// después de entregar, pero no en un pedido cancelado.
class MarcarPagoPedido {
  const MarcarPagoPedido(this._repositorio);

  final RepositorioPedidos _repositorio;

  Future<void> call({
    required String negocioId,
    required String pedidoId,
    required EstadoPago pago,
  }) {
    if (pedidoId.trim().isEmpty) {
      throw ArgumentError('El pedido debe tener un identificador.');
    }
    return _repositorio.marcarPago(negocioId, pedidoId, pago);
  }
}
