import '../models/dia_caja.dart';
import '../models/gasto_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// Contratos de Caja para gastos y para el día en vivo
// ═════════════════════════════════════════════════════════════════════════
// Las implementaciones viven en `data/`. Escribir gastos y leer el día son
// dos contratos distintos (un repositorio = un tipo de operación).
// ═════════════════════════════════════════════════════════════════════════

/// Resultado de anular un gasto.
class ResultadoAnularGasto {
  const ResultadoAnularGasto({this.yaAnulado = false});

  /// Un toque repetido: ya estaba anulado (o no existe), no se tocó nada.
  final bool yaAnulado;
}

/// Registro de gastos de Caja.
abstract class RepositorioGastosCaja {
  /// Guarda el gasto y lo suma al resumen de su día en UNA transacción (todo
  /// o nada). Devuelve false si ese id ya estaba guardado (un toque repetido
  /// no gasta dos veces).
  Future<bool> registrar(String negocioId, GastoCaja gasto);

  /// Anula un gasto en UNA transacción: lo marca anulado (no se borra) y lo
  /// resta del resumen del día en que se guardó.
  Future<ResultadoAnularGasto> anular(String negocioId, String gastoId);
}

/// El día de Caja en vivo.
abstract class RepositorioDiaCaja {
  /// Escucha UN documento: el resumen del [dia] (AAAA-MM-DD). Quien escucha
  /// debe cancelar al salir.
  Stream<DiaCaja> escuchar(String negocioId, String dia);
}
