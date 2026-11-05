import '../../domain/repositories/repositorio_pedidos.dart';

/// Marca como hecho el reembolso de un pedido cancelado que ya estaba pagado.
/// Solo funciona si el reembolso estaba pendiente.
class MarcarReembolsoPedido {
  const MarcarReembolsoPedido(this._repositorio);

  final RepositorioPedidos _repositorio;

  Future<void> call({required String negocioId, required String pedidoId}) {
    if (pedidoId.trim().isEmpty) {
      throw ArgumentError('El pedido debe tener un identificador.');
    }
    return _repositorio.marcarReembolsoHecho(negocioId, pedidoId);
  }
}
