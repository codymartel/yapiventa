import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mobile/features/pedidos/data/pedidos_repository.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import 'pedidos_de_prueba.dart';

const negocioDePrueba = 'n1';

/// Una línea de queso por peso, como la guarda la tienda (mapa de Firestore).
Map<String, dynamic> lineaQuesoMapa([int gramos = 350]) => {
  'productoId': 'queso',
  'nombre': 'Queso andino',
  'cantidad': gramos,
  'precioCentavos': 2400,
  'porMedida': true,
  'cantidadReferencia': 1000,
  'subtotalCentavos': 2400 * gramos ~/ 1000,
};

Map<String, dynamic> lineaGaseosaMapa([int cantidad = 2]) => {
  'productoId': 'gaseosa',
  'nombre': 'Gaseosa Inca',
  'cantidad': cantidad,
  'precioCentavos': 350,
  'subtotalCentavos': 350 * cantidad,
};

/// Un pedido de la tienda como se guarda en Firestore (mapa).
Map<String, dynamic> pedidoMapa({
  List<Map<String, dynamic>>? lineas,
  String estado = 'nuevo',
  String estadoPago = 'pendiente',
  String tipoEntrega = 'delivery',
  DateTime? fecha,
  Object? stockDescontado,
  String reembolso = 'ninguno',
}) {
  return {
    'negocioId': negocioDePrueba,
    'clave': 'ABC123',
    'estado': estado,
    'estadoPago': estadoPago,
    'tipoEntrega': tipoEntrega,
    'fecha': Timestamp.fromDate(fecha ?? DateTime.utc(2026, 11, 5, 16)),
    'cliente': {'nombre': 'Rosa Quispe'},
    'deliveryCentavos': 300,
    'descuentoCentavos': 0,
    'subtotalCentavos': 1540,
    'totalCentavos': 1840,
    'lineas': lineas ?? [lineaQuesoMapa(), lineaGaseosaMapa()],
    'stockDescontado': ?stockDescontado,
    'reembolso': reembolso,
  };
}

/// El simulador de Firestore con un negocio, su repositorio de pedidos y dos
/// productos (queso 1 200 g y gaseosa 10). Lo comparten las pruebas del
/// repositorio de pedidos: `setUp(banco.preparar)`.
class BancoPedidosRepo {
  late FakeFirebaseFirestore db;
  late PedidosRepository repo;

  CollectionReference<Map<String, dynamic>> pedidos() =>
      db.collection('negocios').doc(negocioDePrueba).collection('pedidos');

  Future<void> producto(Producto p) {
    final datos = ProductoFirestoreMapper.paraFirestore(p)
      ..['negocioId'] = negocioDePrueba;
    return db
        .collection('negocios')
        .doc(negocioDePrueba)
        .collection('productos')
        .doc(p.id)
        .set(datos);
  }

  Future<Producto?> leerProducto(String id) async {
    final doc = await db
        .collection('negocios')
        .doc(negocioDePrueba)
        .collection('productos')
        .doc(id)
        .get();
    return ProductoFirestoreMapper.desdeFirestore(doc.id, doc.data());
  }

  Future<Map<String, dynamic>> leerPedido(String id) async {
    return (await pedidos().doc(id).get()).data()!;
  }

  Future<void> preparar() async {
    db = FakeFirebaseFirestore();
    repo = PedidosRepository(
      db: db,
      reloj: () => DateTime.utc(2026, 11, 5, 17),
    );
    await producto(quesoPorMedida(stockBase: 1200));
    await producto(productoSimple(stock: 10));
  }
}
