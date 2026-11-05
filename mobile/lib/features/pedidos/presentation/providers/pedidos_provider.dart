import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/services/lista_pedidos_paginada.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/transiciones_pedido.dart';
import '../../application/use_cases/avanzar_pedido.dart';
import '../../application/use_cases/cancelar_pedido.dart';
import '../../application/use_cases/cancelar_vencidos.dart';
import '../../application/use_cases/confirmar_pedido.dart';
import '../../application/use_cases/marcar_pago_pedido.dart';
import '../../application/use_cases/marcar_reembolso_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/repositories/repositorio_pedidos.dart';

/// Las pestañas de pedidos abiertos. Cada una escucha SU consulta de 10.
enum PestanaPedidos {
  nuevos('Nuevos', {EstadoPedido.nuevo}),
  activos('Activos', {
    EstadoPedido.confirmado,
    EstadoPedido.enCamino,
    EstadoPedido.listo,
  });

  const PestanaPedidos(this.etiqueta, this.estados);

  final String etiqueta;
  final Set<EstadoPedido> estados;
}

enum TipoResultado { exito, aviso, error, ignorado }

/// Lo que la pantalla muestra después de una acción. [mensaje] es texto plano.
class ResultadoAccion {
  const ResultadoAccion(this.tipo, [this.mensaje = '']);

  const ResultadoAccion.ignorado() : this(TipoResultado.ignorado);

  final TipoResultado tipo;
  final String mensaje;

  bool get hizoAlgo => tipo != TipoResultado.ignorado;
  bool get fallo => tipo == TipoResultado.error;
}

// ═════════════════════════════════════════════════════════════════════════
// PedidosProvider
// ═════════════════════════════════════════════════════════════════════════
// El estado de la pantalla de pedidos abiertos: dos pestañas (Nuevos, Activos)
// con los 10 más recientes EN VIVO y «Ver más» de 10 en 10.
//
// Ahorro de lecturas:
//   - 2 listeners de 10 documentos (20 lecturas al abrir), nada más.
//   - [pausar] los cierra (pestaña del navegador oculta o app en segundo plano)
//     y [reanudar] los reabre; las listas ya cargadas se conservan.
//   - Las insignias salen de lo cargado («10+»): 0 lecturas.
//   - dispose() cierra todo.
//
// QUÉ NO HACE: no habla con Firestore (usa RepositorioPedidos y los casos de
// uso), no calcula dinero ni stock, no construye widgets. Los textos de los
// pedidos vienen de una tienda pública: se tratan siempre como texto plano.
// ═════════════════════════════════════════════════════════════════════════
class PedidosProvider extends ChangeNotifier {
  PedidosProvider({
    required this.negocioId,
    required this._repositorio,
    required this._confirmarPedido,
    required this._cancelarPedido,
    required this._avanzarPedido,
    required this._marcarPagoPedido,
    required this._marcarReembolsoPedido,
    required this._cancelarVencidos,
    int tamanoPagina = 10,
    DateTime Function()? reloj,
  }) : _tamano = tamanoPagina,
       _reloj = reloj ?? DateTime.now {
    for (final pestana in PestanaPedidos.values) {
      _listas[pestana] = ListaPedidosPaginada(tamano: _tamano);
    }
  }

  /// Máximo de tandas seguidas al cancelar vencidos (tope contra bucles).
  static const int _maxTandasVencidos = 20;

  final String negocioId;
  final RepositorioPedidos _repositorio;
  final ConfirmarPedido _confirmarPedido;
  final CancelarPedido _cancelarPedido;
  final AvanzarPedido _avanzarPedido;
  final MarcarPagoPedido _marcarPagoPedido;
  final MarcarReembolsoPedido _marcarReembolsoPedido;
  final CancelarVencidos _cancelarVencidos;
  final int _tamano;
  final DateTime Function() _reloj;

  final Map<PestanaPedidos, ListaPedidosPaginada> _listas = {};
  final Map<PestanaPedidos, StreamSubscription<List<Pedido>>> _suscripciones =
      {};
  final Set<PestanaPedidos> _esperandoPrimeraCarga = {};
  final Set<PestanaPedidos> _cargandoMas = {};
  final Set<String> _procesando = {};
  PestanaPedidos _pestana = PestanaPedidos.nuevos;
  String? _error;
  bool _iniciado = false;
  bool _pausado = false;
  bool _cancelandoVencidos = false;
  bool _disposed = false;

  // ── Lectura ───────────────────────────────────────────────────────────

  PestanaPedidos get pestana => _pestana;
  String? get error => _error;
  bool get cancelandoVencidos => _cancelandoVencidos;
  bool get pausado => _pausado;

  List<Pedido> get pedidosActuales => _listas[_pestana]!.pedidos;
  List<Pedido> pedidosDe(PestanaPedidos p) => _listas[p]!.pedidos;

