import 'package:flutter/foundation.dart';

import '../../application/services/resumen_dia_pedidos.dart';
import '../../domain/models/pedido.dart';
import '../../domain/repositories/repositorio_pedidos.dart';

// ═════════════════════════════════════════════════════════════════════════
// HistorialPedidosProvider
// ═════════════════════════════════════════════════════════════════════════
// El historial (entregados y cancelados), agrupado por día en hora de Lima.
//
// Ahorro de lecturas:
//   - No escucha nada: solo lee cuando el vendedor abre «Historial»
//     ([cargar]: 20 lecturas) y cuando pide «Ver más» (20 por toque).
//   - Abrirlo otra vez no relee lo ya cargado; [refrescar] lo relee a pedido.
//   - Por eso no se actualiza solo: un pedido recién entregado aparece al
//     refrescar.
//
// QUÉ NO HACE: no habla con Firestore (usa RepositorioPedidos), no construye
// widgets. Los nombres de los clientes son texto plano.
// ═════════════════════════════════════════════════════════════════════════
class HistorialPedidosProvider extends ChangeNotifier {
  HistorialPedidosProvider({
    required this.negocioId,
    required this._repositorio,
    int tamanoPagina = 20,
  }) : _tamano = tamanoPagina;

  final String negocioId;
  final RepositorioPedidos _repositorio;
  final int _tamano;

  List<Pedido> _pedidos = [];
  CursorPedidos? _cursor;
  bool _hayMas = false;
  bool _cargado = false;
  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;
  List<ResumenDia>? _diasCache;
  bool _disposed = false;

  bool get cargado => _cargado;
  bool get cargando => _cargando;
  bool get cargandoMas => _cargandoMas;
  bool get hayMas => _hayMas;
  String? get error => _error;
  int get totalCargados => _pedidos.length;

  /// Los días del más nuevo al más viejo, con lo entregado y cancelado de cada
  /// uno. Si [hayMas], el día más viejo puede estar incompleto (sus demás
  /// pedidos llegan con la página siguiente).
  List<ResumenDia> get dias =>
      _diasCache ??= List.unmodifiable(ResumenDiaPedidos.agrupar(_pedidos));

  bool get ultimoDiaPuedeEstarIncompleto => _hayMas;

  /// Primera página. Si ya se cargó, no vuelve a leer ([refrescar] sí).
  Future<void> cargar() async {
    if (_cargado || _cargando) return;
    await _cargarPrimeraPagina();
  }

  /// Vuelve a leer desde el principio (jalar para actualizar).
  Future<void> refrescar() async {
    if (_cargando || _cargandoMas) return;
    await _cargarPrimeraPagina();
  }

  Future<void> _cargarPrimeraPagina() async {
    _cargando = true;
    _error = null;
    _notificar();
    try {
      final pagina = await _repositorio.obtenerHistorial(
        negocioId,
        limite: _tamano,
      );
      _pedidos = List<Pedido>.of(pagina.pedidos);
      _cursor = pagina.ultimoCursor;
      _hayMas = pagina.hayMas;
      _cargado = true;
      _diasCache = null;
    } catch (_) {
      _error = 'No se pudo cargar el historial. Revisa tu conexión.';
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  /// Los siguientes 20, a partir del cursor guardado. No repite pedidos.
  Future<void> cargarMas() async {
    final cursor = _cursor;
    if (!_cargado || _cargando || _cargandoMas || !_hayMas || cursor == null) {
      return;
    }
    _cargandoMas = true;
    _error = null;
    _notificar();
    try {
      final pagina = await _repositorio.obtenerHistorial(
        negocioId,
        despuesDe: cursor,
        limite: _tamano,
      );
      final ids = {for (final p in _pedidos) p.id};
      _pedidos = [
        ..._pedidos,
        for (final p in pagina.pedidos)
          if (ids.add(p.id)) p,
      ];
      _cursor = pagina.ultimoCursor ?? cursor;
      _hayMas = pagina.hayMas;
      _diasCache = null;
    } catch (_) {
      _error = 'No se pudieron cargar más pedidos.';
    } finally {
      _cargandoMas = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
