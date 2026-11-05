import 'dart:async';
import 'dart:collection';

import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_pedidos.dart';

/// Repositorio falso: anota las llamadas, emite listas en vivo cuando se le
/// pide y falla donde se le indica.
class RepositorioPedidosFake implements RepositorioPedidos {
  final llamadas = <String>[];
  EstadoPedido? estadoAvanzado;
  EstadoPago? pagoAvanzado;
  DateTime? corteVencidos;

  ResultadoConfirmar resultadoConfirmar = const ResultadoConfirmar();
  int omitidosAlCancelar = 0;

  /// Cada llamada a obtenerVencidos saca la siguiente tanda (vacía si no hay).
  final Queue<List<Pedido>> tandasVencidos = Queue();

  /// Qué pasa al cancelar cada id: lo que se lance, o nada si no está.
  final Map<String, Object> falloAlCancelar = {};

  /// Si se pone, confirmar espera a que se complete (para probar el doble toque).
  Completer<void>? esperaAlConfirmar;

  /// Si se pone, se lanza al abrir la escucha.
  Object? fallaAlEscuchar;

  // ── En vivo ──
  final _controladores = <String, StreamController<List<Pedido>>>{};
  final escuchas = <String>[];
  int oyentesActivos = 0;

  String _clave(Set<EstadoPedido>? estados) {
    final valores = [for (final e in estados ?? <EstadoPedido>{}) e.valor]
      ..sort();
    return valores.join('+');
  }

  /// Emite la lista en vivo de la consulta de esos estados.
  void emitir(Set<EstadoPedido> estados, List<Pedido> pedidos) {
    _controladores[_clave(estados)]!.add(pedidos);
  }

  /// La consulta en vivo falla (por ejemplo, sin conexión).
  void fallar(Set<EstadoPedido> estados) {
    _controladores[_clave(estados)]!.addError(Exception('sin conexión'));
  }

  // ── Ver más ──
  final paginas = Queue<PaginaPedidos>();
  Completer<void>? esperaVerMas;
  Object? fallaAlVerMas;
  final despuesDeVerMas = <String>[];

  @override
  Stream<List<Pedido>> escucharAbiertos(
    String negocioId, {
    Set<EstadoPedido>? estados,
    int limite = 10,
  }) {
    final falla = fallaAlEscuchar;
    if (falla != null) throw falla;
    final clave = _clave(estados);
    escuchas.add(clave);
    final controlador = StreamController<List<Pedido>>(
      onListen: () => oyentesActivos++,
      onCancel: () => oyentesActivos--,
    );
    _controladores[clave] = controlador;
    return controlador.stream;
  }

  @override
  Future<PaginaPedidos> obtenerAbiertosDespuesDe(
    String negocioId,
    Pedido despuesDe, {
    Set<EstadoPedido>? estados,
    int limite = 10,
  }) async {
    despuesDeVerMas.add(despuesDe.id);
    await esperaVerMas?.future;
    final falla = fallaAlVerMas;
    if (falla != null) throw falla;
    return paginas.removeFirst();
  }

  @override
  Future<List<Pedido>> obtenerVencidos(
    String negocioId, {
    required DateTime antesDe,
    int limite = 10,
  }) async {
    corteVencidos = antesDe;
    return tandasVencidos.isEmpty ? const [] : tandasVencidos.removeFirst();
  }

  @override
  Future<PaginaPedidos> obtenerHistorial(
    String negocioId, {
    CursorPedidos? despuesDe,
    int limite = 20,
  }) async {
    llamadas.add('historial:${despuesDe == null ? 'inicio' : 'siguiente'}');
    final falla = fallaAlVerMas;
    if (falla != null) throw falla;
    return paginas.removeFirst();
  }

  // ── Acciones ──
  @override
  Future<ResultadoConfirmar> confirmar(
    String negocioId,
    String pedidoId,
  ) async {
    llamadas.add('confirmar:$pedidoId');
    await esperaAlConfirmar?.future;
    return resultadoConfirmar;
  }

  @override
  Future<int> cancelar(
    String negocioId,
    String pedidoId, {
    bool soloSiEstaNuevo = false,
  }) async {
    llamadas.add('cancelar:$pedidoId:$soloSiEstaNuevo');
    final fallo = falloAlCancelar[pedidoId];
    if (fallo != null) throw fallo;
    return omitidosAlCancelar;
  }

  @override
  Future<void> avanzar(
    String negocioId,
    String pedidoId,
    EstadoPedido nuevo, {
    EstadoPago? pago,
  }) async {
    llamadas.add('avanzar:$pedidoId');
    estadoAvanzado = nuevo;
    pagoAvanzado = pago;
  }

  @override
  Future<void> marcarPago(
    String negocioId,
    String pedidoId,
    EstadoPago pago,
  ) async {
    llamadas.add('pago:$pedidoId:${pago.valor}');
  }

  @override
  Future<void> marcarReembolsoHecho(String negocioId, String pedidoId) async {
    llamadas.add('reembolso:$pedidoId');
  }
}
