import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/services/lista_pedidos_paginada.dart';
import '../../application/services/resumen_dia_pedidos.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/resumen_ventas_dia.dart';
import '../../domain/repositories/repositorio_pedidos.dart';
import 'pestana_pedidos.dart';
import 'resultado_accion.dart';

// ═════════════════════════════════════════════════════════════════════════
// EscuchaPedidos
// ═════════════════════════════════════════════════════════════════════════
// Lo que se lee de Firestore para la pantalla de pedidos abiertos: los
// listeners en vivo (2 pestañas de 10 pedidos y el resumen del día), «Ver
// más» y las listas ya cargadas. No es un ChangeNotifier: avisa con
// [onCambio] y lo usa `PedidosProvider`.
//
// Ahorro de lecturas:
//   - 2 listeners de 10 documentos y 1 documento (el resumen de hoy).
//   - [pausar] los cierra y [reanudar] los reabre; lo cargado se conserva.
//   - Las insignias salen de lo cargado («10+»): 0 lecturas.
// ═════════════════════════════════════════════════════════════════════════
class EscuchaPedidos {
  EscuchaPedidos({
    required this.negocioId,
    required this._repositorio,
    required this._tamano,
    required this._reloj,
    required this.onCambio,
  }) {
    for (final pestana in PestanaPedidos.values) {
      _listas[pestana] = ListaPedidosPaginada(tamano: _tamano);
    }
  }

  final String negocioId;
  final RepositorioPedidos _repositorio;
  final int _tamano;
  final DateTime Function() _reloj;
  final VoidCallback onCambio;

  final Map<PestanaPedidos, ListaPedidosPaginada> _listas = {};
  final Map<PestanaPedidos, StreamSubscription<List<Pedido>>> _suscripciones =
      {};
  StreamSubscription<ResumenVentasDia>? _suscripcionResumen;
  String? _diaResumen;
  ResumenVentasDia? _resumen;
  final Set<PestanaPedidos> _esperandoPrimeraCarga = {};
  final Set<PestanaPedidos> _cargandoMas = {};
  String? _error;
  bool _iniciado = false;
  bool _pausado = false;
  bool _cerrada = false;

  // ── Lectura ───────────────────────────────────────────────────────────

  ListaPedidosPaginada lista(PestanaPedidos p) => _listas[p]!;
  Iterable<ListaPedidosPaginada> get listas => _listas.values;

  /// El resumen de ventas de hoy (un solo documento). Vacío mientras llega.
  ResumenVentasDia get resumenHoy =>
      _resumen ?? ResumenVentasDia.vacio(ResumenDiaPedidos.claveDia(_reloj()));
  String? get error => _error;
  bool get pausado => _pausado;
  bool cargando(PestanaPedidos p) => _esperandoPrimeraCarga.contains(p);
  bool cargandoMas(PestanaPedidos p) => _cargandoMas.contains(p);

  // ── Escucha en vivo ───────────────────────────────────────────────────

  /// Abre los listeners. Se llama una vez al mostrar la pantalla.
  void iniciar() {
    if (_iniciado || _cerrada) return;
    _iniciado = true;
    _suscribir(conSpinner: true);
  }

  /// Cierra los listeners sin perder lo cargado (pestaña oculta, app en
  /// segundo plano): nadie mira, no se leen pedidos.
  void pausar() {
    if (!_iniciado || _pausado || _cerrada) return;
    _pausado = true;
    _cerrarSuscripciones();
    _esperandoPrimeraCarga.clear();
    onCambio();
  }

  void reanudar() {
    if (!_pausado || _cerrada) return;
    _pausado = false;
    _suscribir(conSpinner: false);
    onCambio();
  }

  /// Después de un error de conexión.
  void reintentar() {
    if (!_iniciado || _cerrada) return;
    _error = null;
    _suscribir(conSpinner: true);
    onCambio();
  }

  /// Si ya cambió el día (pasó la medianoche), pasa a escuchar el resumen del
  /// día nuevo. Barato: solo compara textos; la pantalla lo llama cada minuto.
  void revisarDia() {
    if (!_iniciado || _pausado || _cerrada) return;
    if (_diaResumen != ResumenDiaPedidos.claveDia(_reloj())) {
      _suscribirResumen();
    }
  }

  /// Cierra todo para siempre (dispose del provider).
  void cerrar() {
    _cerrada = true;
    _cerrarSuscripciones();
  }

  /// 1 documento: 1 lectura al abrir y 1 por cada venta o confirmación nueva.
  /// Si falla, los pedidos siguen funcionando (el resumen es un extra).
  void _suscribirResumen() {
    _suscripcionResumen?.cancel();
    _suscripcionResumen = null;
    final dia = ResumenDiaPedidos.claveDia(_reloj());
    _diaResumen = dia;
    if (_resumen?.dia != dia) _resumen = null;
    try {
      _suscripcionResumen = _repositorio
          .escucharResumenDia(negocioId, dia)
          .listen((resumen) {
            _resumen = resumen;
            onCambio();
          }, onError: (Object _) => _cerrarResumen());
    } catch (_) {
      _cerrarResumen();
    }
  }

  void _cerrarResumen() {
    _suscripcionResumen?.cancel();
    _suscripcionResumen = null;
    _diaResumen = null;
  }

  void _suscribir({required bool conSpinner}) {
    _suscribirResumen();
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
    onCambio();
  }

  void _fallo(PestanaPedidos pestana) {
    _suscripciones.remove(pestana)?.cancel();
    _esperandoPrimeraCarga.remove(pestana);
    _error = 'No se pudieron cargar tus pedidos. Revisa tu conexión.';
    onCambio();
  }

  void _cerrarSuscripciones() {
    for (final suscripcion in _suscripciones.values) {
      suscripcion.cancel();
    }
    _suscripciones.clear();
    _cerrarResumen();
  }

  // ── Ver más ───────────────────────────────────────────────────────────

  /// Trae los siguientes 10 más viejos de la pestaña (lectura puntual).
  Future<ResultadoAccion> verMas(PestanaPedidos p) async {
    final actual = _listas[p]!;
    final ultimo = actual.ultimoConFecha;
    if (_cargandoMas.contains(p) || !actual.hayMas || ultimo == null) {
      return const ResultadoAccion.ignorado();
    }
    _cargandoMas.add(p);
    onCambio();
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
      onCambio();
    }
  }

  /// Descarta lo traído con «Ver más» (jalar para actualizar). La cabeza en
  /// vivo ya está al día. Con [avisar] false no notifica (lo hace quien llama).
  void reiniciarPaginas(PestanaPedidos p, {bool avisar = true}) {
    _listas[p] = _listas[p]!.sinPaginas();
    if (avisar) onCambio();
  }

  /// El pedido cambió: su copia traída con «Ver más» quedó vieja. La de la
  /// cabeza en vivo se corrige sola.
  void olvidarCopiaVieja(String pedidoId) {
    for (final p in PestanaPedidos.values) {
      _listas[p] = _listas[p]!.sinPedidoViejo(pedidoId);
    }
  }
}