  /// «3», o «10+» si hay más sin cargar. Sale de lo cargado: 0 lecturas.
  String conteo(PestanaPedidos p) => _listas[p]!.etiquetaConteo;
  bool hayMas(PestanaPedidos p) => _listas[p]!.hayMas;
  bool cargando(PestanaPedidos p) => _esperandoPrimeraCarga.contains(p);
  bool cargandoMas(PestanaPedidos p) => _cargandoMas.contains(p);
  bool procesando(String pedidoId) => _procesando.contains(pedidoId);

  /// Pedidos nuevos ya cargados con más de 12 h (para «Cancelar vencidos (N)»).
  int get vencidosCargados {
    final ahora = _reloj();
    return _listas[PestanaPedidos.nuevos]!.pedidos
        .where((p) => TransicionesPedido.estaVencido(p, ahora))
        .length;
  }

  void seleccionarPestana(PestanaPedidos p) {
    if (_pestana == p) return;
    _pestana = p;
    _notificar();
  }

  // ── Escucha en vivo ───────────────────────────────────────────────────

  /// Abre los dos listeners. Se llama una vez al mostrar la pantalla.
  void iniciar() {
    if (_iniciado || _disposed) return;
    _iniciado = true;
    _suscribir(conSpinner: true);
  }

  /// Cierra los listeners sin perder lo cargado (pestaña oculta, app en
  /// segundo plano): nadie mira, no se leen pedidos.
  void pausar() {
    if (!_iniciado || _pausado || _disposed) return;
    _pausado = true;
    _cerrarSuscripciones();
    _esperandoPrimeraCarga.clear();
    _notificar();
  }

  void reanudar() {
    if (!_pausado || _disposed) return;
    _pausado = false;
    _suscribir(conSpinner: false);
    _notificar();
  }

  /// Después de un error de conexión.
  void reintentar() {
    if (!_iniciado || _disposed) return;
    _error = null;
    _suscribir(conSpinner: true);
    _notificar();
  }

  void _suscribir({required bool conSpinner}) {
    for (final pestana in PestanaPedidos.values) {
      if (_suscripciones.containsKey(pestana)) continue;
      if (conSpinner) _esperandoPrimeraCarga.add(pestana);
      try {
        _suscripciones[pestana] = _repositorio
            .escucharAbiertos(
              negocioId,
              estados: pestana.estados,
              limite: _tamano,
            )
            .listen(
              (pedidos) => _llegaron(pestana, pedidos),
              onError: (Object _) => _fallo(pestana),
            );
      } catch (_) {
        _fallo(pestana);
      }
    }
  }

  void _llegaron(PestanaPedidos pestana, List<Pedido> pedidos) {
    _listas[pestana] = _listas[pestana]!.conCabeza(pedidos);
    _esperandoPrimeraCarga.remove(pestana);
    _error = null;
    _notificar();
  }

  void _fallo(PestanaPedidos pestana) {
    _suscripciones.remove(pestana)?.cancel();
    _esperandoPrimeraCarga.remove(pestana);
    _error = 'No se pudieron cargar tus pedidos. Revisa tu conexión.';
    _notificar();
  }

  void _cerrarSuscripciones() {
    for (final suscripcion in _suscripciones.values) {
      suscripcion.cancel();
    }
    _suscripciones.clear();
  }

  // ── Ver más ───────────────────────────────────────────────────────────

  /// Trae los siguientes 10 más viejos de la pestaña (lectura puntual).
  Future<ResultadoAccion> verMas(PestanaPedidos p) async {
    final lista = _listas[p]!;
    final ultimo = lista.ultimoConFecha;
    if (_cargandoMas.contains(p) || !lista.hayMas || ultimo == null) {
      return const ResultadoAccion.ignorado();
    }
    _cargandoMas.add(p);
    _notificar();
    try {
      final pagina = await _repositorio.obtenerAbiertosDespuesDe(
        negocioId,
        ultimo,
        estados: p.estados,
        limite: _tamano,
      );
      _listas[p] = _listas[p]!.conPagina(pagina.pedidos, hayMas: pagina.hayMas);
      return const ResultadoAccion(TipoResultado.exito);
    } catch (_) {
      return const ResultadoAccion(
        TipoResultado.error,
        'No se pudieron cargar más pedidos.',
      );
    } finally {
      _cargandoMas.remove(p);
      _notificar();
    }
  }

