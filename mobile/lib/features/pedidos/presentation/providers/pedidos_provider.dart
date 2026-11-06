import 'package:flutter/foundation.dart';

import '../../application/services/busqueda_pedidos.dart';
import '../../application/services/indicadores_pedidos.dart';
import '../../application/services/por_preparar_pedidos.dart';
import '../../application/services/transiciones_pedido.dart';
import '../../application/use_cases/avanzar_pedido.dart';
import '../../application/use_cases/cancelar_pedido.dart';
import '../../application/use_cases/cancelar_vencidos.dart';
import '../../application/use_cases/confirmar_pedido.dart';
import '../../application/use_cases/marcar_pago_pedido.dart';
import '../../application/use_cases/marcar_reembolso_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/resumen_ventas_dia.dart';
import '../../domain/repositories/repositorio_pedidos.dart';
import 'acciones_pedidos.dart';
import 'escucha_pedidos.dart';
import 'pestana_pedidos.dart';
import 'resultado_accion.dart';

export 'pestana_pedidos.dart';
export 'resultado_accion.dart';

// ═════════════════════════════════════════════════════════════════════════
// PedidosProvider
// ═════════════════════════════════════════════════════════════════════════
// El estado de la pantalla de pedidos abiertos: dos pestañas (Nuevos, Activos)
// con los 10 más recientes EN VIVO y «Ver más» de 10 en 10. Reparte el
// trabajo en dos piezas y solo las une para la pantalla:
//   - [EscuchaPedidos]: lo que se lee (listeners, resumen del día, Ver más).
//   - [AccionesPedidos]: lo que se hace (confirmar, cancelar, avanzar…).
//
// QUÉ NO HACE: no habla con Firestore (usa RepositorioPedidos y los casos de
// uso), no calcula dinero ni stock, no construye widgets. Los textos de los
// pedidos vienen de una tienda pública: se tratan siempre como texto plano.
// ═════════════════════════════════════════════════════════════════════════
class PedidosProvider extends ChangeNotifier {
  PedidosProvider({
    required this.negocioId,
    required RepositorioPedidos repositorio,
    required ConfirmarPedido confirmarPedido,
    required CancelarPedido cancelarPedido,
    required AvanzarPedido avanzarPedido,
    required MarcarPagoPedido marcarPagoPedido,
    required MarcarReembolsoPedido marcarReembolsoPedido,
    required CancelarVencidos cancelarVencidos,
    int tamanoPagina = 10,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now {
    _escucha = EscuchaPedidos(
      negocioId: negocioId,
      repositorio: repositorio,
      tamano: tamanoPagina,
      reloj: _reloj,
      onCambio: _notificar,
    );
    _acciones = AccionesPedidos(
      negocioId: negocioId,
      confirmarPedido: confirmarPedido,
      cancelarPedido: cancelarPedido,
      avanzarPedido: avanzarPedido,
      marcarPagoPedido: marcarPagoPedido,
      marcarReembolsoPedido: marcarReembolsoPedido,
      cancelarVencidos: cancelarVencidos,
      tamano: tamanoPagina,
      reloj: _reloj,
      onCambio: _notificar,
      alCambiarPedido: _escucha.olvidarCopiaVieja,
      reiniciarNuevos: () =>
          _escucha.reiniciarPaginas(PestanaPedidos.nuevos, avisar: false),
    );
  }

  final String negocioId;
  final DateTime Function() _reloj;
  late final EscuchaPedidos _escucha;
  late final AccionesPedidos _acciones;
  PestanaPedidos _pestana = PestanaPedidos.nuevos;
  String _busqueda = '';
  final Set<String> _seleccionados = {};
  bool _disposed = false;

  // ── Lectura ───────────────────────────────────────────────────────────

  PestanaPedidos get pestana => _pestana;
  ResumenVentasDia get resumenHoy => _escucha.resumenHoy;
  String? get error => _escucha.error;
  bool get cancelandoVencidos => _acciones.cancelandoVencidos;
  bool get pausado => _escucha.pausado;

  List<Pedido> get pedidosActuales => _escucha.lista(_pestana).pedidos;
  List<Pedido> pedidosDe(PestanaPedidos p) => _escucha.lista(p).pedidos;

  /// «3», o «10+» si hay más sin cargar. Sale de lo cargado: 0 lecturas.
  String conteo(PestanaPedidos p) => _escucha.lista(p).etiquetaConteo;
  bool hayMas(PestanaPedidos p) => _escucha.lista(p).hayMas;
  bool cargando(PestanaPedidos p) => _escucha.cargando(p);
  bool cargandoMas(PestanaPedidos p) => _escucha.cargandoMas(p);
  bool procesando(String pedidoId) => _acciones.procesando(pedidoId);

  /// Pedidos nuevos ya cargados con más de 12 h (para «Cancelar vencidos (N)»).
  int get vencidosCargados {
    final ahora = _reloj();
    return _escucha
        .lista(PestanaPedidos.nuevos)
        .pedidos
        .where((p) => TransicionesPedido.estaVencido(p, ahora))
        .length;
  }

  /// El pedido con ese id en cualquiera de las pestañas cargadas, o null.
  Pedido? buscar(String pedidoId) {
    for (final lista in _escucha.listas) {
      for (final pedido in lista.pedidos) {
        if (pedido.id == pedidoId) return pedido;
      }
    }
    return null;
  }

  /// Los números de arriba (PC y TV), sacados de lo YA cargado: 0 lecturas.
  IndicadoresPedidos get indicadores => IndicadoresPedidos.calcular(
    nuevos: _escucha.lista(PestanaPedidos.nuevos).pedidos,
    activos: _escucha.lista(PestanaPedidos.activos).pedidos,
    ahora: _reloj(),
  );

  /// Lo que falta cobrar entre los pedidos YA cargados (Nuevos y Activos), en
  /// céntimos. No es el total del negocio: solo lo cargado, sin lecturas extra.
  int get porCobrarCargadoCentavos => indicadores.porCobrarCentavos;

  /// «Por preparar ahora»: suma de lo pedido en los nuevos y confirmados
  /// cargados.
  List<ItemPorPreparar> get porPreparar => PorPrepararPedidos.sumar([
    for (final lista in _escucha.listas) ...lista.pedidos,
  ]);

  // ── Búsqueda y selección (PC) ─────────────────────────────────────────

  String get busqueda => _busqueda;

  /// Los pedidos de la pestaña que coinciden con la búsqueda (solo entre los
  /// cargados: 0 lecturas).
  List<Pedido> get pedidosFiltrados =>
      BusquedaPedidos.filtrar(pedidosActuales, _busqueda);

  void actualizarBusqueda(String texto) {
    if (texto == _busqueda) return;
    _busqueda = texto;
    _notificar();
  }

  Set<String> get seleccionados => Set.unmodifiable(_seleccionados);
  bool estaSeleccionado(String pedidoId) => _seleccionados.contains(pedidoId);

  void alternarSeleccion(String pedidoId) {
    if (!_seleccionados.remove(pedidoId)) _seleccionados.add(pedidoId);
    _notificar();
  }

  /// Marca o desmarca todos los que se ven (los filtrados de la pestaña).
  void seleccionarVisibles(bool marcar) {
    final ids = pedidosFiltrados.map((p) => p.id);
    if (marcar) {
      _seleccionados.addAll(ids);
    } else {
      _seleccionados.removeAll(ids);
    }
    _notificar();
  }

  void limpiarSeleccion() {
    if (_seleccionados.isEmpty) return;
    _seleccionados.clear();
    _notificar();
  }

  /// Confirma los seleccionados que sigan nuevos, de uno en uno. La selección
  /// se limpia al terminar.
  Future<ResultadoAccion> confirmarSeleccionados() async {
    final pedidos = [for (final id in _seleccionados) ?buscar(id)];
    final resultado = await _acciones.confirmarVarios(pedidos);
    _seleccionados.clear();
    _notificar();
    return resultado;
  }

  void seleccionarPestana(PestanaPedidos p) {
    if (_pestana == p) return;
    _pestana = p;
    _notificar();
  }

  // ── Escucha en vivo ───────────────────────────────────────────────────

  void iniciar() => _escucha.iniciar();
  void pausar() => _escucha.pausar();
  void reanudar() => _escucha.reanudar();
  void reintentar() => _escucha.reintentar();
  void revisarDia() => _escucha.revisarDia();

  Future<ResultadoAccion> verMas(PestanaPedidos p) => _escucha.verMas(p);
  void reiniciarPaginas(PestanaPedidos p) => _escucha.reiniciarPaginas(p);

  // ── Acciones ──────────────────────────────────────────────────────────

  Future<ResultadoAccion> confirmar(Pedido pedido) =>
      _acciones.confirmar(pedido);
  Future<ResultadoAccion> cancelar(Pedido pedido) => _acciones.cancelar(pedido);

  /// Pasa al estado siguiente. Al entregar, [cobrado] marca el pago a la vez.
  Future<ResultadoAccion> avanzar(Pedido pedido, {bool cobrado = false}) =>
      _acciones.avanzar(pedido, cobrado: cobrado);
  Future<ResultadoAccion> marcarPago(Pedido pedido, EstadoPago pago) =>
      _acciones.marcarPago(pedido, pago);
  Future<ResultadoAccion> marcarReembolsoHecho(Pedido pedido) =>
      _acciones.marcarReembolsoHecho(pedido);

  /// Cancela los vencidos de 10 en 10 (se detiene si una tanda no cancela).
  Future<ResultadoAccion> cancelarVencidos() => _acciones.cancelarVencidos();

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _escucha.cerrar();
    super.dispose();
  }
}
