import 'dart:async';
import 'dart:collection';

import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/filtro_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
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

  String _clave(FiltroPedidos filtro) => filtro.name;

  /// Emite la lista en vivo de la consulta de ese filtro.
  void emitir(FiltroPedidos filtro, List<Pedido> pedidos) {
    _controladores[_clave(filtro)]!.add(pedidos);
  }

  /// La consulta en vivo falla (por ejemplo, sin conexión).
  void fallar(FiltroPedidos filtro) {
    _controladores[_clave(filtro)]!.addError(Exception('sin conexión'));
  }

  /// Cuántos oyentes tiene ahora la consulta de ese filtro.
  int oyentesDe(FiltroPedidos filtro) => _oyentes[_clave(filtro)] ?? 0;
  final _oyentes = <String, int>{};

  /// Lo que devuelve la suma de «por cobrar» (null = falla).
  int? sumaPorCobrar = 0;
  int sumasPedidas = 0;

  @override
  Future<int> sumarPorCobrar(String negocioId) async {
    sumasPedidas++;
    final suma = sumaPorCobrar;
    if (suma == null) throw StateError('sin índice');
    return suma;
  }

  // ── Resumen del día ──
  final _resumenes = <String, StreamController<ResumenVentasDia>>{};
  final escuchasResumen = <String>[];
  int resumenesActivos = 0;
  Object? fallaAlEscucharResumen;

  /// Emite el resumen de ese día (AAAA-MM-DD).
  void emitirResumen(ResumenVentasDia resumen) {
    _resumenes[resumen.dia]!.add(resumen);
  }

  @override
  Stream<ResumenVentasDia> escucharResumenDia(String negocioId, String dia) {
    final falla = fallaAlEscucharResumen;
    if (falla != null) throw falla;
    escuchasResumen.add(dia);
    final controlador = StreamController<ResumenVentasDia>(
      onListen: () => resumenesActivos++,
      onCancel: () => resumenesActivos--,
    );
    _resumenes[dia] = controlador;
    return controlador.stream;
  }

  // ── Ver más ──
  final paginas = Queue<PaginaPedidos>();
  Completer<void>? esperaVerMas;
  Object? fallaAlVerMas;
  final despuesDeVerMas = <String>[];

  @override
  Stream<List<Pedido>> escucharPedidos(
    String negocioId, {
    FiltroPedidos filtro = FiltroPedidos.todos,
    int limite = 10,
  }) {
    final falla = fallaAlEscuchar;
    if (falla != null) throw falla;
    final clave = _clave(filtro);
    escuchas.add(clave);
    final controlador = StreamController<List<Pedido>>(
      onListen: () {
        oyentesActivos++;
        _oyentes[clave] = (_oyentes[clave] ?? 0) + 1;
      },
      onCancel: () {
        oyentesActivos--;
        _oyentes[clave] = (_oyentes[clave] ?? 1) - 1;
      },
    );
    _controladores[clave] = controlador;
    return controlador.stream;
  }

  @override
  Future<PaginaPedidos> obtenerPedidosDespuesDe(
    String negocioId,
    Pedido despuesDe, {
    FiltroPedidos filtro = FiltroPedidos.todos,
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
