import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../application/services/calculo_stock_pedido.dart';
import '../application/services/resumen_dia_pedidos.dart';
import '../application/services/resumen_ventas_dia_calculo.dart';
import '../application/services/transiciones_pedido.dart';
import '../application/services/verificacion_total_pedido.dart';
import '../domain/models/estado_pedido.dart';
import '../domain/models/filtro_pedidos.dart';
import '../domain/models/pedido.dart';
import '../domain/repositories/repositorio_pedidos.dart';
import '../domain/models/resumen_ventas_dia.dart';
import 'ayudas_pedidos_firestore.dart';
import 'pedido_mapper.dart';
import 'resumen_ventas_dia_mapper.dart';

class _CursorPedidosFirestore implements CursorPedidos {
  const _CursorPedidosFirestore(this.documento);

  final DocumentSnapshot<Map<String, dynamic>> documento;
}

/// Pedidos bajo `negocios/{negocioId}/pedidos`. Confirmar y cancelar mueven
/// stock de varios productos: van en UNA transacción (todo o nada), con todas
/// las lecturas antes de las escrituras.
///
/// Consultas (necesitan el índice compuesto `estado` + `fecha` descendente,
/// ver `firestore.indexes.json`):
///   - abiertos: `estado in (nuevo, confirmado, en_camino, listo)`, límite 50.
///   - historial: `estado in (entregado, cancelado)`, por páginas de 20.
class PedidosRepository implements RepositorioPedidos {
  PedidosRepository({FirebaseFirestore? db, DateTime Function()? reloj})
    : _db = db ?? FirebaseFirestore.instance,
      _reloj = reloj ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _reloj;
  late final AyudasPedidosFirestore _ayudas = AyudasPedidosFirestore(
    db: _db,
    reloj: _reloj,
  );

  static final List<String> _abiertos = [
    for (final e in EstadoPedido.values)
      if (e.abierto) e.valor,
  ];
  static final List<String> _activos = [
    EstadoPedido.confirmado.valor,
    EstadoPedido.enCamino.valor,
    EstadoPedido.listo.valor,
  ];
  static final List<String> _sinCancelar = [
    ..._abiertos,
    EstadoPedido.entregado.valor,
  ];
  static final List<String> _cerrados = [
    for (final e in EstadoPedido.values)
      if (e.esFinal) e.valor,
  ];

  /// Los pedidos que cumplen [filtro], sin orden (para consultar y para sumar).
  Query<Map<String, dynamic>> _filtrar(String negocioId, FiltroPedidos filtro) {
    final base = _ayudas.pedidos(negocioId);
    return switch (filtro) {
      FiltroPedidos.nuevos => base.where(
        'estado',
        isEqualTo: EstadoPedido.nuevo.valor,
      ),
      FiltroPedidos.activos => base.where('estado', whereIn: _activos),
      FiltroPedidos.todos => base.where('estado', whereIn: _abiertos),
      FiltroPedidos.porCobrar =>
        base
            .where('estadoPago', isEqualTo: EstadoPago.pendiente.valor)
            .where('estado', whereIn: _sinCancelar),
      FiltroPedidos.reembolsos =>
        base
            .where('estado', isEqualTo: EstadoPedido.cancelado.valor)
            .where('reembolso', isEqualTo: EstadoReembolso.pendiente.valor),
    };
  }

  /// Del más nuevo al más viejo.
  Query<Map<String, dynamic>> _consulta(
    String negocioId,
    FiltroPedidos filtro,
  ) {
    return _filtrar(negocioId, filtro).orderBy('fecha', descending: true);
  }

  @override
  Stream<List<Pedido>> escucharPedidos(
    String negocioId, {
    FiltroPedidos filtro = FiltroPedidos.todos,
    int limite = 10,
  }) {
    return _consulta(negocioId, filtro)
        .limit(limite)
        .snapshots()
        .map((consulta) => consulta.docs.map(_ayudas.pedido).toList());
  }

  @override
  Future<PaginaPedidos> obtenerPedidosDespuesDe(
    String negocioId,
    Pedido despuesDe, {
    FiltroPedidos filtro = FiltroPedidos.todos,
    int limite = 10,
  }) async {
    final fecha = despuesDe.fecha;
    if (fecha == null) {
      throw ArgumentError.value(despuesDe, 'despuesDe', 'No tiene fecha.');
    }
    // Un documento de más solo para saber si existe otra página.
    final resultado = await _consulta(
      negocioId,
      filtro,
    ).startAfter([Timestamp.fromDate(fecha)]).limit(limite + 1).get();
    return PaginaPedidos(
      pedidos: resultado.docs.take(limite).map(_ayudas.pedido).toList(),
      ultimoCursor: null,
      hayMas: resultado.docs.length > limite,
    );
  }

