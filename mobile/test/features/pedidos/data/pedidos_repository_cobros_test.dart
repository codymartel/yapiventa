import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/pedidos/data/pedidos_repository.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';

import '../helpers/banco_pedidos_repo.dart';

// El reloj del banco marca el 5 a las 12:00 de Lima; el 6, un día después.
const _dia5 = '2026-11-05';
const _dia6 = '2026-11-06';

void main() {
  final banco = BancoPedidosRepo();
  setUp(banco.preparar);

  Future<Map<String, dynamic>?> datos(String dia) async {
    final doc = await banco.db
        .collection('negocios')
        .doc(negocioDePrueba)
        .collection('resumenes')
        .doc(dia)
        .get();
    return doc.data();
  }

  /// El día de Caja tal como lo lee la pantalla (sin gastos).
  Future<DiaCaja> caja(String dia) async => DiaCaja(
    ventas: ResumenVentasDiaMapper.desdeFirestore(dia, await datos(dia)),
  );

  /// Delivery de la tienda de S/ 18,40 en efectivo.
  Future<void> pedido(String estado, {String estadoPago = 'pendiente'}) {
    return banco
        .pedidos()
        .doc('p1')
        .set(
          pedidoMapa(estado: estado, estadoPago: estadoPago)
            ..['metodoPago'] = 'Efectivo',
        );
  }

  PedidosRepository repoDel6() => PedidosRepository(
    db: banco.db,
    reloj: () => DateTime.utc(2026, 11, 6, 17),
  );

  group('entregado sin cobrar', () {
    test('NO sube el efectivo; al marcarlo cobrado sí lo sube', () async {
      await pedido('en_camino');

      await banco.repo.avanzar(
        negocioDePrueba,
        'p1',
        EstadoPedido.entregado,
        pago: EstadoPago.pendiente,
      );

      var dia = await caja(_dia5);
      expect(dia.ventasCentavos, 1840, reason: 'la venta sí cuenta');
      expect(dia.efectivoCentavos, 0, reason: 'al cajón no entró nada');
      expect(dia.porCobrarCentavos, 1840);
      expect(dia.ventas.contadores.porCobrar, 1);
      expect((await banco.leerPedido('p1'))['cobro'], {
        'centavos': 1840,
        'porCobrarDia': _dia5,
      });

      await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

      dia = await caja(_dia5);
      expect(dia.efectivoCentavos, 1840);
      expect(dia.porCobrarCentavos, 0);
      expect(dia.ventasCentavos, 1840, reason: 'cobrar no es otra venta');
      expect(dia.ventas.entregados, 1);
      expect(dia.ventas.ultimosEntregados.single.cobrado, isTrue);
      final p = await banco.leerPedido('p1');
      expect(p['estadoPago'], 'pagado');
      expect(p['cobro'], {
        'dia': _dia5,
        'pago': 'efectivo',
        'centavos': 1840,
        'porCobrarDia': _dia5,
      });
    });

    test('cobrado al día siguiente: entra el 6 y sale del «por cobrar» '
        'del 5', () async {
      await pedido('en_camino');
      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      await repoDel6().marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

      final del5 = await caja(_dia5);
      final del6 = await caja(_dia6);
      expect(del5.efectivoCentavos, 0);
      expect(del5.porCobrarCentavos, 0);
      expect(del5.ventasCentavos, 1840);
      expect(del6.efectivoCentavos, 1840);
      expect(del6.ventasCentavos, 0, reason: 'la venta es del día 5');
    });

    test('marcarlo cobrado dos veces no suma dos veces', () async {
      await pedido('en_camino');
      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);
      await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

      expect((await caja(_dia5)).efectivoCentavos, 1840);
    });

    test('un cobro ya en la caja no se desmarca', () async {
      await pedido('en_camino');
      await banco.repo.avanzar(
        negocioDePrueba,
        'p1',
        EstadoPedido.entregado,
        pago: EstadoPago.pagado,
      );

      expect(
        () =>
            banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pendiente),
        throwsStateError,
      );
      expect((await caja(_dia5)).efectivoCentavos, 1840);
    });
  });

  test('entregar y cobrar a la vez: entra una sola vez', () async {
    await pedido('en_camino');

    await banco.repo.avanzar(
      negocioDePrueba,
      'p1',
      EstadoPedido.entregado,
      pago: EstadoPago.pagado,
    );

    final dia = await caja(_dia5);
    expect(dia.efectivoCentavos, 1840);
    expect(dia.porCobrarCentavos, 0);
  });

  group('pago adelantado', () {
    test('entra el día en que se paga y no otra vez al entregar', () async {
      await pedido('confirmado', estadoPago: 'pendiente');
      await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

      var dia = await caja(_dia5);
      expect(dia.efectivoCentavos, 1840);
      expect(dia.ventasCentavos, 0, reason: 'todavía no se entrega');

      await banco.repo.avanzar(negocioDePrueba, 'p1', EstadoPedido.enCamino);
      await repoDel6().avanzar(negocioDePrueba, 'p1', EstadoPedido.entregado);

      dia = await caja(_dia5);
      final del6 = await caja(_dia6);
      expect(dia.efectivoCentavos, 1840);
      expect(del6.ventasCentavos, 1840);
      expect(del6.efectivoCentavos, 0);
      expect(del6.ventas.ultimosEntregados.single.cobrado, isTrue);
    });

    test('al cancelarlo, sale de la caja del día en que entró', () async {
      await pedido('nuevo');
      await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

      await repoDel6().cancelar(negocioDePrueba, 'p1');

      expect((await caja(_dia5)).efectivoCentavos, 0);
      expect(await datos(_dia6), isNull, reason: 'no toca otro día');
      final p = await banco.leerPedido('p1');
      expect(p['estado'], 'cancelado');
      expect(p['reembolso'], 'pendiente');
    });
  });

  group('pedidos de antes de este cambio (sin cobro)', () {
    test('entregado sin cobrar: cobrarlo no suma otra vez', () async {
      // Con el código viejo ya sumó su forma de pago al entregarse.
      await pedido('entregado');

      await banco.repo.marcarPago(negocioDePrueba, 'p1', EstadoPago.pagado);

      expect(await datos(_dia5), isNull);
      final p = await banco.leerPedido('p1');
      expect(p['estadoPago'], 'pagado');
      expect(p.containsKey('cobro'), isFalse);
    });

    test('cancelar uno sin cobro no toca la caja', () async {
      await pedido('nuevo');

      await banco.repo.cancelar(negocioDePrueba, 'p1');

      expect(await datos(_dia5), isNull);
    });
  });
}
