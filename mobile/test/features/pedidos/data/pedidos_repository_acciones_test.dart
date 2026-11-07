import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';

import '../helpers/banco_pedidos_repo.dart';
import '../helpers/pedidos_de_prueba.dart';

void main() {
  final banco = BancoPedidosRepo();
  setUp(banco.preparar);

  group('confirmar', () {
    test(
      'descuenta el stock, guarda lo descontado y pasa a confirmado',
      () async {
        await banco.pedidos().doc('p1').set(pedidoMapa());

        final r = await banco.repo.confirmar(negocioDePrueba, 'p1');

        expect(r.ok, isTrue);
        expect((await banco.leerProducto('queso'))!.stockBase, 850);
        expect((await banco.leerProducto('gaseosa'))!.stock, 8);
        final doc = await banco.leerPedido('p1');
        expect(doc['estado'], 'confirmado');
        expect(doc['stockDescontado'], hasLength(2));
        expect(doc['historial'], hasLength(1));
      },
    );

    test('si no alcanza un producto no se descuenta NADA', () async {
      await banco.producto(productoSimple(stock: 1));
      await banco.pedidos().doc('p1').set(pedidoMapa());

      final r = await banco.repo.confirmar(negocioDePrueba, 'p1');

      expect(r.ok, isFalse);
      expect(r.faltas.single.nombre, 'Gaseosa Inca');
      expect(r.faltas.single.hay, 1);
      expect((await banco.leerProducto('queso'))!.stockBase, 1200);
      expect((await banco.leerProducto('gaseosa'))!.stock, 1);
      expect((await banco.leerPedido('p1'))['estado'], 'nuevo');
    });

    test('confirmar dos veces descuenta una sola vez', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa());

      await banco.repo.confirmar(negocioDePrueba, 'p1');
      final segunda = await banco.repo.confirmar(negocioDePrueba, 'p1');

      expect(segunda.yaNoEsNuevo, isTrue);
      expect((await banco.leerProducto('gaseosa'))!.stock, 8);
    });

    test('un pedido que no existe se avisa, no se rompe', () async {
      final r = await banco.repo.confirmar(negocioDePrueba, 'fantasma');

      expect(r.yaNoEsNuevo, isTrue);
    });

    test('un producto borrado se avisa y no se descuenta nada', () async {
      await banco.db
          .collection('negocios')
          .doc(negocioDePrueba)
          .collection('productos')
          .doc('gaseosa')
          .delete();
      await banco.pedidos().doc('p1').set(pedidoMapa());

      final r = await banco.repo.confirmar(negocioDePrueba, 'p1');

      expect(r.sinProducto, ['Gaseosa Inca']);
      expect((await banco.leerProducto('queso'))!.stockBase, 1200);
    });

    test('un combo descuenta cada parte × cantidad', () async {
      await banco.producto(comboGaseosaYPapas());
      await banco.producto(
        productoSimple(id: 'papas', nombre: 'Papas', stock: 10),
      );
      await banco
          .pedidos()
          .doc('p1')
          .set(
            pedidoMapa(
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

      final r = await banco.repo.confirmar(negocioDePrueba, 'p1');

      expect(r.ok, isTrue);
      expect((await banco.leerProducto('gaseosa'))!.stock, 8);
      expect((await banco.leerProducto('papas'))!.stock, 6);
    });

    test('con modelos baja la fila y el total del producto', () async {
      await banco.producto(poloConModelos(stockM: 3, stockL: 2));
      await banco
          .pedidos()
          .doc('p1')
          .set(
            pedidoMapa(
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

      await banco.repo.confirmar(negocioDePrueba, 'p1');

      final polo = (await banco.leerProducto('polo'))!;
      expect(polo.modelos.single.filas.firstWhere((f) => f.id == 'm').stock, 1);
      expect(polo.stock, 3);
    });

    test(
      'avisa si con los precios de hoy el total sería otro, pero confirma',
      () async {
        await banco.producto(productoSimple(stock: 10, precioCentavos: 400));
        await banco.pedidos().doc('p1').set(pedidoMapa());

        final r = await banco.repo.confirmar(negocioDePrueba, 'p1');

        expect(r.ok, isTrue);
        expect(r.totalActualCentavos, 1940);
        expect(r.lineasCambiadas, ['Gaseosa Inca']);
        expect((await banco.leerPedido('p1'))['totalCentavos'], 1840);
      },
    );
  });

  group('cancelar', () {
    test('devuelve lo descontado y suma sobre lo repuesto', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa());
      await banco.repo.confirmar(negocioDePrueba, 'p1');
      // El vendedor repone gaseosas mientras tanto: 8 → 12.
      await banco.producto(productoSimple(stock: 12));

      final omitidos = await banco.repo.cancelar(negocioDePrueba, 'p1');

      expect(omitidos, 0);
      expect((await banco.leerProducto('gaseosa'))!.stock, 14);
      expect((await banco.leerProducto('queso'))!.stockBase, 1200);
      final doc = await banco.leerPedido('p1');
      expect(doc['estado'], 'cancelado');
      expect(doc['reembolso'], 'ninguno');
      expect(doc['historial'], hasLength(2));
    });

    test('un pedido pagado queda con el reembolso pendiente', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estadoPago: 'pagado'));
      await banco.repo.confirmar(negocioDePrueba, 'p1');

      await banco.repo.cancelar(negocioDePrueba, 'p1');

      expect((await banco.leerPedido('p1'))['reembolso'], 'pendiente');
    });

    test('un pedido nuevo no toca el stock', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa());

      await banco.repo.cancelar(negocioDePrueba, 'p1');

      expect((await banco.leerPedido('p1'))['estado'], 'cancelado');
      expect((await banco.leerProducto('gaseosa'))!.stock, 10);
      expect((await banco.leerProducto('queso'))!.stockBase, 1200);
    });

    test('si el producto se borró cuenta lo omitido y sigue', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa());
      await banco.repo.confirmar(negocioDePrueba, 'p1');
      await banco.db
          .collection('negocios')
          .doc(negocioDePrueba)
          .collection('productos')
          .doc('queso')
          .delete();

      final omitidos = await banco.repo.cancelar(negocioDePrueba, 'p1');

      expect(omitidos, 1);
      expect((await banco.leerProducto('gaseosa'))!.stock, 10);
      expect((await banco.leerPedido('p1'))['estado'], 'cancelado');
    });

    test(
      'soloSiEstaNuevo no cancela uno ya confirmado ni toca su stock',
      () async {
        await banco.pedidos().doc('p1').set(pedidoMapa());
        await banco.pedidos().doc('p2').set(pedidoMapa());
        await banco.repo.confirmar(negocioDePrueba, 'p1');

        await banco.repo.cancelar(negocioDePrueba, 'p2', soloSiEstaNuevo: true);

        expect((await banco.leerPedido('p2'))['estado'], 'cancelado');
        expect(
          () =>
              banco.repo.cancelar(negocioDePrueba, 'p1', soloSiEstaNuevo: true),
          throwsStateError,
        );
        expect((await banco.leerPedido('p1'))['estado'], 'confirmado');
        expect((await banco.leerProducto('gaseosa'))!.stock, 8);
      },
    );

    test(
      'ya no se cancela un entregado, un cancelado ni uno que no existe',
      () async {
        await banco.pedidos().doc('e').set(pedidoMapa(estado: 'entregado'));
        await banco.pedidos().doc('c').set(pedidoMapa(estado: 'cancelado'));

        expect(
          () => banco.repo.cancelar(negocioDePrueba, 'e'),
          throwsStateError,
        );
        expect(
          () => banco.repo.cancelar(negocioDePrueba, 'c'),
          throwsStateError,
        );
        expect(
          () => banco.repo.cancelar(negocioDePrueba, 'nada'),
          throwsStateError,
        );
      },
    );
  });

  group('avanzar, pago y reembolso', () {
    test(
      'delivery: confirmado → en camino → entregado, con historial',
      () async {
        await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'confirmado'));

        await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.enCamino);
        await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

        final doc = await banco.leerPedido('p1');
        expect(doc['estado'], 'entregado');
        expect(doc['historial'], hasLength(2));
      },
    );

    test('entregar y cobrar cambia estado y pago a la vez', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(
        negocioDePrueba,
        'p1',
        EstadoPedido.entregado,
        pago: EstadoPago.pagado,
      );

      final doc = await banco.leerPedido('p1');
      expect(doc['estado'], 'entregado');
      expect(doc['estadoPago'], 'pagado');
    });

    test('entregar sin pago no cambia el pago', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      expect((await banco.leerPedido('p1'))['estadoPago'], 'pendiente');
    });

    test('no se saltan pasos ni se confirma por aquí', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'confirmado'));

      expect(
        () => banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado),
        throwsStateError,
      );
      expect(
        () => banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.listo),
        throwsStateError,
      );
      expect(
        () =>
            banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.confirmado),
        throwsArgumentError,
      );
    });

    test('recojo pasa por «listo»', () async {
      await banco
          .pedidos()
          .doc('p1')
          .set(pedidoMapa(estado: 'confirmado', tipoEntrega: 'recojo'));

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.listo);

      expect((await banco.leerPedido('p1'))['estado'], 'listo');
    });

    test(
      'marca el pago, también después de entregar, pero no al cancelar',
      () async {
        await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'entregado'));
        await banco.pedidos().doc('p2').set(pedidoMapa(estado: 'cancelado'));

        await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

        expect((await banco.leerPedido('p1'))['estadoPago'], 'pagado');
        expect(
          () => banco.repo.marcarPago(negocioDePrueba, 'p2', EstadoPago.pagado),
          throwsStateError,
        );
      },
    );

    test('el reembolso se marca hecho solo si estaba pendiente', () async {
      await banco
          .pedidos()
          .doc('p1')
          .set(pedidoMapa(estado: 'cancelado', reembolso: 'pendiente'));
      await banco.pedidos().doc('p2').set(pedidoMapa(estado: 'cancelado'));

      await banco.repo.marcarReembolsoHecho(negocioDePrueba, 'p1');

      expect((await banco.leerPedido('p1'))['reembolso'], 'hecho');
      expect(
        () => banco.repo.marcarReembolsoHecho(negocioDePrueba, 'p2'),
        throwsStateError,
      );
    });
  });
}
