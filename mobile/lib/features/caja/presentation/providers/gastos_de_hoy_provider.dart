import 'package:flutter/foundation.dart';

import '../../application/use_cases/gastos_caja.dart';
import '../../domain/models/gasto_caja.dart';
import 'gasto_caja_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// GastosDeHoyProvider
// ═════════════════════════════════════════════════════════════════════════
// La lista «Gastos de hoy»: se lee UNA vez al abrirla (1 lectura por gasto,
// tope de 20) y, tras corregir o anular, se cambia EN MEMORIA (el viejo se
// tacha y el correcto aparece arriba) sin volver a leer. Los números del día
// se actualizan solos por la escucha del resumen.
// ═════════════════════════════════════════════════════════════════════════
class GastosDeHoyProvider extends ChangeNotifier {
  GastosDeHoyProvider({required this.negocioId, required this._leer});

  final String negocioId;
  final GastosDeHoyCaja _leer;

  List<GastoCaja> _gastos = const [];
  bool _cargando = false;
  bool _error = false;
  bool _cerrado = false;
  String _ultimoCambio = '';
  bool _ultimoOk = true;

  List<GastoCaja> get gastos => _gastos;
  bool get cargando => _cargando;

  /// No se pudo leer la lista (sin conexión).
  bool get error => _error;

  /// Llegó el tope: puede haber más gastos hoy que no se ven aquí.
  bool get hayMas => _gastos.length >= GastosDeHoyCaja.limite;

  /// Lo último que se corrigió o anuló, para decirlo arriba de la lista.
  String get ultimoCambio => _ultimoCambio;

  /// Si lo último salió bien (verde) o solo se avisa (por ejemplo, «ya
  /// estaba anulado»).
  bool get ultimoOk => _ultimoOk;

  Future<void> cargar() async {
    if (_cargando || _cerrado) return;
    _cargando = true;
    _error = false;
    notifyListeners();
    try {
      _gastos = await _leer(negocioId);
    } catch (_) {
      _error = true;
    } finally {
      _cargando = false;
      if (!_cerrado) notifyListeners();
    }
  }

  /// Aplica lo que pasó al corregir o anular [viejoId]: lo tacha y, si hay
  /// un gasto correcto, lo pone arriba. No lee nada.
  void aplicar(String viejoId, ResultadoGastoCaja r) {
    if (!r.viejoAnulado && r.gasto == null) return;
    final lista = <GastoCaja>[
      for (final g in _gastos)
        if (g.id == viejoId && r.viejoAnulado) _anulado(g) else g,
    ];
    final nuevo = r.gasto;
    if (nuevo != null && !lista.any((g) => g.id == nuevo.id)) {
      lista.insert(0, nuevo);
    }
    _gastos = List.unmodifiable(lista);
    _ultimoCambio = r.mensaje;
    _ultimoOk = r.ok;
    notifyListeners();
  }

  static GastoCaja _anulado(GastoCaja g) => GastoCaja(
    id: g.id,
    montoCentavos: g.montoCentavos,
    motivo: g.motivo,
    metodoPago: g.metodoPago,
    dia: g.dia,
    nota: g.nota,
    fecha: g.fecha,
    anulado: true,
  );

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
