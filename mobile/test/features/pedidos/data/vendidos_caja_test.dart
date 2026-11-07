import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/pedidos_repository.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';
final _ahora = DateTime.utc(2026, 11, 5, 19, 32);

/// El contador `vendidos` cuenta VENTAS (no unidades) y solo de los productos
/// de las líneas: cobrar suma 1, anular o cancelar resta 1.
void main() {
  late FakeFirebaseFirestore db;
  late VentasMostradorRepository repo;

  Future<void> guardar(Producto p, {int? vendidos}) {
    final datos = ProductoFirestoreMapper.paraFirestore(p)
      ..['negocioId'] = _negocio;
    if (vendidos != null) datos['vendidos'] = vendidos;
    return db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc(p.id)
        .set(datos);
  }

  Future<int?> vendidos(String id) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc(id)
        .get();
    return doc.data()?['vendidos'] as int?;
  }

  SolicitudVentaMostrador solicitud(
    List<LineaPedido> lineas, {
    String id = 'venta0001',
    TipoEntrega entrega = TipoEntrega.recojo,
  }) {
    final v = CalculoVentaMostrador.calcular(lineas: lineas);
    final esDelivery = entrega == TipoEntrega.delivery;
    return SolicitudVentaMostrador(
      idVenta: id,
      lineas: v.lineas,
      tipoEntrega: entrega,
      enLocal: !esDelivery,
      cliente: esDelivery
          ? const ClientePedido(
              nombre: 'Ana',
              telefono: '987654321',
              direccion: 'Av. Lima 1',
            )
          : const ClientePedido(),
      zona: esDelivery ? 'Centro' : '',
      subtotalCentavos: v.subtotalCentavos,
      totalCentavos: v.totalCentavos,
      metodoPago: 'efectivo',
    );
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = VentasMostradorRepository(db: db, reloj: () => _ahora);
    await guardar(quesoPorMedida(stockBase: 3200), vendidos: 0);
    await guardar(productoSimple(stock: 24, precioCentavos: 450), vendidos: 0);
  });

  test(
    'cobrar suma 1 por producto: 350 g de queso y 2 gaseosas = 1 y 1',
    () async {
      await repo.registrar(
        _negocio,
        solicitud([
          lineaQueso(350),
          lineaSimple(cantidad: 2, precioCentavos: 450),
        ]),
      );

      expect(await vendidos('queso'), 1, reason: 'una venta, no 350 gramos');
      expect(await vendidos('gaseosa'), 1, reason: 'una venta, no 2 botellas');
    },
  );

  test('el mismo producto en dos líneas cuenta una sola vez', () async {
    await repo.registrar(
      _negocio,
      solicitud([
        lineaSimple(cantidad: 1, precioCentavos: 450),
        lineaSimple(cantidad: 3, precioCentavos: 450),
      ]),
    );

    expect(await vendidos('gaseosa'), 1);
  });

  test('un producto viejo sin vendidos empieza en 1', () async {
    await guardar(productoSimple(id: 'viejo', nombre: 'Viejo', stock: 5));

    await repo.registrar(
      _negocio,
      solicitud([lineaSimple(productoId: 'viejo', precioCentavos: 350)]),
    );

    expect(await vendidos('viejo'), 1);
  });

  test('una venta bloqueada (falta stock) no suma nada', () async {
    final r = await repo.registrar(
      _negocio,
      solicitud([lineaSimple(cantidad: 99, precioCentavos: 450)]),
    );

    expect(r.registrada, isFalse);
    expect(await vendidos('gaseosa'), 0);
  });

  test('un toque repetido no suma dos veces', () async {
    final s = solicitud([lineaSimple(precioCentavos: 450)]);
    await repo.registrar(_negocio, s);
    await repo.registrar(_negocio, s);

    expect(await vendidos('gaseosa'), 1);
  });

  group('combos', () {
    setUp(() async {
      await guardar(
        productoSimple(id: 'papas', nombre: 'Papas', stock: 10),
        vendidos: 0,
      );
      await guardar(comboGaseosaYPapas(), vendidos: 0);
    });

    LineaPedido combo() => const LineaPedido(
      productoId: 'combo',
      nombre: 'Combo personal',
      cantidad: 2,
      precioCentavos: 1500,
      esCombo: true,
    );

    test('suma el combo y NO sus partes', () async {
      await repo.registrar(_negocio, solicitud([combo()]));

      expect(await vendidos('combo'), 1);
      expect(await vendidos('gaseosa'), 0);
      expect(await vendidos('papas'), 0);
    });

    test('anular resta el combo', () async {
      await repo.registrar(_negocio, solicitud([combo()]));

      await repo.anular(_negocio, 'venta0001');

      expect(await vendidos('combo'), 0);
    });

    test('anular con el combo borrado no falla', () async {
      await repo.registrar(_negocio, solicitud([combo()]));
      await db
          .collection('negocios')
          .doc(_negocio)
          .collection('productos')
          .doc('combo')
          .delete();

      final r = await repo.anular(_negocio, 'venta0001');

      expect(r.yaAnulada, isFalse);
      expect(
        (await db
                .collection('negocios')
                .doc(_negocio)
                .collection('productos')
                .doc('combo')
                .get())
            .exists,
        isFalse,
        reason: 'no se crea un documento fantasma',
      );
    });
  });

  test('anular resta 1 a cada producto de la venta', () async {
    await repo.registrar(
      _negocio,
      solicitud([
        lineaQueso(350),
        lineaSimple(cantidad: 2, precioCentavos: 450),
      ]),
    );
    await repo.registrar(
      _negocio,
      solicitud([lineaSimple(precioCentavos: 450)], id: 'venta0002'),
    );

    await repo.anular(_negocio, 'venta0001');

    expect(await vendidos('queso'), 0);
    expect(await vendidos('gaseosa'), 1, reason: 'la otra venta sigue');
  });

  test('anular con un producto borrado no falla y el resto baja', () async {
    await repo.registrar(
      _negocio,
      solicitud([lineaQueso(350), lineaSimple(precioCentavos: 450)]),
    );
    await db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc('queso')
        .delete();

    final r = await repo.anular(_negocio, 'venta0001');

    expect(r.sinDevolver, 1);
    expect(await vendidos('gaseosa'), 0);
  });

  test('un segundo toque en anular no resta dos veces', () async {
    await repo.registrar(
      _negocio,
      solicitud([lineaSimple(precioCentavos: 450)]),
    );
    await repo.registrar(
      _negocio,
      solicitud([lineaSimple(precioCentavos: 450)], id: 'venta0002'),
    );

    await repo.anular(_negocio, 'venta0001');
    await repo.anular(_negocio, 'venta0001');

    expect(await vendidos('gaseosa'), 1);
  });

  group('delivery de Caja cancelado desde Pedidos', () {
    test('cancelar resta 1 (la venta ya había sumado)', () async {
      await repo.registrar(
        _negocio,
        solicitud([
          lineaSimple(precioCentavos: 450),
        ], entrega: TipoEntrega.delivery),
      );
      expect(await vendidos('gaseosa'), 1);

      await PedidosRepository(
        db: db,
        reloj: () => _ahora,
      ).cancelar(_negocio, 'venta0001');

      expect(await vendidos('gaseosa'), 0);
      final p = await db
          .collection('negocios')
          .doc(_negocio)
          .collection('pedidos')
          .doc('venta0001')
          .get();
      expect(p.data()!['estado'], EstadoPedido.cancelado.valor);
    });

    test('cancelar un pedido de la tienda NO toca vendidos', () async {
      await db
          .collection('negocios')
          .doc(_negocio)
          .collection('pedidos')
          .doc('web1')
          .set({
            'negocioId': _negocio,
            'estado': 'nuevo',
            'tipoEntrega': 'delivery',
            'estadoPago': 'pendiente',
            'totalCentavos': 450,
            'lineas': [
              {
                'productoId': 'gaseosa',
                'nombre': 'Gaseosa Inca',
                'cantidad': 1,
                'precioCentavos': 450,
              },
            ],
          });

      await PedidosRepository(
        db: db,
        reloj: () => _ahora,
      ).cancelar(_negocio, 'web1');

      expect(await vendidos('gaseosa'), 0, reason: 'nunca sumó');
    });
  });
}
