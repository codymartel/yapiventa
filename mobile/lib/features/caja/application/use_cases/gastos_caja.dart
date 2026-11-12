import 'package:mobile/features/pedidos/application/services/resumen_dia_pedidos.dart';

import '../../domain/models/gasto_caja.dart';
import '../../domain/repositories/repositorios_gastos_caja.dart';
import '../services/validacion_gasto_caja.dart';

/// Cómo terminó guardar un gasto.
class ResultadoRegistrarGasto {
  const ResultadoRegistrarGasto({
    this.gasto,
    this.yaGuardado = false,
    this.error,
  });

  /// El gasto tal como se mandó a guardar (para el aviso con «Anular»).
  final GastoCaja? gasto;

  /// Un toque repetido: ese id ya estaba guardado, no se sumó otra vez.
  final bool yaGuardado;

  /// Por qué no se intentó guardar (dato inválido). null si se intentó.
  final String? error;

  bool get ok => error == null;
}

/// Guarda un gasto rápido de Caja en el día de HOY (hora de Lima). Valida
/// antes de escribir; el repositorio lo guarda y lo suma al resumen en una
/// sola transacción.
class RegistrarGastoCaja {
  RegistrarGastoCaja(this._repositorio, {DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  final RepositorioGastosCaja _repositorio;
  final DateTime Function() _reloj;

  Future<ResultadoRegistrarGasto> call({
    required String negocioId,
    required String idGasto,
    required int? montoCentavos,
    required MotivoGasto motivo,
    required String metodoPago,
    String nota = '',
  }) async {
    final error = ValidacionGastoCaja.revisar(
      montoCentavos: montoCentavos,
      metodoPago: metodoPago,
      nota: nota,
    );
    if (error != null) return ResultadoRegistrarGasto(error: error);
    if (idGasto.trim().isEmpty) {
      throw ArgumentError('El gasto debe tener un identificador.');
    }

    final gasto = GastoCaja(
      id: idGasto.trim(),
      montoCentavos: montoCentavos!,
      motivo: motivo,
      metodoPago: ValidacionGastoCaja.clavePago(metodoPago),
      dia: ResumenDiaPedidos.claveDia(_reloj()),
      nota: nota.trim(),
    );
    final nuevo = await _repositorio.registrar(negocioId, gasto);
    return ResultadoRegistrarGasto(gasto: gasto, yaGuardado: !nuevo);
  }
}

/// Anula un gasto: lo marca anulado y lo resta del día en que se guardó.
/// Nunca lo borra.
class AnularGastoCaja {
  const AnularGastoCaja(this._repositorio);

  final RepositorioGastosCaja _repositorio;

  Future<ResultadoAnularGasto> call({
    required String negocioId,
    required String gastoId,
  }) {
    if (gastoId.trim().isEmpty) {
      throw ArgumentError('El gasto debe tener un identificador.');
    }
    return _repositorio.anular(negocioId, gastoId);
  }
}
