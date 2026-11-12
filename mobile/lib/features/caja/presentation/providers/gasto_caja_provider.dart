import 'package:flutter/foundation.dart';

import '../../application/services/id_aleatorio_caja.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import '../../application/services/validacion_gasto_caja.dart';
import '../../application/use_cases/gastos_caja.dart';
import '../../domain/models/gasto_caja.dart';
import '../../domain/models/opciones_caja.dart';

/// Lo que devuelve guardar o anular un gasto: si salió bien y qué decirle al
/// cajero. [gastoId] viene cuando se guardó (para «Anular» en el aviso).
class ResultadoGastoCaja {
  const ResultadoGastoCaja({
    required this.ok,
    required this.mensaje,
    this.gastoId = '',
  });

  final bool ok;
  final String mensaje;
  final String gastoId;
}

// ═════════════════════════════════════════════════════════════════════════
// GastoCajaProvider
// ═════════════════════════════════════════════════════════════════════════
// El gasto rápido que anota el cajero: monto, motivo, de dónde salió y una
// nota. No habla con Firestore: usa los casos de uso.
//
// Contra el doble gasto: el gasto tiene un id desde que se abre la hoja. Si
// guardar falla (sin conexión) el id y lo escrito se CONSERVAN: reintentar
// con el mismo id no gasta dos veces. Solo al guardarse se estrena un id
// nuevo y se limpia.
// ═════════════════════════════════════════════════════════════════════════
class GastoCajaProvider extends ChangeNotifier {
  GastoCajaProvider({
    required this.negocioId,
    required this._registrar,
    required this._anular,
    this.opcionesPago = const [],
    String Function()? generarId,
  }) : _generarId = generarId ?? idAleatorioCaja,
       _pago = opcionesPago.isEmpty ? null : opcionesPago.first {
    _idGasto = _generarId();
  }

  final String negocioId;
  final RegistrarGastoCaja _registrar;
  final AnularGastoCaja _anular;
  final String Function() _generarId;

  /// Las formas de pago activas del negocio (las mismas de las ventas).
  final List<OpcionPagoCaja> opcionesPago;

  late String _idGasto;
  String _montoTexto = '';
  MotivoGasto _motivo = MotivoGasto.comida;
  OpcionPagoCaja? _pago;
  String _nota = '';
  bool _guardando = false;

  String get idGasto => _idGasto;
  String get montoTexto => _montoTexto;
  MotivoGasto get motivo => _motivo;
  OpcionPagoCaja? get pago => _pago;
  String get nota => _nota;
  bool get guardando => _guardando;

  /// El monto escrito, en céntimos. null si todavía no es un monto válido.
  int? get montoCentavos => ValidacionGastoCaja.montoDeTexto(_montoTexto);

  /// Qué falta para guardar, o null si está listo. Con el monto vacío no
  /// avisa nada (el cajero recién empieza).
  String? get motivoNoGuardar {
    if (_montoTexto.trim().isEmpty) return null;
    return _error;
  }

  bool get puedeGuardar => !_guardando && _error == null;

  String? get _error => ValidacionGastoCaja.revisar(
    montoCentavos: montoCentavos,
    metodoPago: _pago?.id ?? '',
    nota: _nota,
  );

  void escribirMonto(String valor) {
    _montoTexto = valor;
    notifyListeners();
  }

  void elegirMotivo(MotivoGasto motivo) {
    _motivo = motivo;
    notifyListeners();
  }

  void elegirPago(OpcionPagoCaja? pago) {
    _pago = pago;
    notifyListeners();
  }

  void escribirNota(String valor) {
    _nota = valor;
    notifyListeners();
  }

  Future<ResultadoGastoCaja> guardar() async {
    if (_guardando) {
      return const ResultadoGastoCaja(ok: false, mensaje: '');
    }
    final error = _error;
    if (error != null) return ResultadoGastoCaja(ok: false, mensaje: error);

    _guardando = true;
    notifyListeners();
    try {
      final r = await _registrar(
        negocioId: negocioId,
        idGasto: _idGasto,
        montoCentavos: montoCentavos,
        motivo: _motivo,
        metodoPago: _pago?.id ?? '',
        nota: _nota,
      );
      if (!r.ok) return ResultadoGastoCaja(ok: false, mensaje: r.error!);

      final gasto = r.gasto!;
      _limpiar();
      _idGasto = _generarId();
      return ResultadoGastoCaja(
        ok: true,
        mensaje: r.yaGuardado
            ? 'Este gasto ya estaba guardado.'
            : 'Gasto guardado · ${gasto.motivo.etiqueta} · '
                  '${MensajesCobroCaja.dinero(gasto.montoCentavos)}',
        gastoId: gasto.id,
      );
    } catch (_) {
      return const ResultadoGastoCaja(
        ok: false,
        mensaje:
            'No se pudo guardar el gasto. Revisa tu conexión e inténtalo de '
            'nuevo: no se guardará dos veces.',
      );
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  /// «Anular» del aviso: el gasto queda anulado y se resta del día.
  Future<ResultadoGastoCaja> anular(String gastoId) async {
    try {
      final r = await _anular(negocioId: negocioId, gastoId: gastoId);
      return ResultadoGastoCaja(
        ok: true,
        mensaje: r.yaAnulado
            ? 'Ese gasto ya estaba anulado.'
            : 'Gasto anulado.',
      );
    } catch (_) {
      return const ResultadoGastoCaja(
        ok: false,
        mensaje: 'No se pudo anular el gasto. Revisa tu conexión.',
      );
    }
  }

  void _limpiar() {
    _montoTexto = '';
    _nota = '';
    _motivo = MotivoGasto.comida;
  }
}