  @override
  Future<int> sumarPorCobrar(String negocioId) async {
    final resultado = await _filtrar(
      negocioId,
      FiltroPedidos.porCobrar,
    ).aggregate(sum('totalCentavos')).get();
    // La suma llega como número decimal; los totales son enteros, así que el
    // redondeo no pierde nada.
    return (resultado.getSum('totalCentavos') ?? 0).round();
  }

  @override
  Future<List<Pedido>> obtenerVencidos(
    String negocioId, {
    required DateTime antesDe,
    int limite = 10,
  }) async {
    final resultado = await _ayudas
        .pedidos(negocioId)
        .where('estado', isEqualTo: EstadoPedido.nuevo.valor)
        .where('fecha', isLessThan: Timestamp.fromDate(antesDe))
        .orderBy('fecha', descending: true)
        .limit(limite)
        .get();
    return resultado.docs.map(_ayudas.pedido).toList();
  }

  @override
  Future<PaginaPedidos> obtenerHistorial(
    String negocioId, {
    CursorPedidos? despuesDe,
    int limite = 20,
  }) async {
    Query<Map<String, dynamic>> consulta = _ayudas
        .pedidos(negocioId)
        .where('estado', whereIn: _cerrados)
        .orderBy('fecha', descending: true);
    if (despuesDe != null) {
      if (despuesDe is! _CursorPedidosFirestore) {
        throw ArgumentError.value(despuesDe, 'despuesDe', 'Cursor ajeno.');
      }
      consulta = consulta.startAfterDocument(despuesDe.documento);
    }
    // Un documento de más solo para saber si existe otra página.
    final resultado = await consulta.limit(limite + 1).get();
    final pagina = resultado.docs.take(limite).toList();
    return PaginaPedidos(
      pedidos: pagina.map(_ayudas.pedido).toList(),
      ultimoCursor: pagina.isEmpty
          ? null
          : _CursorPedidosFirestore(pagina.last),
      hayMas: resultado.docs.length > limite,
    );
  }

  @override
  Stream<ResumenVentasDia> escucharResumenDia(String negocioId, String dia) {
    return _ayudas
        .resumen(negocioId, dia)
        .snapshots()
        .map((doc) => ResumenVentasDiaMapper.desdeFirestore(dia, doc.data()));
  }

