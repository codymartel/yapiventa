import 'package:flutter/foundation.dart';
import 'package:mobile/features/productos/application/use_cases/preparar_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

/// En qué va la preparación del catálogo para Caja (pantalla B10).
enum EstadoPreparacion {
  /// Todavía no se sabe (no se ha preguntado).
  desconocido,

  /// Ya estaba preparado: no hay nada que mostrar.
  noHaceFalta,

  /// Falta prepararlo: se pide el «sí» del vendedor.
  pideConfirmar,
  preparando,
  lista,

  /// Sin conexión o corte: se puede reintentar sin perder lo hecho.
  error,

  /// El negocio pasa del tope de productos: no se escribió nada.
  demasiados,

  /// El vendedor eligió «Más tarde»: Caja sigue con límites.
  pospuesta,
}

// ═════════════════════════════════════════════════════════════════════════
// PreparacionCatalogoProvider
// ═════════════════════════════════════════════════════════════════════════
// Decide cuándo mostrar el aviso de «Prepara tu catálogo para Caja» y corre
// la preparación SOLO cuando el vendedor acepta.
//
//   verificar()  → 1 lectura (la marca del negocio); no escribe nada
//   preparar()   → N lecturas y ≤ N + 1 escrituras, una sola vez por negocio
//
// Mientras prepara, [bloqueaVentas] es true (si se vendiera un producto justo
// ahora, su contador de «más vendidos» podría volver a 0).
// ═════════════════════════════════════════════════════════════════════════
class PreparacionCatalogoProvider extends ChangeNotifier {
  PreparacionCatalogoProvider({
    required this.negocioId,
    required this._preparar,
  });

  final String negocioId;
  final PrepararCatalogoCaja _preparar;

  EstadoPreparacion _estado = EstadoPreparacion.desconocido;
  ResultadoRelleno? _resultado;
  bool _cerrado = false;

  EstadoPreparacion get estado => _estado;

  /// Lo que pasó al preparar (cuántos productos se revisaron y se tocaron).
  ResultadoRelleno? get resultado => _resultado;

  bool get bloqueaVentas => _estado == EstadoPreparacion.preparando;

  /// Hay que mostrar el aviso (o el estado de la preparación en curso).
  bool get hayQueMostrar =>
      _estado == EstadoPreparacion.pideConfirmar ||
      _estado == EstadoPreparacion.preparando ||
      _estado == EstadoPreparacion.lista ||
      _estado == EstadoPreparacion.error ||
      _estado == EstadoPreparacion.demasiados;

  /// Caja funciona con límites (sin búsqueda por nombre ni «más vendidos»).
  bool get conLimites =>
      _estado == EstadoPreparacion.pospuesta ||
      _estado == EstadoPreparacion.demasiados ||
      _estado == EstadoPreparacion.error;

  Future<void> verificar() async {
    if (_estado != EstadoPreparacion.desconocido) return;
    try {
      final hace = await _preparar.hacePrecisoPreparar(negocioId);
      _poner(
        hace ? EstadoPreparacion.pideConfirmar : EstadoPreparacion.noHaceFalta,
      );
    } catch (_) {
      // Sin conexión al abrir: no se bloquea Caja; se vuelve a preguntar luego.
      _poner(EstadoPreparacion.desconocido);
    }
  }

  /// El vendedor tocó «Preparar ahora» (o «Reintentar»).
  Future<void> preparar() async {
    if (_estado == EstadoPreparacion.preparando) return;
    _poner(EstadoPreparacion.preparando);
    try {
      final r = await _preparar.preparar(negocioId);
      _resultado = r;
      _poner(
        r.demasiados ? EstadoPreparacion.demasiados : EstadoPreparacion.lista,
      );
    } catch (_) {
      _poner(EstadoPreparacion.error);
    }
  }

  /// «Más tarde» o «Entendido»: Caja sigue, con límites.
  void posponer() => _poner(EstadoPreparacion.pospuesta);

  /// El aviso de «Listo» ya se vio.
  void cerrarListo() {
    if (_estado == EstadoPreparacion.lista) {
      _poner(EstadoPreparacion.noHaceFalta);
    }
  }

  void _poner(EstadoPreparacion nuevo) {
    _estado = nuevo;
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
