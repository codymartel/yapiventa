import 'package:flutter/foundation.dart';
import 'package:mobile/features/pedidos/application/services/periodo_informe.dart';
import 'package:mobile/features/pedidos/application/use_cases/obtener_informe_ventas.dart';
import 'package:mobile/features/pedidos/domain/models/informe_ventas.dart';

// ═════════════════════════════════════════════════════════════════════════
// InformesCajaProvider
// ═════════════════════════════════════════════════════════════════════════
// El periodo que mira el vendedor (hoy, semana, mes o un día) y su informe con
// el periodo anterior. Cada vez que cambia el periodo se hace UNA consulta por
// rango de resúmenes (hoy 1 documento, semana hasta 7, mes hasta 31; el doble
// al comparar). No escucha nada en vivo: se actualiza al abrir, al cambiar de
// periodo y con `recargar()`.
//
// Un resultado que llega tarde de un periodo viejo se descarta.
// ═════════════════════════════════════════════════════════════════════════
class InformesCajaProvider extends ChangeNotifier {
  InformesCajaProvider({
    required this.negocioId,
    required this._obtener,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final String negocioId;
  final ObtenerInformeVentas _obtener;
  final DateTime Function() _reloj;

  TipoPeriodo _tipo = TipoPeriodo.hoy;
  String? _dia;
  bool _comparar = true;
  InformeComparado? _informe;
  bool _cargando = false;
  String? _error;
  int _generacion = 0;
  bool _cerrado = false;

  TipoPeriodo get tipo => _tipo;

  /// El día elegido (AAAA-MM-DD); solo cuenta con [TipoPeriodo.dia].
  String? get dia => _dia;
  bool get comparar => _comparar;
  InformeComparado? get informe => _informe;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> iniciar() => _cargar();

  Future<void> elegirPeriodo(TipoPeriodo tipo, {String? dia}) {
    _tipo = tipo;
    _dia = tipo == TipoPeriodo.dia ? dia : null;
    return _cargar();
  }

  /// Con «comparar» apagado se lee la mitad.
  Future<void> cambiarComparar(bool valor) {
    if (_comparar == valor) return Future.value();
    _comparar = valor;
    return _cargar();
  }

  Future<void> recargar() => _cargar();

  Future<void> _cargar() async {
    final generacion = ++_generacion;
    _cargando = true;
    _error = null;
    _avisar();
    try {
      final r = await _obtener(
        negocioId: negocioId,
        tipo: _tipo,
        ahora: _reloj(),
        dia: _dia,
        comparar: _comparar,
      );
      if (generacion != _generacion) return;
      _informe = r;
    } on ArgumentError {
      if (generacion != _generacion) return;
      _error = 'Ese día no es válido.';
    } catch (_) {
      if (generacion != _generacion) return;
      _error = 'No se pudo cargar el informe. Revisa tu conexión.';
    } finally {
      if (generacion == _generacion) {
        _cargando = false;
        _avisar();
      }
    }
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
