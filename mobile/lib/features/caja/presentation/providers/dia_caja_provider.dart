import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/pedidos/application/services/resumen_dia_pedidos.dart';

import '../../domain/models/dia_caja.dart';
import '../../domain/repositories/repositorios_gastos_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// DiaCajaProvider
// ═════════════════════════════════════════════════════════════════════════
// El día de Caja en vivo: ventas de hoy, gastos de hoy y efectivo en caja.
// Escucha UN solo documento (el resumen de hoy, hora de Lima) y deja de
// escuchar al cerrarse.
//
// Lecturas: 1 al abrir Caja y 1 por cada venta, anulación o gasto del día.
// Si Caja queda abierta pasada la medianoche, `revisarDia()` (se llama tras
// cada cobro o gasto) cambia la escucha al día nuevo.
// ═════════════════════════════════════════════════════════════════════════
class DiaCajaProvider extends ChangeNotifier {
  DiaCajaProvider({
    required this.negocioId,
    required this._repositorio,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final String negocioId;
  final RepositorioDiaCaja _repositorio;
  final DateTime Function() _reloj;

  StreamSubscription<DiaCaja>? _escucha;
  DiaCaja? _dia;
  String _clave = '';
  bool _error = false;
  bool _cerrado = false;

  /// El día de hoy. Mientras no llega el primer dato es un día en cero.
  DiaCaja get dia => _dia ?? DiaCaja.vacio(_clave);

  /// Todavía no llegó el primer dato.
  bool get cargando => _dia == null && !_error;

  /// No se pudo leer el día (sin conexión o sin permiso). Los números que se
  /// ven pueden estar viejos.
  bool get error => _error;

  /// Si la escucha está abierta (se ve como «En vivo»).
  bool get enVivo => _escucha != null && !_error && _dia != null;

  void iniciar() => _escuchar(ResumenDiaPedidos.claveDia(_reloj()));

  /// Si ya es otro día (pasó la medianoche de Lima), escucha el nuevo.
  void revisarDia() {
    final hoy = ResumenDiaPedidos.claveDia(_reloj());
    if (hoy != _clave) _escuchar(hoy);
  }

  /// Vuelve a escuchar tras un error.
  void reintentar() => _escuchar(ResumenDiaPedidos.claveDia(_reloj()));

  void _escuchar(String clave) {
    if (_cerrado) return;
    _escucha?.cancel();
    _clave = clave;
    _dia = null;
    _error = false;
    _escucha = null;
    notifyListeners();
    try {
      _escucha = _repositorio
          .escuchar(negocioId, clave)
          .listen(
            (dia) {
              _dia = dia;
              _error = false;
              if (!_cerrado) notifyListeners();
            },
            onError: (Object _) {
              _error = true;
              if (!_cerrado) notifyListeners();
            },
          );
    } catch (_) {
      // Sin negocio (o un fallo al abrir la escucha): se muestra como error.
      _error = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _escucha?.cancel();
    _escucha = null;
    super.dispose();
  }
}
