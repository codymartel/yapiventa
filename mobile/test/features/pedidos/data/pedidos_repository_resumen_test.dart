import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';

import '../helpers/banco_pedidos_repo.dart';
import '../helpers/pedidos_de_prueba.dart';

void main() {
  final banco = BancoPedidosRepo();
  setUp(banco.preparar);

  group('resumen del día', () {
    Future<Map<String, dynamic>?> leerResumen([
      String dia = '2026-11-05',
    ]) async {
      final doc = await banco.db
          .collection('negocios')
          .doc(negocioDePrueba)
          .collection('resumenes')
          .doc(dia)
          .get();
      return doc.data();
    }

    test('confirmar suma los minutos que tardó en confirmarse', () async {
      // Llegó 16:00 UTC y el reloj marca 17:00: 60 minutos.
      await banco.pedidos().doc('p1').set(pedidoMapa());

      await banco.repo.confirmar(negocioDePrueba, 'p1');

      final r = await leerResumen();
      expect(r!['confirmados'], 1);
      expect(r['sumaMinutosConfirmar'], 60);
    });

    test(
      'un confirmar bloqueado por falta de stock no toca el resumen',
      () async {
        await banco.producto(productoSimple(stock: 1));
        await banco.pedidos().doc('p1').set(pedidoMapa());

        await banco.repo.confirmar(negocioDePrueba, 'p1');

        expect(await leerResumen(), isNull);
      },
    );

    test('entregar suma la venta y guarda el entregado reciente', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      final r = await leerResumen();
      expect(r!['ventasCentavos'], 1840);
      expect(r['entregados'], 1);
      final recientes = r['ultimosEntregados'] as List;
      expect(recientes.single['pedidoId'], 'p1');
      expect(recientes.single['cliente'], 'Rosa Quispe');
      expect(recientes.single['totalCentavos'], 1840);
      expect(recientes.single['cobrado'], isFalse);
    });

    test('entregar y cobrar guarda que se cobró', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(
        negocioDePrueba,
        'p1',
        EstadoPedido.entregado,
        pago: EstadoPago.pagado,
      );

      final r = await leerResumen();
      expect((r!['ultimosEntregados'] as List).single['cobrado'], isTrue);
    });

    test('entregar suma los contadores del día (3b)', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(
        negocioDePrueba,
        'p1',
        EstadoPedido.entregado,
        pago: EstadoPago.pagado,
      );

      final r = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      // Reloj 17:00 UTC = 12:00 en Lima. Pedido de la tienda: no es mostrador.
      expect(r.contadores.porEntrega, {'delivery': 1840});
      expect(r.contadores.porHora, {'12': 1840});
      expect(r.contadores.porProducto.keys, containsAll(['queso', 'gaseosa']));
      expect(r.contadores.mostrador, 0);
      expect(r.contadores.anuladas, 0);
    });

    test('dos entregas acumulan y no pisan los contadores', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));
      await banco.pedidos().doc('p2').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);
      await banco.repo.avanzar(negocioDePrueba, 'p2', EstadoPedido.entregado);

      final r = ResumenVentasDiaMapper.desdeFirestore(
        '2026-11-05',
        await leerResumen(),
      );
      expect(r.ventasCentavos, 3680);
      expect(r.entregados, 2);
      expect(r.contadores.porEntrega, {'delivery': 3680});
    });

    test('la hora del historial es la misma del resumen', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      final historial = (await banco.leerPedido('p1'))['historial'] as List;
      final entregado = historial.last['fecha'] as Timestamp;
      expect(entregado.toDate().toUtc(), DateTime.utc(2026, 11, 5, 17));
    });

    test(
      'varias entregas se acumulan y solo se guardan las últimas 5',
      () async {
        for (var i = 0; i < 6; i++) {
          await banco.pedidos().doc('p$i').set(pedidoMapa(estado: 'listo'));
          await banco.repo.avanzar(
            negocioDePrueba,
            'p$i',
            EstadoPedido.entregado,
          );
        }

        final r = await leerResumen();
        expect(r!['entregados'], 6);
        expect(r['ventasCentavos'], 6 * 1840);
        final ids = [
          for (final e in r['ultimosEntregados'] as List) e['pedidoId'],
        ];
        expect(ids, ['p5', 'p4', 'p3', 'p2', 'p1']);
      },
    );

    test('un paso que no es entregar no suma ventas', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'confirmado'));

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.enCamino);

      expect(await leerResumen(), isNull);
    });

    test('entregar dos veces no cuenta dos veces', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));
      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      expect(
        () => banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado),
        throwsStateError,
      );

      final r = await leerResumen();
      expect(r!['entregados'], 1);
      expect(r['ventasCentavos'], 1840);
    });

    test('cancelar no toca el resumen', () async {
      await banco.pedidos().doc('p1').set(pedidoMapa());

      await banco.repo.cancelar(negocioDePrueba, 'p1');

      expect(await leerResumen(), isNull);
    });

    test(
      'escucha el resumen del día: vacío primero y luego los cambios',
      () async {
        final recibidos = <int>[];
        final suscripcion = banco.repo
            .escucharResumenDia(negocioDePrueba, '2026-11-05')
            .listen((r) => recibidos.add(r.ventasCentavos));
        await Future<void>.delayed(Duration.zero);
        await banco.pedidos().doc('p1').set(pedidoMapa(estado: 'en_camino'));

        await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);
        await Future<void>.delayed(Duration.zero);
        await suscripcion.cancel();

        expect(recibidos.first, 0);
        expect(recibidos.last, 1840);
      },
    );
  });
}
