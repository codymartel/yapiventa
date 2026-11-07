import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/pedidos_repository.dart';
import 'package:mobile/features/pedidos/data/pedido_mapper.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';

// 19:32 UTC = 14:32 en Lima, día 2026-11-05.
final _vendida = DateTime.utc(2026, 11, 5, 19, 32);

void main() {
  late FakeFirebaseFirestore db;
  var ahora = _vendida;
  late VentasMostradorRepository repo;

  Future<void> guardar(Producto p) {
    final datos = ProductoFirestoreMapper.paraFirestore(p)
      ..['negocioId'] = _negocio;
    return db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc(p.id)
        .set(datos);
  }

  Future<Producto?> leerProducto(String id) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc(id)
        .get();
    return ProductoFirestoreMapper.desdeFirestore(doc.id, doc.data());
  }

  Future<Pedido> leerPedido(String id) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('pedidos')
        .doc(id)
        .get();
    return PedidoMapper.desdeFirestore(doc.id, doc.data()!);
  }

  Future<Map<String, dynamic>?> datosResumen(String dia) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('resumenes')
        .doc(dia)
        .get();
    return doc.data();
  }

  Future<dynamic> resumen(String dia) async =>
      ResumenVentasDiaMapper.desdeFirestore(dia, await datosResumen(dia));

  SolicitudVentaMostrador solicitud(
    List<LineaPedido> lineas, {
    String id = 'venta0001',
    TipoEntrega entrega = TipoEntrega.recojo,
    bool enLocal = true,
    String pago = 'efectivo',
    ClientePedido cliente = const ClientePedido(),
    String zona = '',
    int delivery = 0,
    DescuentoPago descuento = DescuentoPago.ninguno,
  }) {
    final v = CalculoVentaMostrador.calcular(
      lineas: lineas,
      deliveryCentavos: delivery,
      descuento: descuento,
    );
    return SolicitudVentaMostrador(
      idVenta: id,
      lineas: v.lineas,
      tipoEntrega: entrega,
      enLocal: enLocal,
      cliente: cliente,
      zona: zona,
      deliveryCentavos: v.deliveryCentavos,
      descuentoCentavos: v.descuentoCentavos,
      subtotalCentavos: v.subtotalCentavos,
      totalCentavos: v.totalCentavos,
      metodoPago: pago,
    );
  }

  // 350 g de queso (840) + 2 gaseosas a S/ 4,50 (900) = 1 740.
  final bodega = [
    lineaQueso(350),
    lineaSimple(cantidad: 2, precioCentavos: 450),
  ];

  setUp(() async {
    db = FakeFirebaseFirestore();
    ahora = _vendida;
    repo = VentasMostradorRepository(db: db, reloj: () => ahora);
    await guardar(quesoPorMedida(stockBase: 3200));
    await guardar(productoSimple(stock: 24, precioCentavos: 450));
  });

  group('anular una venta en el local', () {
    test('devuelve el stock exacto y deja el pedido cancelado', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      expect((await leerProducto('queso'))!.stockBase, 2850);

      final r = await repo.anular(_negocio, 'venta0001');

      expect(r.yaAnulada, isFalse);
      expect(r.sinDevolver, 0);
      expect((await leerProducto('queso'))!.stockBase, 3200);
      expect((await leerProducto('gaseosa'))!.stock, 24);
      final p = await leerPedido('venta0001');
      expect(p.anulada, isTrue);
      expect(p.totalCentavos, 1740, reason: 'el pedido no se borra ni cambia');
      expect(p.reembolso.valor, 'ninguno');
      expect(p.historial.map((c) => c.estado.valor), [
        'confirmado',
        'entregado',
        'cancelado',
      ]);
    });

    test('resta del resumen: ventas, entregados y contadores', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      await repo.anular(_negocio, 'venta0001');

      final r = await resumen('2026-11-05');
      expect(r.ventasCentavos, 0);
      expect(r.entregados, 0);
      expect(r.ultimosEntregados, isEmpty);
      expect(r.contadores.mostrador, 0);
      expect(r.contadores.mostradorCentavos, 0);
      expect(r.contadores.anuladas, 1);
      expect(r.contadores.anuladasCentavos, 1740);
      expect(r.contadores.porPago, isEmpty);
      expect(r.contadores.porEntrega, isEmpty);
      expect(r.contadores.porHora, isEmpty);
      expect(r.contadores.porProducto, isEmpty);
    });

    test('con otra venta del día, solo quita la anulada', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      await repo.registrar(
        _negocio,
        solicitud(
          [lineaSimple(cantidad: 1, precioCentavos: 450)],
          id: 'venta0002',
          pago: 'yape',
        ),
      );

      await repo.anular(_negocio, 'venta0001');

      final r = await resumen('2026-11-05');
      expect(r.ventasCentavos, 450);
      expect(r.entregados, 1);
      expect(r.ultimosEntregados.single.pedidoId, 'venta0002');
      expect(r.contadores.porPago, {'yape': 450});
      expect(r.contadores.porProducto.keys, ['gaseosa']);
      expect(r.contadores.porProducto['gaseosa']!.cantidad, 1);
      expect(r.contadores.mostrador, 1);
      expect((await leerProducto('gaseosa'))!.stock, 23);
    });

    test('con descuento resta el total cobrado, no el subtotal', () async {
      await repo.registrar(
        _negocio,
        solicitud(
          bodega,
          pago: 'yape',
          descuento: const DescuentoPago.porcentaje(centesimas: 500),
        ),
      );
      expect((await resumen('2026-11-05')).ventasCentavos, 1653);

      await repo.anular(_negocio, 'venta0001');

      final r = await resumen('2026-11-05');
      expect(r.ventasCentavos, 0);
      expect(r.contadores.anuladasCentavos, 1653);
    });
  });

  group('casos límite', () {
    test('un segundo toque no resta dos veces', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      await repo.registrar(
        _negocio,
        solicitud([lineaSimple(cantidad: 1, precioCentavos: 450)], id: 'v2'),
      );

      await repo.anular(_negocio, 'venta0001');
      final segundo = await repo.anular(_negocio, 'venta0001');

      expect(segundo.yaAnulada, isTrue);
      final r = await resumen('2026-11-05');
      expect(r.ventasCentavos, 450);
      expect(r.contadores.anuladas, 1);
      expect((await leerProducto('gaseosa'))!.stock, 23);
    });

    test('anular al día siguiente resta del día de la venta', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      ahora = DateTime.utc(2026, 11, 7, 15);

      await repo.anular(_negocio, 'venta0001');

      final r = await resumen('2026-11-05');
      expect(r.ventasCentavos, 0);
      expect(r.contadores.anuladas, 1);
      expect(
        await datosResumen('2026-11-07'),
        isNull,
        reason: 'no se crea el resumen del día de hoy',
      );
    });

    test('un producto borrado se avisa y el resto del stock vuelve', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      await db
          .collection('negocios')
          .doc(_negocio)
          .collection('productos')
          .doc('queso')
          .delete();

      final r = await repo.anular(_negocio, 'venta0001');

      expect(r.sinDevolver, 1);
      expect((await leerProducto('gaseosa'))!.stock, 24);
      expect((await leerPedido('venta0001')).anulada, isTrue);
    });

    test('el stock que cambió después se suma, no se pisa', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      // El vendedor repuso 10 gaseosas después de la venta (22 → 32).
      await guardar(productoSimple(stock: 32, precioCentavos: 450));

      await repo.anular(_negocio, 'venta0001');

      expect((await leerProducto('gaseosa'))!.stock, 34);
    });

    test('un delivery confirmado no se anula: se cancela en Pedidos', () async {
      await repo.registrar(
        _negocio,
        solicitud(
          bodega,
          entrega: TipoEntrega.delivery,
          enLocal: false,
          cliente: const ClientePedido(
            nombre: 'Ana',
            telefono: '987654321',
            direccion: 'Av. Lima 1',
          ),
          zona: 'Centro',
          delivery: 300,
        ),
      );

      expect(
        () => repo.anular(_negocio, 'venta0001'),
        throwsA(isA<StateError>()),
      );
      expect((await leerProducto('gaseosa'))!.stock, 22, reason: 'sin cambios');
    });

    test(
      'un delivery de Caja entregado SÍ se anula y resta todo (3b)',
      () async {
        await repo.registrar(
          _negocio,
          solicitud(
            bodega,
            pago: 'yape',
            entrega: TipoEntrega.delivery,
            enLocal: false,
            cliente: const ClientePedido(
              nombre: 'Ana',
              telefono: '987654321',
              direccion: 'Av. Lima 1',
            ),
            zona: 'Centro',
            delivery: 300,
          ),
        );
        // Se entrega desde Pedidos (en camino → entregado): ahí suma al día.
        final pedidos = PedidosRepository(db: db, reloj: () => ahora);
        await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.enCamino);
        await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.entregado);
        var r = await resumen('2026-11-05');
        expect(r.ventasCentavos, 2040);
        expect(r.contadores.mostrador, 1);
        expect(r.contadores.porEntrega, {'delivery': 2040});

        await repo.anular(_negocio, 'venta0001');

        r = await resumen('2026-11-05');
        expect(r.ventasCentavos, 0);
        expect(r.entregados, 0);
        expect(r.contadores.mostrador, 0);
        expect(r.contadores.porEntrega, isEmpty);
        expect(r.contadores.porPago, isEmpty);
        expect(r.contadores.porProducto, isEmpty);
        expect(r.contadores.anuladas, 1);
        expect((await leerProducto('gaseosa'))!.stock, 24);
        expect((await leerPedido('venta0001')).anulada, isTrue);
      },
    );

    test('un pedido de la tienda entregado no se anula', () async {
      await db
          .collection('negocios')
          .doc(_negocio)
          .collection('pedidos')
          .doc('web1')
          .set({
            'negocioId': _negocio,
            'estado': 'entregado',
            'origen': 'tienda',
            'totalCentavos': 900,
            'historial': <Map<String, dynamic>>[],
            'fecha': Timestamp.fromDate(_vendida),
          });

      expect(() => repo.anular(_negocio, 'web1'), throwsA(isA<StateError>()));
    });

    test('una venta que no existe o sin id se rechaza', () async {
      expect(
        () => repo.anular(_negocio, 'no-existe'),
        throwsA(isA<StateError>()),
      );
      expect(() => repo.anular(_negocio, ' '), throwsArgumentError);
      expect(() => repo.anular(' ', 'venta0001'), throwsA(isA<StateError>()));
    });
  });
}
