import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../application/services/calculo_stock_pedido.dart';
import '../domain/models/estado_pedido.dart';
import '../domain/models/pedido.dart';
import 'pedido_mapper.dart';

// ═════════════════════════════════════════════════════════════════════════
// AyudasPedidosFirestore
// ═════════════════════════════════════════════════════════════════════════
// Lo que comparten los repositorios que escriben pedidos (pedidos de la
// tienda y ventas de mostrador): las referencias de Firestore del negocio, la
// lectura de un producto dentro de una transacción, los campos de stock que se
// actualizan y el historial de cambios de estado.
//
// Solo ayudas de acceso a datos: no decide nada del negocio.
// ═════════════════════════════════════════════════════════════════════════
class AyudasPedidosFirestore {
  AyudasPedidosFirestore({required this._db, required this._reloj});

  final FirebaseFirestore _db;
  final DateTime Function() _reloj;

  /// La hora del dispositivo (inyectable en las pruebas).
  DateTime ahora() => _reloj();

  CollectionReference<Map<String, dynamic>> pedidos(String negocioId) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para operar los pedidos.');
    }
    return _db.collection('negocios').doc(id).collection('pedidos');
  }

  DocumentReference<Map<String, dynamic>> producto(
    String negocioId,
    String productoId,
  ) {
    return _db
        .collection('negocios')
        .doc(negocioId.trim())
        .collection('productos')
        .doc(productoId);
  }

  /// negocios/{id}/resumenes/{AAAA-MM-DD}: el resumen de ventas de un día.
  DocumentReference<Map<String, dynamic>> resumen(
    String negocioId,
    String dia,
  ) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para operar los pedidos.');
    }
    return _db.collection('negocios').doc(id).collection('resumenes').doc(dia);
  }

  Pedido pedido(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PedidoMapper.desdeFirestore(doc.id, doc.data() ?? const {});
  }

  Future<Pedido> leerPedido(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final doc = await tx.get(ref);
    if (!doc.exists) throw StateError('El pedido ya no existe.');
    return pedido(doc);
  }

  Future<Producto?> leerProducto(
    Transaction tx,
    String negocioId,
    String productoId,
  ) async {
    final doc = await tx.get(producto(negocioId, productoId));
    return ProductoFirestoreMapper.desdeFirestore(doc.id, doc.data());
  }

  /// Solo los campos de stock del producto: el resto del documento no se toca.
  Map<String, dynamic> camposDeStock(Producto producto) {
    final datos = ProductoFirestoreMapper.paraFirestore(producto);
    return {
      'stock': datos['stock'],
      'stockBase': datos['stockBase'],
      'modelos': datos['modelos'],
    };
  }

  /// Devuelve al stock lo que el pedido descontó (lo guardado en
  /// `stockDescontado`, no se recalcula). Lee los productos y luego escribe sus
  /// campos de stock: el llamador debe haber hecho ANTES todas sus demás
  /// lecturas. Devuelve cuántas líneas no se pudieron devolver porque su
  /// producto ya no existe (0 = todo devuelto). Un pedido que no descontó nada
  /// no lee ningún producto.
  Future<int> devolverStock(
    Transaction tx,
    String negocioId,
    Pedido pedido,
  ) async {
    final productos = <String, Producto>{};
    var omitidos = 0;
    final ids = {for (final d in pedido.stockDescontado) d.productoId};
    for (final id in ids) {
      final producto = await leerProducto(tx, negocioId, id);
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
        producto(negocioId, entrada.key),
        camposDeStock(aplicado.producto),
      );
    }
    return omitidos;
  }

  List<Map<String, dynamic>> historialCon(Pedido pedido, EstadoPedido nuevo) {
    return PedidoMapper.historialAMapas([
      ...pedido.historial,
      CambioEstado(estado: nuevo, fecha: _reloj()),
    ]);
  }
}
