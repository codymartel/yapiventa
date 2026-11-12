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

/// Cómo terminó corregir un gasto.
class ResultadoCorregirGastoCaja {
  const ResultadoCorregirGastoCaja({this.correcto, this.resultado, this.error});

  /// El gasto correcto tal como se mandó a guardar.
  final GastoCaja? correcto;

  /// Qué pasó en la nube. null si no se intentó.
  final ResultadoCorregirGasto? resultado;

  /// Por qué no se intentó (dato inválido o nada que corregir).
  final String? error;
}

/// Corrige un gasto mal anotado (S/ 100 en vez de S/ 10): el viejo queda
/// anulado y nace el correcto, en el MISMO día, en una sola transacción.
/// Corregir es anular más crear: el gasto viejo nunca se edita ni se borra.
class CorregirGastoCaja {
  const CorregirGastoCaja(this._repositorio);

  final RepositorioGastosCaja _repositorio;

  Future<ResultadoCorregirGastoCaja> call({
    required String negocioId,
    required GastoCaja original,
    required String idNuevo,
    required int? montoCentavos,
    required MotivoGasto motivo,
    required String metodoPago,
    String nota = '',
  }) async {
    if (original.anulado) {
      return const ResultadoCorregirGastoCaja(
        error: 'Este gasto ya está anulado.',
      );
    }
    final error = ValidacionGastoCaja.revisar(
      montoCentavos: montoCentavos,
      metodoPago: metodoPago,
      nota: nota,
    );
    if (error != null) return ResultadoCorregirGastoCaja(error: error);
    if (idNuevo.trim().isEmpty || idNuevo.trim() == original.id) {
      throw ArgumentError('La corrección necesita un identificador nuevo.');
    }
    final correcto = GastoCaja(
      id: idNuevo.trim(),
      montoCentavos: montoCentavos!,
      motivo: motivo,
      metodoPago: ValidacionGastoCaja.clavePago(metodoPago),
      dia: original.dia,
      nota: nota.trim(),
    );
    if (!hayCambios(original, correcto)) {
      return const ResultadoCorregirGastoCaja(
        error: 'Cambia el monto, el motivo o de dónde salió.',
      );
    }
    final resultado = await _repositorio.corregir(
      negocioId,
      viejoId: original.id,
      correcto: correcto,
    );
    return ResultadoCorregirGastoCaja(correcto: correcto, resultado: resultado);
  }

  /// Si el gasto nuevo dice algo distinto del viejo (sin cambios no hay nada
  /// que corregir).
  static bool hayCambios(GastoCaja viejo, GastoCaja nuevo) =>
      viejo.montoCentavos != nuevo.montoCentavos ||
      viejo.motivo != nuevo.motivo ||
      viejo.metodoPago != nuevo.metodoPago ||
      viejo.nota.trim() != nuevo.nota.trim();
}

/// Los gastos de HOY (hora de Lima), para verlos y corregirlos: el más nuevo
/// arriba y los anulados también (se ven tachados). Lee una sola vez, con
/// tope de [limite] (1 lectura por gasto).
class GastosDeHoyCaja {
  GastosDeHoyCaja(this._repositorio, {DateTime Function()? reloj})
    : _reloj = reloj ?? DateTime.now;

  static const int limite = 20;

  final RepositorioGastosDelDia _repositorio;
  final DateTime Function() _reloj;

  Future<List<GastoCaja>> call(String negocioId) async {
    final dia = ResumenDiaPedidos.claveDia(_reloj());
    final gastos = await _repositorio.delDia(negocioId, dia, limite: limite);
    return ordenar(gastos);
  }

  /// El más nuevo primero. Uno sin fecha (recién guardado, el servidor aún no
  /// la puso) va arriba de todo.
  static List<GastoCaja> ordenar(List<GastoCaja> gastos) {
    final lista = List<GastoCaja>.of(gastos);
    lista.sort((a, b) {
      final fa = a.fecha;
      final fb = b.fecha;
      if (fa == null && fb == null) return 0;
      if (fa == null) return -1;
      if (fb == null) return 1;
      return fb.compareTo(fa);
    });
    return lista;
  }
}
