import 'package:flutter/foundation.dart';

import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/use_cases/avanzar_pedido.dart';
import '../../application/use_cases/cancelar_pedido.dart';
import '../../application/use_cases/cancelar_vencidos.dart';
import '../../application/use_cases/confirmar_pedido.dart';
import '../../application/use_cases/marcar_pago_pedido.dart';
import '../../application/use_cases/marcar_reembolso_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'resultado_accion.dart';

// ═════════════════════════════════════════════════════════════════════════
// AccionesPedidos
// ═════════════════════════════════════════════════════════════════════════
// Lo que el vendedor HACE con un pedido: confirmar, cancelar, avanzar, marcar
// pago o reembolso y cancelar vencidos. Un solo pedido a la vez (un doble
// toque no repite la acción) y los errores se convierten en texto para el
// vendedor, sin detalles internos. No es un ChangeNotifier: avisa con
// [onCambio] y lo usa `PedidosProvider`.
// ═════════════════════════════════════════════════════════════════════════
class AccionesPedidos {
  AccionesPedidos({
    required this.negocioId,
    required this._confirmarPedido,
    required this._cancelarPedido,
    required this._avanzarPedido,
    required this._marcarPagoPedido,
    required this._marcarReembolsoPedido,
    required this._cancelarVencidos,
    required this._tamano,
    required this._reloj,
    required this.onCambio,
    required this.alCambiarPedido,
    required this.reiniciarNuevos,
  });

  /// Máximo de tandas seguidas al cancelar vencidos (tope contra bucles).
  static const int _maxTandasVencidos = 20;

  final String negocioId;
  final ConfirmarPedido _confirmarPedido;
  final CancelarPedido _cancelarPedido;
  final AvanzarPedido _avanzarPedido;
  final MarcarPagoPedido _marcarPagoPedido;
  final MarcarReembolsoPedido _marcarReembolsoPedido;
  final CancelarVencidos _cancelarVencidos;
  final int _tamano;
  final DateTime Function() _reloj;

  /// Avisa que algo cambió (para redibujar).
  final VoidCallback onCambio;

  /// El pedido cambió: hay que olvidar su copia vieja de «Ver más».
  final void Function(String pedidoId) alCambiarPedido;

  /// Tras cancelar vencidos: lo traído con «Ver más» en Nuevos queda viejo.
  final VoidCallback reiniciarNuevos;

  final Set<String> _procesando = {};
  bool _cancelandoVencidos = false;

  bool procesando(String pedidoId) => _procesando.contains(pedidoId);
  bool get cancelandoVencidos => _cancelandoVencidos;

  Future<ResultadoAccion> confirmar(Pedido pedido) {
    return _ejecutar(pedido.id, () async {
      final r = await _confirmarPedido(
        negocioId: negocioId,
        pedidoId: pedido.id,
      );
      if (r.ok || r.yaNoEsNuevo) alCambiarPedido(pedido.id);
      if (!r.ok) {
        return ResultadoAccion(
          TipoResultado.error,
          MensajesAccionPedido.confirmarBloqueado(r),
        );
      }
      return ResultadoAccion(
        r.totalActualCentavos == null
            ? TipoResultado.exito
            : TipoResultado.aviso,
        MensajesAccionPedido.confirmado(r, pedido.totalCentavos),
      );
    });
  }

  /// Confirma varios pedidos nuevos, de uno en uno (cada uno es su propia
  /// transacción: si falta stock en uno, los demás siguen). Devuelve cuántos
  /// se confirmaron y el motivo del primero que no.
  Future<ResultadoAccion> confirmarVarios(List<Pedido> pedidos) async {
    var confirmados = 0;
    var bloqueados = 0;
    String? primerMotivo;
    for (final pedido in pedidos) {
      if (pedido.estado != EstadoPedido.nuevo) continue;
      final r = await confirmar(pedido);
      if (!r.hizoAlgo) continue;
      if (r.fallo) {
        bloqueados++;
        primerMotivo ??= r.mensaje;
      } else {
        confirmados++;
      }
    }
    return ResultadoAccion(
      bloqueados > 0 ? TipoResultado.aviso : TipoResultado.exito,
      MensajesAccionPedido.confirmadosEnLote(
        confirmados,
        bloqueados,
        primerMotivo,
      ),
    );
  }