  @override
  Future<ResultadoConfirmar> confirmar(String negocioId, String pedidoId) {
    final ref = _ayudas.pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return const ResultadoConfirmar(yaNoEsNuevo: true);
      final pedido = _ayudas.pedido(doc);
      if (pedido.estado != EstadoPedido.nuevo) {
        return const ResultadoConfirmar(yaNoEsNuevo: true);
      }

      // Todas las lecturas primero: los productos del carrito y, si hay
      // combos, las partes de cada combo.
      final productos = <String, Producto>{};
      final leidos = <String>{};
      Future<void> leer(Iterable<String> ids) async {
        for (final id in ids) {
          if (!leidos.add(id)) continue;
          final producto = await _ayudas.leerProducto(tx, negocioId, id);
          if (producto != null) productos[id] = producto;
        }
      }

      await leer(CalculoStockPedido.idsDeLineas(pedido.lineas));
      await leer([
        for (final p in productos.values.toList())
          if (p.esCombo) ...CalculoStockPedido.idsDePartes(p),
      ]);

      Producto? buscar(String id) => productos[id];
      final calculo = CalculoStockPedido.calcular(pedido.lineas, buscar);
      if (!calculo.ok) {
        return ResultadoConfirmar(
          faltas: calculo.faltas,
          sinProducto: calculo.sinProducto,
        );
      }
      final verificacion = CalculoPedido.verificar(pedido, buscar);

      // Resumen del día: se lee ANTES de escribir (regla de las transacciones)
      // y se guarda el valor ya sumado.
      final ahora = _reloj();
      final refResumen = _ayudas.resumen(
        negocioId,
        ResumenDiaPedidos.claveDia(ahora),
      );
      final resumenActual = ResumenVentasDiaMapper.desdeFirestore(
        refResumen.id,
        (await tx.get(refResumen)).data(),
      );

      for (final id in {for (final d in calculo.descuentos) d.productoId}) {
        final nuevo = CalculoStockPedido.aplicar(
          productos[id]!,
          calculo.descuentos,
          devolver: false,
        ).producto;
        tx.update(
          _ayudas.producto(negocioId, id),
          _ayudas.camposDeStock(nuevo),
        );
      }
      tx.update(ref, {
        'estado': EstadoPedido.confirmado.valor,
        'stockDescontado': PedidoMapper.descuentosAMapas(calculo.descuentos),
        'historial': _ayudas.historialCon(pedido, EstadoPedido.confirmado),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      // Cuántos minutos tardó en confirmarse (de la llegada a ahora).
      final minutos = ResumenVentasDiaCalculo.minutosParaConfirmar(
        pedido.fecha,
        ahora,
      );
      if (minutos != null) {
        tx.set(refResumen, {
          'confirmados': resumenActual.confirmados + 1,
          'sumaMinutosConfirmar': resumenActual.sumaMinutosConfirmar + minutos,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return ResultadoConfirmar(
        totalActualCentavos: verificacion.difiere
            ? verificacion.totalActualCentavos
            : null,
        lineasCambiadas: verificacion.lineasCambiadas,
      );
    });
  }

  @override
  Future<int> cancelar(
    String negocioId,
    String pedidoId, {
    bool soloSiEstaNuevo = false,
  }) {
    final ref = _ayudas.pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _ayudas.leerPedido(tx, ref);
      if (!TransicionesPedido.puedeCancelar(pedido.estado)) {
        throw StateError('El pedido ya no se puede cancelar.');
      }
      if (soloSiEstaNuevo && pedido.estado != EstadoPedido.nuevo) {
        throw StateError('El pedido ya no está nuevo.');
      }

      // Se devuelve lo guardado en el pedido (no se recalcula). Un pedido
      // nuevo no descontó nada: no lee ningún producto.
      final productos = <String, Producto>{};
      var omitidos = 0;
      final ids = {for (final d in pedido.stockDescontado) d.productoId};
      for (final id in ids) {
        final producto = await _ayudas.leerProducto(tx, negocioId, id);
        if (producto != null) {
          productos[id] = producto;
        } else {
          omitidos += pedido.stockDescontado
              .where((d) => d.productoId == id)
              .length;
        }
      }

      for (final entrada in productos.entries) {
        final aplicado = CalculoStockPedido.aplicar(
          entrada.value,
          pedido.stockDescontado,
          devolver: true,
        );
        omitidos += aplicado.omitidos;
        tx.update(
          _ayudas.producto(negocioId, entrada.key),
          _ayudas.camposDeStock(aplicado.producto),
        );
      }
      tx.update(ref, {
        'estado': EstadoPedido.cancelado.valor,
        'reembolso': TransicionesPedido.reembolsoAlCancelar(pedido).valor,
        'historial': _ayudas.historialCon(pedido, EstadoPedido.cancelado),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return omitidos;
    });
  }

  @override
  Future<void> avanzar(
    String negocioId,
    String pedidoId,
    EstadoPedido nuevo, {
    EstadoPago? pago,
  }) {
    if (nuevo == EstadoPedido.confirmado) {
      throw ArgumentError('Confirmar mueve stock: usa confirmar().');
    }
    final ref = _ayudas.pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _ayudas.leerPedido(tx, ref);
      final siguiente = TransicionesPedido.siguiente(
        pedido.estado,
        pedido.tipoEntrega,
      );
      if (siguiente != nuevo) {
        throw StateError(
          'El pedido no puede pasar de ${pedido.estado.valor} a ${nuevo.valor}.',
        );
      }
      // Al entregar se suma la venta al resumen del día. La lectura va ANTES de
      // todas las escrituras (regla de las transacciones).
      final ahora = _reloj();
      final entregando = nuevo == EstadoPedido.entregado;
      final refResumen = _ayudas.resumen(
        negocioId,
        ResumenDiaPedidos.claveDia(ahora),
      );
      var resumenActual = ResumenVentasDia.vacio(refResumen.id);
      if (entregando) {
        resumenActual = ResumenVentasDiaMapper.desdeFirestore(
          refResumen.id,
          (await tx.get(refResumen)).data(),
        );
      }
      tx.update(ref, {
        'estado': nuevo.valor,
        'estadoPago': ?pago?.valor,
        'historial': _ayudas.historialCon(pedido, nuevo),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      if (entregando) {
        final entregado = ResumenVentasDiaCalculo.entregadoDe(
          pedido.copyWith(estadoPago: pago),
          ahora,
        );
        tx.set(refResumen, {
          'ventasCentavos': resumenActual.ventasCentavos + pedido.totalCentavos,
          'entregados': resumenActual.entregados + 1,
          'ultimosEntregados': ResumenVentasDiaMapper.entregadosAMapas(
            ResumenVentasDiaCalculo.conNuevoEntregado(
              resumenActual.ultimosEntregados,
              entregado,
            ),
          ),
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> marcarPago(String negocioId, String pedidoId, EstadoPago pago) {
    final ref = _ayudas.pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _ayudas.leerPedido(tx, ref);
      if (!TransicionesPedido.puedeCambiarPago(pedido.estado)) {
        throw StateError('Un pedido cancelado no cambia de pago.');
      }
      tx.update(ref, {
        'estadoPago': pago.valor,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> marcarReembolsoHecho(String negocioId, String pedidoId) {
    final ref = _ayudas.pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _ayudas.leerPedido(tx, ref);
      if (!TransicionesPedido.puedeMarcarReembolsoHecho(pedido)) {
        throw StateError('Este pedido no tiene un reembolso pendiente.');
      }
      tx.update(ref, {
        'reembolso': EstadoReembolso.hecho.valor,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
  }
}
