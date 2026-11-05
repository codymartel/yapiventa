import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../application/services/calculo_stock_pedido.dart';
import '../application/services/transiciones_pedido.dart';
import '../application/services/verificacion_total_pedido.dart';
import '../domain/models/estado_pedido.dart';
import '../domain/models/pedido.dart';
import '../domain/repositories/repositorio_pedidos.dart';
import 'pedido_mapper.dart';

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

  static final List<String> _abiertos = [
    for (final e in EstadoPedido.values)
      if (e.abierto) e.valor,
  ];
  static final List<String> _cerrados = [
    for (final e in EstadoPedido.values)
      if (e.esFinal) e.valor,
  ];

  CollectionReference<Map<String, dynamic>> _pedidos(String negocioId) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para operar los pedidos.');
    }
    return _db.collection('negocios').doc(id).collection('pedidos');
  }

  DocumentReference<Map<String, dynamic>> _producto(
    String negocioId,
    String productoId,
  ) {
    return _db
        .collection('negocios')
        .doc(negocioId.trim())
        .collection('productos')
        .doc(productoId);
  }

  Pedido _pedido(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PedidoMapper.desdeFirestore(doc.id, doc.data() ?? const {});
  }

  @override
  Stream<List<Pedido>> escucharAbiertos(String negocioId, {int limite = 50}) {
    return _pedidos(negocioId)
        .where('estado', whereIn: _abiertos)
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((consulta) => consulta.docs.map(_pedido).toList());
  }

  @override
  Future<PaginaPedidos> obtenerHistorial(
    String negocioId, {
    CursorPedidos? despuesDe,
    int limite = 20,
  }) async {
    Query<Map<String, dynamic>> consulta = _pedidos(
      negocioId,
    ).where('estado', whereIn: _cerrados).orderBy('fecha', descending: true);
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
      pedidos: pagina.map(_pedido).toList(),
      ultimoCursor: pagina.isEmpty
          ? null
          : _CursorPedidosFirestore(pagina.last),
      hayMas: resultado.docs.length > limite,
    );
  }

  @override
  Future<ResultadoConfirmar> confirmar(String negocioId, String pedidoId) {
    final ref = _pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return const ResultadoConfirmar(yaNoEsNuevo: true);
      final pedido = _pedido(doc);
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
          final producto = await _leerProducto(tx, negocioId, id);
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

      for (final id in {for (final d in calculo.descuentos) d.productoId}) {
        final nuevo = CalculoStockPedido.aplicar(
          productos[id]!,
          calculo.descuentos,
          devolver: false,
        ).producto;
        tx.update(_producto(negocioId, id), _camposDeStock(nuevo));
      }
      tx.update(ref, {
        'estado': EstadoPedido.confirmado.valor,
        'stockDescontado': PedidoMapper.descuentosAMapas(calculo.descuentos),
        'historial': _historialCon(pedido, EstadoPedido.confirmado),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      return ResultadoConfirmar(
        totalActualCentavos: verificacion.difiere
            ? verificacion.totalActualCentavos
            : null,
        lineasCambiadas: verificacion.lineasCambiadas,
      );
    });
  }

  @override
  Future<int> cancelar(String negocioId, String pedidoId) {
    final ref = _pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _leerPedido(tx, ref);
      if (!TransicionesPedido.puedeCancelar(pedido.estado)) {
        throw StateError('El pedido ya no se puede cancelar.');
      }

      // Se devuelve lo guardado en el pedido (no se recalcula). Un pedido
      // nuevo no descontó nada: no lee ningún producto.
      final productos = <String, Producto>{};
      var omitidos = 0;
      final ids = {for (final d in pedido.stockDescontado) d.productoId};
      for (final id in ids) {
        final producto = await _leerProducto(tx, negocioId, id);
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
          _producto(negocioId, entrada.key),
          _camposDeStock(aplicado.producto),
        );
      }
      tx.update(ref, {
        'estado': EstadoPedido.cancelado.valor,
        'reembolso': TransicionesPedido.reembolsoAlCancelar(pedido).valor,
        'historial': _historialCon(pedido, EstadoPedido.cancelado),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return omitidos;
    });
  }

  @override
  Future<void> avanzar(String negocioId, String pedidoId, EstadoPedido nuevo) {
    if (nuevo == EstadoPedido.confirmado) {
      throw ArgumentError('Confirmar mueve stock: usa confirmar().');
    }
    final ref = _pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _leerPedido(tx, ref);
      final siguiente = TransicionesPedido.siguiente(
        pedido.estado,
        pedido.tipoEntrega,
      );
      if (siguiente != nuevo) {
        throw StateError(
          'El pedido no puede pasar de ${pedido.estado.valor} a ${nuevo.valor}.',
        );
      }
      tx.update(ref, {
        'estado': nuevo.valor,
        'historial': _historialCon(pedido, nuevo),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> marcarPago(String negocioId, String pedidoId, EstadoPago pago) {
    final ref = _pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _leerPedido(tx, ref);
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
    final ref = _pedidos(negocioId).doc(pedidoId);
    return _db.runTransaction((tx) async {
      final pedido = await _leerPedido(tx, ref);
      if (!TransicionesPedido.puedeMarcarReembolsoHecho(pedido)) {
        throw StateError('Este pedido no tiene un reembolso pendiente.');
      }
      tx.update(ref, {
        'reembolso': EstadoReembolso.hecho.valor,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Ayudas ────────────────────────────────────────────────────────────

  Future<Pedido> _leerPedido(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final doc = await tx.get(ref);
    if (!doc.exists) throw StateError('El pedido ya no existe.');
    return _pedido(doc);
  }

  Future<Producto?> _leerProducto(
    Transaction tx,
    String negocioId,
    String productoId,
  ) async {
    final doc = await tx.get(_producto(negocioId, productoId));
    return ProductoFirestoreMapper.desdeFirestore(doc.id, doc.data());
  }

  /// Solo los campos de stock del producto: el resto del documento no se toca.
  Map<String, dynamic> _camposDeStock(Producto producto) {
    final datos = ProductoFirestoreMapper.paraFirestore(producto);
    return {
      'stock': datos['stock'],
      'stockBase': datos['stockBase'],
      'modelos': datos['modelos'],
    };
  }

  List<Map<String, dynamic>> _historialCon(Pedido pedido, EstadoPedido nuevo) {
    return PedidoMapper.historialAMapas([
      ...pedido.historial,
      CambioEstado(estado: nuevo, fecha: _reloj()),
    ]);
  }
}