  Future<ResultadoAccion> cancelar(Pedido pedido) {
    return _ejecutar(pedido.id, () async {
      final sinDevolver = await _cancelarPedido(
        negocioId: negocioId,
        pedidoId: pedido.id,
      );
      alCambiarPedido(pedido.id);
      return ResultadoAccion(
        sinDevolver == 0 ? TipoResultado.exito : TipoResultado.aviso,
        MensajesAccionPedido.cancelado(sinDevolver),
      );
    });
  }

  /// Pasa al estado siguiente. Al entregar, [cobrado] marca el pago a la vez.
  Future<ResultadoAccion> avanzar(Pedido pedido, {bool cobrado = false}) {
    return _ejecutar(pedido.id, () async {
      final nuevo = await _avanzarPedido(
        negocioId: negocioId,
        pedido: pedido,
        cobrado: cobrado,
      );
      alCambiarPedido(pedido.id);
      return ResultadoAccion(
        TipoResultado.exito,
        'Pedido ${nuevo.etiqueta.toLowerCase()}.',
      );
    });
  }

  Future<ResultadoAccion> marcarPago(Pedido pedido, EstadoPago pago) {
    return _ejecutar(pedido.id, () async {
      await _marcarPagoPedido(
        negocioId: negocioId,
        pedidoId: pedido.id,
        pago: pago,
      );
      alCambiarPedido(pedido.id);
      return ResultadoAccion(
        TipoResultado.exito,
        pago == EstadoPago.pagado
            ? 'Marcado como cobrado.'
            : 'Marcado como pendiente de cobro.',
      );
    });
  }

  Future<ResultadoAccion> marcarReembolsoHecho(Pedido pedido) {
    return _ejecutar(pedido.id, () async {
      await _marcarReembolsoPedido(negocioId: negocioId, pedidoId: pedido.id);
      return const ResultadoAccion(
        TipoResultado.exito,
        'Reembolso marcado como hecho.',
      );
    });
  }

  /// Cancela los vencidos de 10 en 10. Se detiene cuando una tanda no cancela
  /// ninguno (por ejemplo, sin conexión), no queda más, o tras
  /// [_maxTandasVencidos] tandas.
  Future<ResultadoAccion> cancelarVencidos() async {
    if (_cancelandoVencidos) return const ResultadoAccion.ignorado();
    _cancelandoVencidos = true;
    onCambio();
    var canceladas = 0;
    var omitidas = 0;
    var fallidas = 0;
    try {
      for (var tanda = 0; tanda < _maxTandasVencidos; tanda++) {
        final r = await _cancelarVencidos(
          negocioId: negocioId,
          ahora: _reloj(),
          limite: _tamano,
        );
        canceladas += r.canceladas;
        omitidas += r.omitidas;
        fallidas += r.fallidas;
        if (!r.hayMas || r.canceladas == 0) break;
      }
    } catch (_) {
      fallidas++;
    } finally {
      // No se sabe cuáles se cancelaron: lo traído con «Ver más» queda viejo.
      reiniciarNuevos();
      _cancelandoVencidos = false;
      onCambio();
    }
    final resultado = ResultadoCancelarVencidos(
      canceladas: canceladas,
      omitidas: omitidas,
      fallidas: fallidas,
    );
    return ResultadoAccion(
      fallidas > 0 ? TipoResultado.aviso : TipoResultado.exito,
      MensajesAccionPedido.vencidos(resultado),
    );
  }

  /// Un solo pedido a la vez: un doble toque no repite la acción. Los errores
  /// se convierten en texto para el vendedor, sin mostrar detalles internos.
  Future<ResultadoAccion> _ejecutar(
    String pedidoId,
    Future<ResultadoAccion> Function() accion,
  ) async {
    if (_procesando.contains(pedidoId)) {
      return const ResultadoAccion.ignorado();
    }
    _procesando.add(pedidoId);
    onCambio();
    try {
      return await accion();
    } on StateError catch (e) {
      alCambiarPedido(pedidoId);
      return ResultadoAccion(TipoResultado.error, e.message);
    } on ArgumentError {
      return const ResultadoAccion(
        TipoResultado.error,
        'No se pudo completar la acción.',
      );
    } catch (_) {
      return const ResultadoAccion(
        TipoResultado.error,
        'No se pudo completar. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      _procesando.remove(pedidoId);
      onCambio();
    }
  }
}
