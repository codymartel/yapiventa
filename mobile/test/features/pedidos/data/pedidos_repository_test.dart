import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/data/pedidos_repository.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';

Map<String, dynamic> _lineaQueso([int gramos = 350]) => {
  'productoId': 'queso',
  'nombre': 'Queso andino',
  'cantidad': gramos,
  'precioCentavos': 2400,
  'porMedida': true,
  'cantidadReferencia': 1000,
  'subtotalCentavos': 2400 * gramos ~/ 1000,
};

Map<String, dynamic> _lineaGaseosa([int cantidad = 2]) => {
  'productoId': 'gaseosa',
  'nombre': 'Gaseosa Inca',
  'cantidad': cantidad,
  'precioCentavos': 350,
  'subtotalCentavos': 350 * cantidad,
};

Map<String, dynamic> _pedido({
  List<Map<String, dynamic>>? lineas,
  String estado = 'nuevo',
  String estadoPago = 'pendiente',
  String tipoEntrega = 'delivery',
  DateTime? fecha,
  Object? stockDescontado,
  String reembolso = 'ninguno',
}) {
  return {
    'negocioId': _negocio,
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
    'lineas': lineas ?? [_lineaQueso(), _lineaGaseosa()],
    'stockDescontado': ?stockDescontado,
    'reembolso': reembolso,
  };
}