  /// Descarta lo traído con «Ver más» (jalar para actualizar). La cabeza en
  /// vivo ya está al día.
  void reiniciarPaginas(PestanaPedidos p) {
    _listas[p] = _listas[p]!.sinPaginas();
    _notificar();
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  Future<ResultadoAccion> confirmar(Pedido pedido) {
    return _ejecutar(pedido.id, () async {
      final r = await _confirmarPedido(
        negocioId: negocioId,
        pedidoId: pedido.id,
      );
      if (r.ok || r.yaNoEsNuevo) _olvidarCopiaVieja(pedido.id);
      if (!r.ok) {
        return ResultadoAccion(
          TipoResultado.error,
          MensajesAccionPedido.confirmarBloqueado(r),
        );
      }
      return ResultadoAccion(
        r.totalActualCentavos == null
            ? TipoResultado.exito
            : TipoResultado.aviso,
        MensajesAccionPedido.confirmado(r, pedido.totalCentavos),
      );
    });
  }

  Future<ResultadoAccion> cancelar(Pedido pedido) {
    return _ejecutar(pedido.id, () async {
      final sinDevolver = await _cancelarPedido(
        negocioId: negocioId,
        pedidoId: pedido.id,
      );
      _olvidarCopiaVieja(pedido.id);
      return ResultadoAccion(
        sinDevolver == 0 ? TipoResultado.exito : TipoResultado.aviso,
        MensajesAccionPedido.cancelado(sinDevolver),
      );
    });
  }

  /// Pasa al estado siguiente. Al entregar, [cobrado] marca el pago a la vez.
  Future<ResultadoAccion> avanzar(Pedido pedido, {bool cobrado = false}) {
    return _ejecutar(pedido.id, () async {
      final nuevo = await _avanzarPedido(
        negocioId: negocioId,
        pedido: pedido,
        cobrado: cobrado,
      );
      _olvidarCopiaVieja(pedido.id);
      return ResultadoAccion(
        TipoResultado.exito,
        'Pedido ${nuevo.etiqueta.toLowerCase()}.',
      );
    });
  }

  Future<ResultadoAccion> marcarPago(Pedido pedido, EstadoPago pago) {
    return _ejecutar(pedido.id, () async {
      await _marcarPagoPedido(
        negocioId: negocioId,
        pedidoId: pedido.id,
        pago: pago,
      );
      _olvidarCopiaVieja(pedido.id);
      return ResultadoAccion(
        TipoResultado.exito,
        pago == EstadoPago.pagado
            ? 'Marcado como cobrado.'
            : 'Marcado como pendiente de cobro.',
      );
    });
  }

  Future<ResultadoAccion> marcarReembolsoHecho(Pedido pedido) {
    return _ejecutar(pedido.id, () async {
      await _marcarReembolsoPedido(negocioId: negocioId, pedidoId: pedido.id);
      return const ResultadoAccion(
        TipoResultado.exito,
        'Reembolso marcado como hecho.',
      );
    });
  }

  /// Cancela los vencidos de 10 en 10. Se detiene cuando una tanda no cancela
  /// ninguno (por ejemplo, sin conexión), no queda más, o tras
  /// [_maxTandasVencidos] tandas.
  Future<ResultadoAccion> cancelarVencidos() async {
    if (_cancelandoVencidos) return const ResultadoAccion.ignorado();
    _cancelandoVencidos = true;
    _notificar();
    var canceladas = 0;
    var omitidas = 0;
    var fallidas = 0;
    try {
      for (var tanda = 0; tanda < _maxTandasVencidos; tanda++) {
        final r = await _cancelarVencidos(
          negocioId: negocioId,
          ahora: _reloj(),
          limite: _tamano,
        );
        canceladas += r.canceladas;
        omitidas += r.omitidas;
        fallidas += r.fallidas;
        if (!r.hayMas || r.canceladas == 0) break;
      }
    } catch (_) {
      fallidas++;
    } finally {
      // No se sabe cuáles se cancelaron: lo traído con «Ver más» queda viejo.
      _listas[PestanaPedidos.nuevos] = _listas[PestanaPedidos.nuevos]!
          .sinPaginas();
      _cancelandoVencidos = false;
      _notificar();
    }
    final resultado = ResultadoCancelarVencidos(
      canceladas: canceladas,
      omitidas: omitidas,
      fallidas: fallidas,
    );
    return ResultadoAccion(
      fallidas > 0 ? TipoResultado.aviso : TipoResultado.exito,
      MensajesAccionPedido.vencidos(resultado),
    );
  }

  /// Un solo pedido a la vez: un doble toque no repite la acción. Los errores
  /// se convierten en texto para el vendedor, sin mostrar detalles internos.
  Future<ResultadoAccion> _ejecutar(
    String pedidoId,
    Future<ResultadoAccion> Function() accion,
  ) async {
    if (_procesando.contains(pedidoId)) {
      return const ResultadoAccion.ignorado();
    }
    _procesando.add(pedidoId);
    _notificar();
    try {
      return await accion();
    } on StateError catch (e) {
      _olvidarCopiaVieja(pedidoId);
      return ResultadoAccion(TipoResultado.error, e.message);
    } on ArgumentError {
      return const ResultadoAccion(
        TipoResultado.error,
        'No se pudo completar la acción.',
      );
    } catch (_) {
      return const ResultadoAccion(
        TipoResultado.error,
        'No se pudo completar. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      _procesando.remove(pedidoId);
      _notificar();
    }
  }

  /// El pedido cambió: su copia traída con «Ver más» quedó vieja. La de la
  /// cabeza en vivo se corrige sola.
  void _olvidarCopiaVieja(String pedidoId) {
    for (final p in PestanaPedidos.values) {
      _listas[p] = _listas[p]!.sinPedidoViejo(pedidoId);
    }
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cerrarSuscripciones();
    super.dispose();
  }
}
