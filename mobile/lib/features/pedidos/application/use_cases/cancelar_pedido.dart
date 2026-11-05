import '../../domain/repositories/repositorio_pedidos.dart';

/// Cancela un pedido nuevo o confirmado y devuelve al stock lo que se había
/// descontado. Devuelve cuántas líneas no se pudieron devolver porque su
/// producto ya no existe (0 = todo devuelto). Nunca borra el pedido.
class CancelarPedido {
  const CancelarPedido(this._repositorio);

  final RepositorioPedidos _repositorio;

  Future<int> call({required String negocioId, required String pedidoId}) {
    if (pedidoId.trim().isEmpty) {
      throw ArgumentError('El pedido debe tener un identificador.');
    }
    return _repositorio.cancelar(negocioId, pedidoId);
  }
}
