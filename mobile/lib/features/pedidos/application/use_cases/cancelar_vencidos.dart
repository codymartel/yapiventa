import '../../domain/repositories/repositorio_pedidos.dart';
import '../services/transiciones_pedido.dart';

/// Lo que pasó en una tanda de cancelación de vencidos.
class ResultadoCancelarVencidos {
  const ResultadoCancelarVencidos({
    this.canceladas = 0,
    this.omitidas = 0,
    this.fallidas = 0,
    this.hayMas = false,
  });

  /// Pedidos que se cancelaron.
  final int canceladas;

  /// Ya no estaban nuevos (otro vendedor los confirmó o cancelaron): no se tocan.
  final int omitidas;

  /// Fallaron por otra causa (sin conexión, permisos): siguen nuevos.
  final int fallidas;

  /// La tanda salió completa: puede haber más vencidos, se repite el botón.
  final bool hayMas;
}

/// Cancela los pedidos nuevos con más de 12 horas sin confirmar, de [limite]
/// en [limite] y de uno en uno (cada cancelación es su propia transacción).
///
/// Usa el reloj del teléfono para el corte; la cancelación automática desde el
/// servidor queda para cuando haya Cloud Functions. Un pedido que otro
/// vendedor ya confirmó NO se cancela (`soloSiEstaNuevo`): ya descontó stock.
class CancelarVencidos {
  const CancelarVencidos(this._repositorio);

  final RepositorioPedidos _repositorio;

  Future<ResultadoCancelarVencidos> call({
    required String negocioId,
    DateTime? ahora,
    int limite = 10,
  }) async {
    final corte = (ahora ?? DateTime.now()).subtract(
      const Duration(hours: TransicionesPedido.horasParaVencer),
    );
    final vencidos = await _repositorio.obtenerVencidos(
      negocioId,
      antesDe: corte,
      limite: limite,
    );

    var canceladas = 0;
    var omitidas = 0;
    var fallidas = 0;
    for (final pedido in vencidos) {
      try {
        await _repositorio.cancelar(
          negocioId,
          pedido.id,
          soloSiEstaNuevo: true,
        );
        canceladas++;
      } on StateError {
        omitidas++;
      } catch (_) {
        fallidas++;
      }
    }
    return ResultadoCancelarVencidos(
      canceladas: canceladas,
      omitidas: omitidas,
      fallidas: fallidas,
      hayMas: vencidos.length >= limite,
    );
  }
}
