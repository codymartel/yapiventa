import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/pedido_mapper.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';

// 19:32 UTC = 14:32 en Lima, día 2026-11-05.
final _ahora = DateTime.utc(2026, 11, 5, 19, 32);

void main() {
  late FakeFirebaseFirestore db;
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

  Future<Map<String, dynamic>?> leerPedido(String id) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('pedidos')
        .doc(id)
        .get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> leerResumen() async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('resumenes')
        .doc('2026-11-05')
        .get();
    return doc.data();
  }

  Future<int> cuantosPedidos() async {
    final q = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('pedidos')
        .get();
    return q.docs.length;
  }

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
    String notas = '',
    bool cobrarAlEntregar = false,
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
      notas: notas,
      cobrarAlEntregar: cobrarAlEntregar,
    );
  }

  // Bodega: 350 g de queso (S/ 24,00 el kg) + 2 gaseosas a S/ 4,50.
  final bodega = [
    lineaQueso(350),
    lineaSimple(cantidad: 2, precioCentavos: 450),
  ];

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = VentasMostradorRepository(db: db, reloj: () => _ahora);
    await guardar(quesoPorMedida(stockBase: 3200));
    await guardar(productoSimple(stock: 24, precioCentavos: 450));
  });

  group('cobrar en el local', () {
    test('crea el pedido entregado y cobrado, de mostrador', () async {
      final r = await repo.registrar(_negocio, solicitud(bodega));

      expect(r.registrada, isTrue);
      expect(r.pedidoId, 'venta0001');
      expect(r.clave, 'TA0001');
      final p = (await leerPedido('venta0001'))!;
      expect(p['estado'], 'entregado');
      expect(p['estadoPago'], 'pagado');
      expect(p['origen'], 'mostrador');
      expect(p['enLocal'], isTrue);
      expect(p['tipoEntrega'], 'recojo');
      expect(p['subtotalCentavos'], 1740);
      expect(p['totalCentavos'], 1740);
      expect(p['metodoPago'], 'efectivo');
      expect(p['reembolso'], 'ninguno');
      expect(p['fecha'], isNotNull);
      expect(p['negocioId'], _negocio);
      expect((p['historial'] as List), hasLength(2));
      expect((p['stockDescontado'] as List), hasLength(2));
    });

    test(
      'la clave son los últimos 6 caracteres del id, en mayúsculas',
      () async {
        final r = await repo.registrar(
          _negocio,
          solicitud(bodega, id: 'abcdefGHIJKL'),
        );

        expect(r.clave, 'GHIJKL'.toUpperCase());
      },
    );

    test('baja el stock: queso 3 200 → 2 850 g y gaseosas 24 → 22', () async {
      await repo.registrar(_negocio, solicitud(bodega));

      expect((await leerProducto('queso'))!.stockBase, 2850);
      expect((await leerProducto('gaseosa'))!.stock, 22);
    });

    test('suma al resumen del día: ventas, entregados y contadores', () async {
      await repo.registrar(_negocio, solicitud(bodega));

      final r = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      expect(r.ventasCentavos, 1740);
      expect(r.entregados, 1);
      expect(r.ultimosEntregados.single.pedidoId, 'venta0001');
      expect(r.contadores.mostrador, 1);
      expect(r.contadores.mostradorCentavos, 1740);
      expect(r.contadores.porPago, {'efectivo': 1740});
      expect(r.contadores.porEntrega, {'local': 1740});
      expect(r.contadores.porHora, {'14': 1740});
      expect(r.contadores.porProducto['queso']!.cantidad, 350);
      expect(r.contadores.porProducto['queso']!.centavos, 840);
      expect(r.contadores.porProducto['gaseosa']!.cantidad, 2);
    });

    test('una segunda venta acumula en el mismo resumen', () async {
      await repo.registrar(_negocio, solicitud(bodega));
      await repo.registrar(
        _negocio,
        solicitud(
          [lineaSimple(cantidad: 1, precioCentavos: 450)],
          id: 'venta0002',
          pago: 'yape',
        ),
      );

      final r = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      expect(r.ventasCentavos, 1740 + 450);
      expect(r.entregados, 2);
      expect(r.contadores.mostrador, 2);
      expect(r.contadores.porPago, {'efectivo': 1740, 'yape': 450});
      expect(r.contadores.porProducto['gaseosa']!.cantidad, 3);
      expect((await leerProducto('gaseosa'))!.stock, 21);
    });

    test('el pedido guardado se lee con el mismo mapper de Pedidos', () async {
      await repo.registrar(
        _negocio,
        solicitud(
          bodega,
          cliente: const ClientePedido(nombre: 'Mesa 4'),
          notas: 'Sin bolsa',
        ),
      );

      final p = PedidoMapper.desdeFirestore(
        'venta0001',
        (await leerPedido('venta0001'))!,
      );

      expect(p.origen, OrigenPedido.mostrador);
      expect(p.estado, EstadoPedido.entregado);
      expect(p.enLocal, isTrue);
      expect(p.cliente.nombre, 'Mesa 4');
      expect(p.notas, 'Sin bolsa');
      expect(p.lineas, hasLength(2));
      expect(p.lineas.first.porMedida, isTrue);
      expect(p.lineas.first.subtotalCentavos, 840);
      expect(p.stockDescontado.first.enBase, isTrue);
    });

    test(
      'el cliente puede quedar vacío (Caja no lo exige en el local)',
      () async {
        await repo.registrar(_negocio, solicitud(bodega));

        final p = (await leerPedido('venta0001'))!;
        expect(p['cliente'], isEmpty);
        expect(p.containsKey('notas'), isFalse);
        expect(p.containsKey('zona'), isFalse);
      },
    );

    test('guarda el descuento por forma de pago: 5 % de 1 740 = 87', () async {
      await repo.registrar(
        _negocio,
        solicitud(
          bodega,
          pago: 'yape',
          descuento: const DescuentoPago.porcentaje(centesimas: 500),
        ),
      );

      final p = (await leerPedido('venta0001'))!;
      expect(p['descuentoCentavos'], 87);
      expect(p['totalCentavos'], 1653);
      final r = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      expect(r.ventasCentavos, 1653);
    });
  });

  group('delivery', () {
    final lineas = [lineaSimple(cantidad: 2, precioCentavos: 450)];
    const cliente = ClientePedido(
      nombre: 'Carla',
      telefono: '987654321',
      direccion: 'Av. Larco 123',
    );

    test(
      'nace confirmado, con el stock ya descontado y sin sumar a ventas',
      () async {
        final r = await repo.registrar(
          _negocio,
          solicitud(
            lineas,
            entrega: TipoEntrega.delivery,
            enLocal: false,
            cliente: cliente,
            zona: 'Miraflores',
            delivery: 500,
          ),
        );

        expect(r.registrada, isTrue);
        final p = (await leerPedido('venta0001'))!;
        expect(p['estado'], 'confirmado');
        expect(p['estadoPago'], 'pagado');
        expect(p['tipoEntrega'], 'delivery');
        expect(p['enLocal'], isFalse);
        expect(p['zona'], 'Miraflores');
        expect(p['deliveryCentavos'], 500);
        expect(p['totalCentavos'], 900 + 500);
        expect((p['historial'] as List), hasLength(1));
        expect((await leerProducto('gaseosa'))!.stock, 22);
        // Todavía no es una venta: el resumen del día no se toca.
        expect(await leerResumen(), isNull);
      },
    );

    test('«Cobrar al entregar» deja el pago pendiente', () async {
      await repo.registrar(
        _negocio,
        solicitud(
          lineas,
          entrega: TipoEntrega.delivery,
          enLocal: false,
          cliente: cliente,
          zona: 'Miraflores',
          cobrarAlEntregar: true,
        ),
      );

      expect((await leerPedido('venta0001'))!['estadoPago'], 'pendiente');
    });

    test(
      'en el local, «cobrar al entregar» no aplica: queda cobrado',
      () async {
        await repo.registrar(
          _negocio,
          solicitud(lineas, cobrarAlEntregar: true),
        );

        expect((await leerPedido('venta0001'))!['estadoPago'], 'pagado');
      },
    );
  });

  group('no se cobra (todo o nada)', () {
    test('si falta stock no se escribe nada y dice qué falta', () async {
      await guardar(productoSimple(stock: 1, precioCentavos: 450));

      final r = await repo.registrar(_negocio, solicitud(bodega));

      expect(r.registrada, isFalse);
      expect(r.faltas.single.nombre, 'Gaseosa Inca');
      expect(r.faltas.single.pide, 2);
      expect(r.faltas.single.hay, 1);
      expect(await cuantosPedidos(), 0);
      expect(await leerResumen(), isNull);
      // El queso sí alcanzaba, pero no se descuenta a medias.
      expect((await leerProducto('queso'))!.stockBase, 3200);
      expect((await leerProducto('gaseosa'))!.stock, 1);
    });

    test('un producto que ya no existe se dice por su nombre', () async {
      final r = await repo.registrar(
        _negocio,
        solicitud([
          lineaSimple(
            productoId: 'borrado',
            nombre: 'Papas',
            precioCentavos: 300,
          ),
          lineaQueso(350),
        ]),
      );

      expect(r.registrada, isFalse);
      expect(r.sinProducto, ['Papas']);
      expect(await cuantosPedidos(), 0);
      expect((await leerProducto('queso'))!.stockBase, 3200);
    });

    test('si el precio cambió no se cobra y avisa el total de hoy', () async {
      // El cajero vio la gaseosa a S/ 4,50; el vendedor la subió a S/ 5,00.
      await guardar(productoSimple(stock: 24, precioCentavos: 500));

      final r = await repo.registrar(_negocio, solicitud(bodega));

      expect(r.registrada, isFalse);
      expect(r.precioCambio, isTrue);
      expect(r.lineasCambiadas, ['Gaseosa Inca']);
      expect(r.totalActualCentavos, 840 + 1000);
      expect(await cuantosPedidos(), 0);
      expect((await leerProducto('gaseosa'))!.stock, 24);
    });
  });

  group('un toque repetido', () {
    test('con el mismo id no cobra dos veces', () async {
      final primera = await repo.registrar(_negocio, solicitud(bodega));
      final segunda = await repo.registrar(_negocio, solicitud(bodega));

      expect(primera.registrada, isTrue);
      expect(segunda.registrada, isFalse);
      expect(segunda.yaRegistrada, isTrue);
      expect(segunda.pedidoId, 'venta0001');
      expect(segunda.clave, primera.clave);
      expect(await cuantosPedidos(), 1);
      expect((await leerProducto('gaseosa'))!.stock, 22);
      final r = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      expect(r.entregados, 1);
      expect(r.ventasCentavos, 1740);
    });
  });

  group('según el tipo de producto', () {
    test(
      'con variables baja solo esa casilla y recalcula los totales',
      () async {
        await guardar(poloConModelos(stockM: 3, stockL: 2));

        await repo.registrar(
          _negocio,
          solicitud([
            lineaSimple(
              productoId: 'polo',
              nombre: 'Polo básico',
              cantidad: 2,
              precioCentavos: 5000,
              modeloId: 'luna',
              filaId: 'm',
            ),
          ]),
        );

        final polo = (await leerProducto('polo'))!;
        expect(polo.modelos.first.filas.first.stock, 1); // M: 3 − 2
        expect(polo.modelos.first.filas.last.stock, 2); // L no se toca
        expect(polo.stock, 3);
      },
    );

    test('un combo descuenta cada una de sus partes', () async {
      await guardar(
        productoSimple(
          id: 'papas',
          nombre: 'Papas',
          stock: 10,
          precioCentavos: 600,
        ),
      );
      await guardar(comboGaseosaYPapas());

      final r = await repo.registrar(
        _negocio,
        solicitud([
          LineaPedido(
            productoId: 'combo',
            nombre: 'Combo personal',
            cantidad: 3,
            precioCentavos: 1500,
            esCombo: true,
          ),
        ]),
      );

      expect(r.registrada, isTrue);
      // 1 gaseosa y 2 papas por combo × 3 combos.
      expect((await leerProducto('gaseosa'))!.stock, 24 - 3);
      expect((await leerProducto('papas'))!.stock, 10 - 6);
      final r2 = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      expect(r2.contadores.porCombo['combo']!.cantidad, 3);
      expect(r2.contadores.porProducto, isEmpty);
    });

    test(
      'un combo al que le falta una parte no se cobra y no toca ninguna',
      () async {
        await guardar(
          productoSimple(
            id: 'papas',
            nombre: 'Papas',
            stock: 3,
            precioCentavos: 600,
          ),
        );
        await guardar(comboGaseosaYPapas());

        final r = await repo.registrar(
          _negocio,
          solicitud([
            LineaPedido(
              productoId: 'combo',
              nombre: 'Combo personal',
              cantidad: 2,
              precioCentavos: 1500,
              esCombo: true,
            ),
          ]),
        );

        expect(r.registrada, isFalse);
        expect(r.faltas.single.nombre, 'Papas');
        expect((await leerProducto('gaseosa'))!.stock, 24);
        expect((await leerProducto('papas'))!.stock, 3);
      },
    );

    test(
      'un producto de stock ilimitado no se toca, pero la venta se registra',
      () async {
        await guardar(
          productoSimple(
            id: 'chaufa',
            nombre: 'Arroz chaufa',
            stock: 0,
            precioCentavos: 1400,
            infinito: true,
          ),
        );

        final r = await repo.registrar(
          _negocio,
          solicitud([
            lineaSimple(
              productoId: 'chaufa',
              nombre: 'Arroz chaufa',
              cantidad: 2,
              precioCentavos: 1400,
            ),
          ]),
        );

        expect(r.registrada, isTrue);
        expect((await leerProducto('chaufa'))!.stock, 0);
        expect((await leerPedido('venta0001'))!['stockDescontado'], isEmpty);
        final res = ResumenVentasDiaMapper.desdeFirestore(
          '2026-11-05',
          await leerResumen(),
        );
        expect(res.ventasCentavos, 2800);
      },
    );

    test('con extras: (350 + 100) × 2 = 900', () async {
      final r = await repo.registrar(
        _negocio,
        solicitud([
          lineaSimple(
            cantidad: 2,
            precioCentavos: 450,
            extras: const [ExtraLinea(nombre: 'Con hielo', precioCentavos: 0)],
          ),
        ]),
      );

      expect(r.registrada, isTrue);
      expect((await leerPedido('venta0001'))!['totalCentavos'], 900);
    });
  });

  group('errores de programación (no del cajero)', () {
    test(
      'una cuenta que no cuadra se rechaza antes de tocar Firebase',
      () async {
        final mala = SolicitudVentaMostrador(
          idVenta: 'venta0001',
          lineas: [lineaQueso(350)],
          tipoEntrega: TipoEntrega.recojo,
          subtotalCentavos: 840,
          totalCentavos: 100,
          metodoPago: 'efectivo',
        );

        expect(() => repo.registrar(_negocio, mala), throwsArgumentError);
        expect(await cuantosPedidos(), 0);
      },
    );

    test('sin id o sin líneas se rechaza', () {
      expect(
        () => repo.registrar(
          _negocio,
          const SolicitudVentaMostrador(
            idVenta: ' ',
            lineas: [],
            tipoEntrega: TipoEntrega.recojo,
            subtotalCentavos: 0,
            totalCentavos: 0,
            metodoPago: 'efectivo',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('sin negocioId no opera', () {
      expect(() => repo.registrar('  ', solicitud(bodega)), throwsStateError);
    });
  });
}