void main() {
  late FakeFirebaseFirestore db;
  late PedidosRepository repo;

  CollectionReference<Map<String, dynamic>> pedidos() =>
      db.collection('negocios').doc(_negocio).collection('pedidos');

  Future<void> producto(Producto p) {
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

  Future<Map<String, dynamic>> leerPedido(String id) async {
    return (await pedidos().doc(id).get()).data()!;
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PedidosRepository(
      db: db,
      reloj: () => DateTime.utc(2026, 11, 5, 17),
    );
    await producto(quesoPorMedida(stockBase: 1200));
    await producto(productoSimple(stock: 10));
  });

  group('escucharAbiertos e historial', () {
    test('trae solo los abiertos, del más nuevo al más viejo', () async {
      await pedidos()
          .doc('a')
          .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 15)));
      await pedidos()
          .doc('b')
          .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 16)));
      await pedidos().doc('c').set(_pedido(estado: 'entregado'));
      await pedidos()
          .doc('d')
          .set(
            _pedido(estado: 'en_camino', fecha: DateTime.utc(2026, 11, 5, 14)),
          );

      final lista = await repo.escucharAbiertos(_negocio).first;

      expect(lista.map((p) => p.id), ['b', 'a', 'd']);
    });

    test('respeta el límite', () async {
      for (var i = 0; i < 5; i++) {
        await pedidos()
            .doc('p$i')
            .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 10 + i)));
      }

      final lista = await repo.escucharAbiertos(_negocio, limite: 3).first;

      expect(lista, hasLength(3));
    });

    test('por defecto trae solo 10 abiertos', () async {
      for (var i = 0; i < 12; i++) {
        await pedidos()
            .doc('p$i')
            .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 1, i)));
      }

      final lista = await repo.escucharAbiertos(_negocio).first;

      expect(lista, hasLength(10));
      expect(lista.first.id, 'p11');
    });

    test(
      'con estado trae solo ese estado, del más nuevo al más viejo',
      () async {
        await pedidos()
            .doc('a')
            .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 15)));
        await pedidos()
            .doc('b')
            .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 16)));
        await pedidos().doc('c').set(_pedido(estado: 'confirmado'));

        final nuevos = await repo
            .escucharAbiertos(_negocio, estado: EstadoPedido.nuevo)
            .first;

        expect(nuevos.map((p) => p.id), ['b', 'a']);
      },
    );

    test('un estado cerrado no es una pestaña de abiertos', () {
      expect(
        () => repo.escucharAbiertos(_negocio, estado: EstadoPedido.entregado),
        throwsArgumentError,
      );
    });

    // fake_cloud_firestore 3.1.0 ignora el orden descendente en startAfter
    // (devuelve vacío). Contra el emulador real de Firestore (2026-11-05) la
    // misma consulta devuelve los más viejos, como se espera.
    const fakeSinCursorDescendente =
        'fake_cloud_firestore no soporta startAfter con orden descendente';

    test(
      '«Ver más» trae los 10 siguientes de ese estado',
      skip: fakeSinCursorDescendente,
      () async {
        for (var i = 0; i < 13; i++) {
          await pedidos()
              .doc('n$i')
              .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 1, i)));
        }
        await pedidos()
            .doc('otro')
            .set(
              _pedido(estado: 'confirmado', fecha: DateTime.utc(2026, 11, 1)),
            );

        final vistos = await repo
            .escucharAbiertos(_negocio, estado: EstadoPedido.nuevo)
            .first;
        final segunda = await repo.obtenerAbiertosDespuesDe(
          _negocio,
          vistos.last,
          estado: EstadoPedido.nuevo,
        );

        expect(vistos.map((p) => p.id), [for (var i = 12; i >= 3; i--) 'n$i']);
        expect(segunda.pedidos.map((p) => p.id), ['n2', 'n1', 'n0']);
        expect(segunda.hayMas, isFalse);
      },
    );

    test(
      '«Ver más» dice si todavía hay otra página',
      skip: fakeSinCursorDescendente,
      () async {
        for (var i = 0; i < 5; i++) {
          await pedidos()
              .doc('n$i')
              .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 1, i)));
        }
        final cabeza =
            (await repo.escucharAbiertos(_negocio, limite: 1).first).single;

        final pagina = await repo.obtenerAbiertosDespuesDe(
          _negocio,
          cabeza,
          limite: 2,
        );

        expect(pagina.pedidos.map((p) => p.id), ['n3', 'n2']);
        expect(pagina.hayMas, isTrue);
      },
    );

    test('«Ver más» pide un pedido con fecha', () {
      expect(
        () => repo.obtenerAbiertosDespuesDe(_negocio, pedidoDe(const [])),
        throwsArgumentError,
      );
    });

    test('vencidos: solo los nuevos anteriores al corte', () async {
      await pedidos()
          .doc('viejo')
          .set(_pedido(fecha: DateTime.utc(2026, 11, 4, 20)));
      await pedidos()
          .doc('mas-viejo')
          .set(_pedido(fecha: DateTime.utc(2026, 11, 4, 10)));
      await pedidos()
          .doc('reciente')
          .set(_pedido(fecha: DateTime.utc(2026, 11, 5, 10)));
      await pedidos()
          .doc('confirmado')
          .set(_pedido(estado: 'confirmado', fecha: DateTime.utc(2026, 11, 4)));

      final lista = await repo.obtenerVencidos(
        _negocio,
        antesDe: DateTime.utc(2026, 11, 5, 5),
      );

      expect(lista.map((p) => p.id), ['viejo', 'mas-viejo']);
    });

    test('vencidos respeta el límite', () async {
      for (var i = 0; i < 4; i++) {
        await pedidos()
            .doc('v$i')
            .set(_pedido(fecha: DateTime.utc(2026, 11, 1, i)));
      }

      final lista = await repo.obtenerVencidos(
        _negocio,
        antesDe: DateTime.utc(2026, 11, 5),
        limite: 3,
      );

      expect(lista, hasLength(3));
    });

    test('el historial pagina de a poco y dice si hay más', () async {
      for (var i = 0; i < 5; i++) {
        await pedidos()
            .doc('h$i')
            .set(
              _pedido(
                estado: i.isEven ? 'entregado' : 'cancelado',
                fecha: DateTime.utc(2026, 11, 1 + i),
              ),
            );
      }
      await pedidos().doc('abierto').set(_pedido());

      final primera = await repo.obtenerHistorial(_negocio, limite: 2);
      final segunda = await repo.obtenerHistorial(
        _negocio,
        limite: 2,
        despuesDe: primera.ultimoCursor,
      );
      final tercera = await repo.obtenerHistorial(
        _negocio,
        limite: 2,
        despuesDe: segunda.ultimoCursor,
      );

      expect(primera.pedidos.map((p) => p.id), ['h4', 'h3']);
      expect(primera.hayMas, isTrue);
      expect(segunda.pedidos.map((p) => p.id), ['h2', 'h1']);
      expect(tercera.pedidos.map((p) => p.id), ['h0']);
      expect(tercera.hayMas, isFalse);
    });
  });

  group('confirmar', () {
    test(
      'descuenta el stock, guarda lo descontado y pasa a confirmado',
      () async {
        await pedidos().doc('p1').set(_pedido());

        final r = await repo.confirmar(_negocio, 'p1');

        expect(r.ok, isTrue);
        expect((await leerProducto('queso'))!.stockBase, 850);
        expect((await leerProducto('gaseosa'))!.stock, 8);
        final doc = await leerPedido('p1');
        expect(doc['estado'], 'confirmado');
        expect(doc['stockDescontado'], hasLength(2));
        expect(doc['historial'], hasLength(1));
      },
    );

    test('si no alcanza un producto no se descuenta NADA', () async {
      await producto(productoSimple(stock: 1));
      await pedidos().doc('p1').set(_pedido());

      final r = await repo.confirmar(_negocio, 'p1');

      expect(r.ok, isFalse);
      expect(r.faltas.single.nombre, 'Gaseosa Inca');
      expect(r.faltas.single.hay, 1);
      expect((await leerProducto('queso'))!.stockBase, 1200);
      expect((await leerProducto('gaseosa'))!.stock, 1);
      expect((await leerPedido('p1'))['estado'], 'nuevo');
    });

    test('confirmar dos veces descuenta una sola vez', () async {
      await pedidos().doc('p1').set(_pedido());

      await repo.confirmar(_negocio, 'p1');
      final segunda = await repo.confirmar(_negocio, 'p1');

      expect(segunda.yaNoEsNuevo, isTrue);
      expect((await leerProducto('gaseosa'))!.stock, 8);
    });

    test('un pedido que no existe se avisa, no se rompe', () async {
      final r = await repo.confirmar(_negocio, 'fantasma');

      expect(r.yaNoEsNuevo, isTrue);
    });

    test('un producto borrado se avisa y no se descuenta nada', () async {
      await db
          .collection('negocios')
          .doc(_negocio)
          .collection('productos')
          .doc('gaseosa')
          .delete();
      await pedidos().doc('p1').set(_pedido());

      final r = await repo.confirmar(_negocio, 'p1');

      expect(r.sinProducto, ['Gaseosa Inca']);
      expect((await leerProducto('queso'))!.stockBase, 1200);
    });

    test('un combo descuenta cada parte × cantidad', () async {
      await producto(comboGaseosaYPapas());
      await producto(productoSimple(id: 'papas', nombre: 'Papas', stock: 10));
      await pedidos()
          .doc('p1')
          .set(
            _pedido(
              lineas: [
                {
                  'productoId': 'combo',
                  'nombre': 'Combo personal',
                  'cantidad': 2,
                  'precioCentavos': 1500,
                  'subtotalCentavos': 3000,
                },
              ],
            ),
          );

      final r = await repo.confirmar(_negocio, 'p1');

      expect(r.ok, isTrue);
      expect((await leerProducto('gaseosa'))!.stock, 8);
      expect((await leerProducto('papas'))!.stock, 6);
    });

    test('con modelos baja la fila y el total del producto', () async {
      await producto(poloConModelos(stockM: 3, stockL: 2));
      await pedidos()
          .doc('p1')
          .set(
            _pedido(
              lineas: [
                {
                  'productoId': 'polo',
                  'modeloId': 'luna',
                  'filaId': 'm',
                  'nombre': 'Polo básico',
                  'cantidad': 2,
                  'precioCentavos': 5000,
                  'subtotalCentavos': 10000,
                },
              ],
            ),
          );

      await repo.confirmar(_negocio, 'p1');

      final polo = (await leerProducto('polo'))!;
      expect(polo.modelos.single.filas.firstWhere((f) => f.id == 'm').stock, 1);
      expect(polo.stock, 3);
    });

    test(
      'avisa si con los precios de hoy el total sería otro, pero confirma',
      () async {
        await producto(productoSimple(stock: 10, precioCentavos: 400));
        await pedidos().doc('p1').set(_pedido());

        final r = await repo.confirmar(_negocio, 'p1');

        expect(r.ok, isTrue);
        expect(r.totalActualCentavos, 1940);
        expect(r.lineasCambiadas, ['Gaseosa Inca']);
        expect((await leerPedido('p1'))['totalCentavos'], 1840);
      },
    );
  });

  group('cancelar', () {
    test('devuelve lo descontado y suma sobre lo repuesto', () async {
      await pedidos().doc('p1').set(_pedido());
      await repo.confirmar(_negocio, 'p1');
      // El vendedor repone gaseosas mientras tanto: 8 → 12.
      await producto(productoSimple(stock: 12));

      final omitidos = await repo.cancelar(_negocio, 'p1');

      expect(omitidos, 0);
      expect((await leerProducto('gaseosa'))!.stock, 14);
      expect((await leerProducto('queso'))!.stockBase, 1200);
      final doc = await leerPedido('p1');
      expect(doc['estado'], 'cancelado');
      expect(doc['reembolso'], 'ninguno');
      expect(doc['historial'], hasLength(2));
    });

    test('un pedido pagado queda con el reembolso pendiente', () async {
      await pedidos().doc('p1').set(_pedido(estadoPago: 'pagado'));
      await repo.confirmar(_negocio, 'p1');

      await repo.cancelar(_negocio, 'p1');

      expect((await leerPedido('p1'))['reembolso'], 'pendiente');
    });

    test('un pedido nuevo no toca el stock', () async {
      await pedidos().doc('p1').set(_pedido());

      await repo.cancelar(_negocio, 'p1');

      expect((await leerPedido('p1'))['estado'], 'cancelado');
      expect((await leerProducto('gaseosa'))!.stock, 10);
      expect((await leerProducto('queso'))!.stockBase, 1200);
    });

    test('si el producto se borró cuenta lo omitido y sigue', () async {
      await pedidos().doc('p1').set(_pedido());
      await repo.confirmar(_negocio, 'p1');
      await db
          .collection('negocios')
          .doc(_negocio)
          .collection('productos')
          .doc('queso')
          .delete();

      final omitidos = await repo.cancelar(_negocio, 'p1');

      expect(omitidos, 1);
      expect((await leerProducto('gaseosa'))!.stock, 10);
      expect((await leerPedido('p1'))['estado'], 'cancelado');
    });

    test(
      'soloSiEstaNuevo no cancela uno ya confirmado ni toca su stock',
      () async {
        await pedidos().doc('p1').set(_pedido());
        await pedidos().doc('p2').set(_pedido());
        await repo.confirmar(_negocio, 'p1');

        await repo.cancelar(_negocio, 'p2', soloSiEstaNuevo: true);

        expect((await leerPedido('p2'))['estado'], 'cancelado');
        expect(
          () => repo.cancelar(_negocio, 'p1', soloSiEstaNuevo: true),
          throwsStateError,
        );
        expect((await leerPedido('p1'))['estado'], 'confirmado');
        expect((await leerProducto('gaseosa'))!.stock, 8);
      },
    );

    test(
      'ya no se cancela un entregado, un cancelado ni uno que no existe',
      () async {
        await pedidos().doc('e').set(_pedido(estado: 'entregado'));
        await pedidos().doc('c').set(_pedido(estado: 'cancelado'));

        expect(() => repo.cancelar(_negocio, 'e'), throwsStateError);
        expect(() => repo.cancelar(_negocio, 'c'), throwsStateError);
        expect(() => repo.cancelar(_negocio, 'nada'), throwsStateError);
      },
    );
  });

  group('avanzar, pago y reembolso', () {
    test(
      'delivery: confirmado → en camino → entregado, con historial',
      () async {
        await pedidos().doc('p1').set(_pedido(estado: 'confirmado'));

        await repo.avanzar(_negocio, 'p1', EstadoPedido.enCamino);
        await repo.avanzar(_negocio, 'p1', EstadoPedido.entregado);

        final doc = await leerPedido('p1');
        expect(doc['estado'], 'entregado');
        expect(doc['historial'], hasLength(2));
      },
    );

    test('entregar y cobrar cambia estado y pago a la vez', () async {
      await pedidos().doc('p1').set(_pedido(estado: 'en_camino'));

      await repo.avanzar(
        _negocio,
        'p1',
        EstadoPedido.entregado,
        pago: EstadoPago.pagado,
      );

      final doc = await leerPedido('p1');
      expect(doc['estado'], 'entregado');
      expect(doc['estadoPago'], 'pagado');
    });

    test('entregar sin pago no cambia el pago', () async {
      await pedidos().doc('p1').set(_pedido(estado: 'en_camino'));

      await repo.avanzar(_negocio, 'p1', EstadoPedido.entregado);

      expect((await leerPedido('p1'))['estadoPago'], 'pendiente');
    });

    test('no se saltan pasos ni se confirma por aquí', () async {
      await pedidos().doc('p1').set(_pedido(estado: 'confirmado'));

      expect(
        () => repo.avanzar(_negocio, 'p1', EstadoPedido.entregado),
        throwsStateError,
      );
      expect(
        () => repo.avanzar(_negocio, 'p1', EstadoPedido.listo),
        throwsStateError,
      );
      expect(
        () => repo.avanzar(_negocio, 'p1', EstadoPedido.confirmado),
        throwsArgumentError,
      );
    });

    test('recojo pasa por «listo»', () async {
      await pedidos()
          .doc('p1')
          .set(_pedido(estado: 'confirmado', tipoEntrega: 'recojo'));

      await repo.avanzar(_negocio, 'p1', EstadoPedido.listo);

      expect((await leerPedido('p1'))['estado'], 'listo');
    });

    test(
      'marca el pago, también después de entregar, pero no al cancelar',
      () async {
        await pedidos().doc('p1').set(_pedido(estado: 'entregado'));
        await pedidos().doc('p2').set(_pedido(estado: 'cancelado'));

        await repo.marcarPago(_negocio, 'p1', EstadoPago.pagado);

        expect((await leerPedido('p1'))['estadoPago'], 'pagado');
        expect(
          () => repo.marcarPago(_negocio, 'p2', EstadoPago.pagado),
          throwsStateError,
        );
      },
    );

    test('el reembolso se marca hecho solo si estaba pendiente', () async {
      await pedidos()
          .doc('p1')
          .set(_pedido(estado: 'cancelado', reembolso: 'pendiente'));
      await pedidos().doc('p2').set(_pedido(estado: 'cancelado'));

      await repo.marcarReembolsoHecho(_negocio, 'p1');

      expect((await leerPedido('p1'))['reembolso'], 'hecho');
      expect(() => repo.marcarReembolsoHecho(_negocio, 'p2'), throwsStateError);
    });
  });

  test('sin negocioId no opera', () {
    expect(() => repo.escucharAbiertos('  '), throwsStateError);
  });
}
