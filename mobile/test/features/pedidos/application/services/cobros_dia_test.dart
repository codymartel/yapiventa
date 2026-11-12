import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/cobros_dia.dart';
import 'package:mobile/features/pedidos/domain/models/cobro_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';

// 17:00 UTC = 12:00 en Lima del 5; el 6 a la misma hora.
final _dia5 = DateTime.utc(2026, 11, 5, 17);
final _dia6 = DateTime.utc(2026, 11, 6, 17);

// Delivery de S/ 40,00 en efectivo.
Pedido _pedido({
  EstadoPedido estado = EstadoPedido.enCamino,
  EstadoPago pago = EstadoPago.pendiente,
  CobroPedido? cobro,
}) {
  return Pedido(
    id: 'p1',
    estado: estado,
    metodoPago: 'Efectivo',
    estadoPago: pago,
    totalCentavos: 4000,
    cobro: cobro,
  );
}

void main() {
  group('al entregar', () {
    test('sin cobrar: no entra a la caja, queda «por cobrar» hoy', () {
      final plan = CobrosDia.alEntregar(
        _pedido(),
        cobradoAhora: false,
        ahora: _dia5,
      );

      final a = plan.ajustes.single;
      expect(a.dia, '2026-11-05');
      expect(a.cobradoCentavos, 0);
      expect(a.porCobrarCentavos, 4000);
      expect(a.porCobrar, 1);
      expect(plan.cobro!.contado, isFalse);
      expect(plan.cobro!.pendiente, isTrue);
      expect(plan.cobro!.porCobrarDia, '2026-11-05');
    });

    test('cobrando al entregar: la plata entra hoy', () {
      final plan = CobrosDia.alEntregar(
        _pedido(),
        cobradoAhora: true,
        ahora: _dia5,
      );

      final a = plan.ajustes.single;
      expect(a.pago, 'efectivo');
      expect(a.cobradoCentavos, 4000);
      expect(a.porCobrarCentavos, 0);
      expect(plan.cobro!.dia, '2026-11-05');
    });

    test('ya cobrado antes (pago adelantado): no suma otra vez', () {
      final plan = CobrosDia.alEntregar(
        _pedido(
          pago: EstadoPago.pagado,
          cobro: const CobroPedido(
            dia: '2026-11-04',
            pago: 'yape',
            centavos: 4000,
          ),
        ),
        cobradoAhora: true,
        ahora: _dia5,
      );

      expect(plan.ajustes, isEmpty);
      expect(plan.cobro, isNull);
    });

    test('pagado con el código viejo (sin cobro): suma al entregar', () {
      final plan = CobrosDia.alEntregar(
        _pedido(pago: EstadoPago.pagado),
        cobradoAhora: true,
        ahora: _dia5,
      );

      expect(plan.ajustes.single.cobradoCentavos, 4000);
    });
  });

  group('al marcar cobrado', () {
    test('entregado sin cobrar ayer: entra hoy y sale de «por cobrar» '
        'de ayer', () {
      final plan = CobrosDia.alCobrar(
        _pedido(
          estado: EstadoPedido.entregado,
          cobro: const CobroPedido(centavos: 4000, porCobrarDia: '2026-11-05'),
        ),
        _dia6,
      );

      expect(plan.dias, {'2026-11-06', '2026-11-05'});
      final hoy = plan.ajustes.firstWhere((a) => a.dia == '2026-11-06');
      final ayer = plan.ajustes.firstWhere((a) => a.dia == '2026-11-05');
      expect(hoy.cobradoCentavos, 4000);
      expect(ayer.porCobrarCentavos, -4000);
      expect(ayer.porCobrar, -1);
      expect(ayer.cobradoPedidoId, 'p1');
      expect(plan.cobro!.dia, '2026-11-06');
      expect(plan.cobro!.porCobrarDia, '2026-11-05');
      expect(plan.cobro!.pendiente, isFalse);
    });

    test('pago adelantado (sin entregar): entra hoy', () {
      final plan = CobrosDia.alCobrar(
        _pedido(estado: EstadoPedido.confirmado),
        _dia5,
      );

      expect(plan.ajustes.single.cobradoCentavos, 4000);
      expect(plan.cobro!.dia, '2026-11-05');
    });

    test('ya cobrado: no hace nada', () {
      final plan = CobrosDia.alCobrar(_pedido(pago: EstadoPago.pagado), _dia5);

      expect(plan.ajustes, isEmpty);
      expect(plan.cobro, isNull);
    });

    test('pedido viejo entregado sin cobro: ya se sumó al entregar', () {
      final plan = CobrosDia.alCobrar(
        _pedido(estado: EstadoPedido.entregado),
        _dia5,
      );

      expect(plan.ajustes, isEmpty);
      expect(plan.cobro, isNull);
    });
  });

  group('al cancelar o anular', () {
    test('resta lo cobrado del día en que entró', () {
      final plan = CobrosDia.alQuitar(
        _pedido(
          pago: EstadoPago.pagado,
          cobro: const CobroPedido(
            dia: '2026-11-04',
            pago: 'yape',
            centavos: 4000,
          ),
        ),
      );

      final a = plan.ajustes.single;
      expect(a.dia, '2026-11-04');
      expect(a.pago, 'yape');
      expect(a.cobradoCentavos, -4000);
    });

    test('quita lo que seguía «por cobrar»', () {
      final plan = CobrosDia.alQuitar(
        _pedido(
          estado: EstadoPedido.entregado,
          cobro: const CobroPedido(centavos: 4000, porCobrarDia: '2026-11-05'),
        ),
        diaEntrega: '2026-11-05',
      );

      final a = plan.ajustes.single;
      expect(a.porCobrarCentavos, -4000);
      expect(a.porCobrar, -1);
      expect(a.cobradoCentavos, 0);
    });

    test('sin cobro y sin entregar: no toca la caja', () {
      expect(CobrosDia.alQuitar(_pedido()).ajustes, isEmpty);
    });

    test('venta vieja entregada (sin cobro): resta del día de la entrega', () {
      final plan = CobrosDia.alQuitar(
        _pedido(estado: EstadoPedido.entregado, pago: EstadoPago.pagado),
        diaEntrega: '2026-11-05',
      );

      final a = plan.ajustes.single;
      expect(a.dia, '2026-11-05');
      expect(a.pago, 'efectivo');
      expect(a.cobradoCentavos, -4000);
    });
  });

  group('alNacer (venta de Caja)', () {
    test('nace cobrada: entra hoy', () {
      final plan = CobrosDia.alNacer(_pedido(pago: EstadoPago.pagado), _dia5);

      expect(plan.ajustes.single.cobradoCentavos, 4000);
      expect(plan.cobro!.dia, '2026-11-05');
    });

    test('«cobrar al entregar»: nada todavía', () {
      expect(CobrosDia.alNacer(_pedido(), _dia5), same(PlanCobro.nada));
    });
  });

  group('aplicar', () {
    const dia = '2026-11-05';
    final base = ResumenVentasDia(
      dia: dia,
      ventasCentavos: 9000,
      entregados: 2,
      ultimosEntregados: const [
        EntregadoReciente(pedidoId: 'p1', totalCentavos: 4000),
        EntregadoReciente(pedidoId: 'p2', totalCentavos: 5000, cobrado: true),
      ],
      contadores: const ContadoresDia(
        porPago: {'efectivo': 5000, 'yape': 100},
        porCobrarCentavos: 4000,
        porCobrar: 1,
        porEntrega: {'delivery': 9000},
      ),
    );

    test('cobrar: suma, quita el «por cobrar» y lo marca cobrado', () {
      final r = CobrosDia.aplicar(
        {dia: base},
        const [
          AjusteCobroDia(
            dia: dia,
            pago: 'efectivo',
            cobradoCentavos: 4000,
            porCobrarCentavos: -4000,
            porCobrar: -1,
            cobradoPedidoId: 'p1',
          ),
        ],
      )[dia]!;

      expect(r.contadores.porPago, {'efectivo': 9000, 'yape': 100});
      expect(r.contadores.porCobrarCentavos, 0);
      expect(r.contadores.porCobrar, 0);
      expect(r.ultimosEntregados.first.cobrado, isTrue);
      // Lo demás del día no cambia.
      expect(r.ventasCentavos, 9000);
      expect(r.entregados, 2);
      expect(r.contadores.porEntrega, {'delivery': 9000});
    });

    test('restar quita la clave que llega a 0 y nunca baja de 0', () {
      final r = CobrosDia.aplicar(
        {dia: base},
        const [
          AjusteCobroDia(dia: dia, pago: 'yape', cobradoCentavos: -500),
          AjusteCobroDia(dia: dia, porCobrarCentavos: -9999, porCobrar: -3),
        ],
      )[dia]!;

      expect(r.contadores.porPago, {'efectivo': 5000});
      expect(r.contadores.porCobrarCentavos, 0);
      expect(r.contadores.porCobrar, 0);
    });

    test('un día que no estaba leído empieza vacío', () {
      final r = CobrosDia.aplicar({}, const [
        AjusteCobroDia(dia: dia, pago: 'efectivo', cobradoCentavos: 4000),
      ]);

      expect(r[dia]!.contadores.porPago, {'efectivo': 4000});
      expect(r[dia]!.ventasCentavos, 0);
    });
  });
}
