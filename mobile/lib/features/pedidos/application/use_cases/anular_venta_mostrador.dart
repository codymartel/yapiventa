import '../../domain/repositories/repositorio_ventas_mostrador.dart';

/// Anula una venta de Caja ya entregada: devuelve el stock, resta del día de la
/// venta y la deja cancelada. Nunca la borra. Lo que sigue en proceso (un
/// delivery confirmado o en camino) NO se anula: se cancela con
/// `CancelarPedido`.
class AnularVentaMostrador {
  const AnularVentaMostrador(this._repositorio);

  final RepositorioVentasMostrador _repositorio;

  Future<ResultadoAnulacion> call({
    required String negocioId,
    required String pedidoId,
  }) {
    if (pedidoId.trim().isEmpty) {
      throw ArgumentError('La venta debe tener un identificador.');
    }
    return _repositorio.anular(negocioId, pedidoId);
  }
}
