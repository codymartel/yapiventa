import '../../domain/repositories/repositorio_pedidos.dart';

/// Confirma un pedido nuevo: en una sola transacción valida que siga nuevo,
/// descuenta el stock y lo pasa a confirmado. Si algo no alcanza, no se
/// descuenta nada y el resultado dice qué falta ([ResultadoConfirmar.ok]).
class ConfirmarPedido {
  const ConfirmarPedido(this._repositorio);

  final RepositorioPedidos _repositorio;

  Future<ResultadoConfirmar> call({
    required String negocioId,
    required String pedidoId,
  }) {
    if (pedidoId.trim().isEmpty) {
      throw ArgumentError('El pedido debe tener un identificador.');
    }
    return _repositorio.confirmar(negocioId, pedidoId);
  }
}
