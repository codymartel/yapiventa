import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/transiciones_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';

import '../../helpers/pedidos_de_prueba.dart';

void main() {
  group('siguiente', () {
    test('delivery: nuevo → confirmado → en camino → entregado', () {
      const e = TipoEntrega.delivery;

      expect(
        TransicionesPedido.siguiente(EstadoPedido.nuevo, e),
        EstadoPedido.confirmado,
      );
      expect(
        TransicionesPedido.siguiente(EstadoPedido.confirmado, e),
        EstadoPedido.enCamino,
      );
      expect(
        TransicionesPedido.siguiente(EstadoPedido.enCamino, e),
        EstadoPedido.entregado,
      );
    });

    test('recojo: confirmado → listo → entregado', () {
      const e = TipoEntrega.recojo;

      expect(
        TransicionesPedido.siguiente(EstadoPedido.confirmado, e),
        EstadoPedido.listo,
      );
      expect(
        TransicionesPedido.siguiente(EstadoPedido.listo, e),
        EstadoPedido.entregado,
      );
    });

    test('entregado y cancelado no tienen siguiente ni botón', () {
      for (final estado in [EstadoPedido.entregado, EstadoPedido.cancelado]) {
        expect(
          TransicionesPedido.siguiente(estado, TipoEntrega.delivery),
          isNull,
        );
        expect(
          TransicionesPedido.etiquetaBoton(estado, TipoEntrega.delivery),
          isEmpty,
        );
      }
    });

    test('el botón dice lo que hace según la entrega', () {
      expect(
        TransicionesPedido.etiquetaBoton(
          EstadoPedido.confirmado,
          TipoEntrega.delivery,
        ),
        'Enviar a domicilio',
      );
      expect(
        TransicionesPedido.etiquetaBoton(
          EstadoPedido.confirmado,
          TipoEntrega.recojo,
        ),
        'Listo para recoger',
      );
    });
  });

  group('reglas', () {
    test('se cancela solo siendo nuevo o confirmado', () {
      expect(TransicionesPedido.puedeCancelar(EstadoPedido.nuevo), isTrue);
      expect(TransicionesPedido.puedeCancelar(EstadoPedido.confirmado), isTrue);
      expect(TransicionesPedido.puedeCancelar(EstadoPedido.enCamino), isFalse);
      expect(TransicionesPedido.puedeCancelar(EstadoPedido.listo), isFalse);
      expect(TransicionesPedido.puedeCancelar(EstadoPedido.entregado), isFalse);
      expect(TransicionesPedido.puedeCancelar(EstadoPedido.cancelado), isFalse);
    });

    test(
      'cobrar se puede marcar hasta después de entregar, no al cancelar',
      () {
        expect(
          TransicionesPedido.puedeCambiarPago(EstadoPedido.entregado),
          isTrue,
        );
        expect(
          TransicionesPedido.puedeCambiarPago(EstadoPedido.cancelado),
          isFalse,
        );
      },
    );

    test('solo nuevo → confirmado mueve stock', () {
      expect(
        TransicionesPedido.descuentaStock(
          EstadoPedido.nuevo,
          EstadoPedido.confirmado,
        ),
        isTrue,
      );
      expect(
        TransicionesPedido.descuentaStock(
          EstadoPedido.confirmado,
          EstadoPedido.enCamino,
        ),
        isFalse,
      );
    });

    test('cancelar un pedido pagado deja el reembolso pendiente', () {
      final pagado = pedidoDe([], pago: EstadoPago.pagado);
      final sinPagar = pedidoDe([]);

      expect(
        TransicionesPedido.reembolsoAlCancelar(pagado),
        EstadoReembolso.pendiente,
      );
      expect(
        TransicionesPedido.reembolsoAlCancelar(sinPagar),
        EstadoReembolso.ninguno,
      );
    });

    test(
      'marcar el reembolso hecho solo en cancelados con reembolso pendiente',
      () {
        final pendiente = pedidoDe(
          [],
          estado: EstadoPedido.cancelado,
        ).copyWith(reembolso: EstadoReembolso.pendiente);
        final hecho = pendiente.copyWith(reembolso: EstadoReembolso.hecho);
        final abierto = pedidoDe(
          [],
        ).copyWith(reembolso: EstadoReembolso.pendiente);

        expect(TransicionesPedido.puedeMarcarReembolsoHecho(pendiente), isTrue);
        expect(TransicionesPedido.puedeMarcarReembolsoHecho(hecho), isFalse);
        expect(TransicionesPedido.puedeMarcarReembolsoHecho(abierto), isFalse);
      },
    );
  });

  group('vencidos (12 h sin confirmar)', () {
    final ahora = DateTime.utc(2026, 11, 5, 12);

    test('justo 12 h no vence; 12 h y un minuto, sí', () {
      final justo = pedidoDe(
        [],
        fecha: ahora.subtract(const Duration(hours: 12)),
      );
      final pasado = pedidoDe(
        [],
        fecha: ahora.subtract(const Duration(hours: 12, minutes: 1)),
      );

      expect(TransicionesPedido.estaVencido(justo, ahora), isFalse);
      expect(TransicionesPedido.estaVencido(pasado, ahora), isTrue);
    });

    test('un confirmado viejo no está vencido', () {
      final p = pedidoDe(
        [],
        estado: EstadoPedido.confirmado,
        fecha: ahora.subtract(const Duration(days: 3)),
      );

      expect(TransicionesPedido.estaVencido(p, ahora), isFalse);
    });

    test('sin fecha todavía (escribiéndose) no se considera vencido', () {
      expect(TransicionesPedido.estaVencido(pedidoDe([]), ahora), isFalse);
    });
  });

  group('EstadoPedido.desdeValor', () {
    test('lee los nombres de la app anterior', () {
      expect(
        EstadoPedido.desdeValor('pendiente_confirmacion'),
        EstadoPedido.nuevo,
      );
      expect(EstadoPedido.desdeValor('pendiente'), EstadoPedido.nuevo);
      expect(
        EstadoPedido.desdeValor('en_preparacion'),
        EstadoPedido.confirmado,
      );
      expect(EstadoPedido.desdeValor('listo_para_recoger'), EstadoPedido.listo);
      expect(
        EstadoPedido.desdeValor('pendiente_reembolso'),
        EstadoPedido.cancelado,
      );
    });

    test(
      'un valor desconocido o vacío es nuevo: nunca se pierde un pedido',
      () {
        expect(EstadoPedido.desdeValor('raro'), EstadoPedido.nuevo);
        expect(EstadoPedido.desdeValor(null), EstadoPedido.nuevo);
      },
    );

    test('ida y vuelta con el valor guardado', () {
      for (final estado in EstadoPedido.values) {
        expect(EstadoPedido.desdeValor(estado.valor), estado);
      }
    });
  });

  group('puedeAnular y anulada', () {
    final venta = [lineaSimple(cantidad: 1, precioCentavos: 450)];

    test('solo una venta de Caja ya entregada se anula', () {
      for (final estado in EstadoPedido.values) {
        final pedido = pedidoDe(
          venta,
          estado: estado,
          origen: OrigenPedido.mostrador,
        );
        expect(
          TransicionesPedido.puedeAnular(pedido),
          estado == EstadoPedido.entregado,
          reason: estado.valor,
        );
      }
    });

    test('un pedido de la tienda entregado no se anula', () {
      final pedido = pedidoDe(venta, estado: EstadoPedido.entregado);
      expect(TransicionesPedido.puedeAnular(pedido), isFalse);
    });

    test('anulada = cancelada que antes pasó por entregado', () {
      final hora = DateTime.utc(2026, 11, 5, 19);
      final anulada =
          pedidoDe(
            venta,
            estado: EstadoPedido.cancelado,
            origen: OrigenPedido.mostrador,
          ).copyWith(
            historial: [
              CambioEstado(estado: EstadoPedido.entregado, fecha: hora),
              CambioEstado(estado: EstadoPedido.cancelado, fecha: hora),
            ],
          );
      final cancelada = pedidoDe(venta, estado: EstadoPedido.cancelado)
          .copyWith(
            historial: [
              CambioEstado(estado: EstadoPedido.cancelado, fecha: hora),
            ],
          );

      expect(anulada.anulada, isTrue);
      expect(cancelada.anulada, isFalse);
      expect(TransicionesPedido.puedeAnular(anulada), isFalse);
    });
  });
}
