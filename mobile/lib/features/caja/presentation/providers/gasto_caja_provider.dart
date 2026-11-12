import 'package:flutter/foundation.dart';

import '../../application/services/id_aleatorio_caja.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import '../../application/services/validacion_gasto_caja.dart';
import '../../application/use_cases/gastos_caja.dart';
import '../../domain/models/gasto_caja.dart';
import '../../domain/models/opciones_caja.dart';
import '../../domain/repositories/repositorios_gastos_caja.dart';

/// Lo que devuelve guardar, corregir o anular un gasto: si salió bien y qué
/// decirle al cajero. [gastoId] viene cuando se guardó (para «Anular» en el
/// aviso). Al corregir, [gasto] es el correcto y [viejoAnulado] dice que el
/// gasto viejo ya quedó anulado (para tacharlo en la lista sin volver a leer).
class ResultadoGastoCaja {
  const ResultadoGastoCaja({
    required this.ok,
    required this.mensaje,
    this.gastoId = '',
    this.gasto,
    this.viejoAnulado = false,
  });

  final bool ok;
  final String mensaje;
  final String gastoId;
  final GastoCaja? gasto;
  final bool viejoAnulado;
}

// ═════════════════════════════════════════════════════════════════════════
// GastoCajaProvider
// ═════════════════════════════════════════════════════════════════════════
// El formulario del gasto: monto, motivo, de dónde salió y una nota. Sirve
// para anotar uno nuevo y, con [original], para CORREGIR uno mal anotado
// (llega lleno; al guardar el viejo queda anulado y nace el correcto). No
// habla con Firestore: usa los casos de uso.
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
  }) : original = null,
       _corregir = null,
       _generarId = generarId ?? idAleatorioCaja,
       _pago = opcionesPago.isEmpty ? null : opcionesPago.first {
    _idGasto = _generarId();
  }

  /// Para corregir [original]: el formulario llega lleno con sus datos.
  GastoCajaProvider.corrigiendo({
    required this.negocioId,
    required GastoCaja this.original,
    required CorregirGastoCaja this._corregir,
    required this._anular,
    required this._registrar,
    this.opcionesPago = const [],
    String Function()? generarId,
  }) : _generarId = generarId ?? idAleatorioCaja,
       _pago = _pagoDe(opcionesPago, original.metodoPago) {
    final viejo = original!;
    _idGasto = _generarId();
    _montoTexto = ValidacionGastoCaja.textoDeMonto(viejo.montoCentavos);
    _motivo = viejo.motivo;
    _nota = viejo.nota;
  }

  final String negocioId;
  final RegistrarGastoCaja _registrar;
  final AnularGastoCaja _anular;
  final CorregirGastoCaja? _corregir;
  final String Function() _generarId;

  /// El gasto que se corrige. null al anotar uno nuevo.
  final GastoCaja? original;

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
  bool get corrigiendo => original != null;

  /// El monto escrito, en céntimos. null si todavía no es un monto válido.
  int? get montoCentavos => ValidacionGastoCaja.montoDeTexto(_montoTexto);

  /// Qué falta para guardar, o null si está listo. Con el monto vacío no
  /// avisa nada (el cajero recién empieza).
  String? get motivoNoGuardar {
    if (_montoTexto.trim().isEmpty) return null;
    return _error;
  }

  bool get puedeGuardar => !_guardando && _error == null;

  String? get _error {
    final error = ValidacionGastoCaja.revisar(
      montoCentavos: montoCentavos,
      metodoPago: _pago?.id ?? '',
      nota: _nota,
    );
    if (error != null) return error;
    final viejo = original;
    if (viejo != null && !_cambio(viejo)) {
      return 'Cambia el monto, el motivo o de dónde salió.';
    }
    return null;
  }

  bool _cambio(GastoCaja viejo) => CorregirGastoCaja.hayCambios(
    viejo,
    GastoCaja(
      id: '',
      montoCentavos: montoCentavos ?? 0,
      motivo: _motivo,
      metodoPago: ValidacionGastoCaja.clavePago(_pago?.id ?? ''),
      dia: viejo.dia,
      nota: _nota,
    ),
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
      return original == null
          ? await _guardarNuevo()
          : await _guardarCorreccion();
    } catch (_) {
      return ResultadoGastoCaja(
        ok: false,
        mensaje:
            'No se pudo guardar ${corrigiendo ? 'la corrección' : 'el gasto'}. '
            'Revisa tu conexión e inténtalo de nuevo: no se guardará dos '
            'veces.',
      );
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  Future<ResultadoGastoCaja> _guardarNuevo() async {
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
  }

  Future<ResultadoGastoCaja> _guardarCorreccion() async {
    final r = await _corregir!(
      negocioId: negocioId,
      original: original!,
      idNuevo: _idGasto,
      montoCentavos: montoCentavos,
      motivo: _motivo,
      metodoPago: _pago?.id ?? '',
      nota: _nota,
    );
    final error = r.error;
    if (error != null) return ResultadoGastoCaja(ok: false, mensaje: error);
    final correcto = r.correcto!;
    return switch (r.resultado!) {
      ResultadoCorregirGasto.corregido ||
      ResultadoCorregirGasto.yaCorregido => ResultadoGastoCaja(
        ok: true,
        mensaje:
            'Gasto corregido · ahora es '
            '${MensajesCobroCaja.dinero(correcto.montoCentavos)}',
        gasto: correcto,
        viejoAnulado: true,
      ),
      ResultadoCorregirGasto.yaAnulado => const ResultadoGastoCaja(
        ok: false,
        mensaje:
            'Este gasto ya estaba anulado: no se cambió nada. Si hace falta, '
            'anota uno nuevo con «Gasto».',
        viejoAnulado: true,
      ),
    };
  }

  /// «Anular» del aviso, o «Anular este gasto» al corregir: el gasto queda
  /// anulado y se resta del día.
  Future<ResultadoGastoCaja> anular(String gastoId) async {
    try {
      final r = await _anular(negocioId: negocioId, gastoId: gastoId);
      return ResultadoGastoCaja(
        ok: true,
        mensaje: r.yaAnulado
            ? 'Ese gasto ya estaba anulado.'
            : 'Gasto anulado.',
        gastoId: gastoId,
        viejoAnulado: true,
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

  /// La forma de pago activa que guarda con esa clave. null si ya no está
  /// activa (el cajero elige otra).
  static OpcionPagoCaja? _pagoDe(List<OpcionPagoCaja> opciones, String clave) {
    for (final o in opciones) {
      if (ValidacionGastoCaja.clavePago(o.id) == clave) return o;
    }
    return null;
  }
}
