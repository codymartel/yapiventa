import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/opciones_caja_desde_negocio.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';

void main() {
  group('formas de pago del negocio', () {
    test('solo las activas, en su orden y con su nombre', () {
      final pagos = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['yape', 'efectivo'],
      });

      expect([for (final p in pagos) p.id], ['yape', 'efectivo']);
      expect([for (final p in pagos) p.etiqueta], ['Yape', 'Efectivo']);
      expect(pagos.first.descuento, DescuentoPago.ninguno);
    });

    test('un negocio sin Yape ni Plin no los muestra', () {
      final pagos = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['efectivo', 'transferencia'],
      });

      expect(
        [for (final p in pagos) p.etiqueta],
        ['Efectivo', 'Transferencia'],
      );
    });

    test('una forma de pago propia sale con el nombre que le puso', () {
      final pagos = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['tarjeta', ' Fiado '],
      });

      expect([for (final p in pagos) p.etiqueta], ['Tarjeta', 'Fiado']);
      expect([for (final p in pagos) p.id], ['tarjeta', 'fiado']);
    });

    test('descuento en porcentaje: 5 % → 500 centésimas, con su mínimo', () {
      final yape = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['yape'],
        'configPagos': {
          'yape': {
            'descuentoActivo': true,
            'tipoDescuento': 'porcentaje',
            'valorDescuento': 5.0,
            'montoMinimo': 20.0,
          },
        },
      }).single;

      expect(yape.descuento.tipo, TipoDescuentoPago.porcentaje);
      expect(yape.descuento.valor, 500);
      expect(yape.descuento.minimoCentavos, 2000);
    });

    test('descuento de monto fijo: S/ 1,50 → 150 céntimos', () {
      final plin = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['plin'],
        'configPagos': {
          'plin': {
            'descuentoActivo': true,
            'tipoDescuento': 'monto_fijo',
            'valorDescuento': 1.5,
          },
        },
      }).single;

      expect(plin.descuento.tipo, TipoDescuentoPago.montoFijo);
      expect(plin.descuento.valor, 150);
      expect(plin.descuento.minimoCentavos, 0);
    });

    test('redondea una sola vez: 4,35 → 435 (no 434)', () {
      final yape = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['yape'],
        'configPagos': {
          'yape': {
            'descuentoActivo': true,
            'tipoDescuento': 'monto_fijo',
            'valorDescuento': 4.35,
          },
        },
      }).single;

      expect(yape.descuento.valor, 435);
    });

    test('descuento apagado, en cero o de más de 100 % no rompe', () {
      DescuentoPago de(Map<String, dynamic> config) =>
          OpcionesCajaDesdeNegocio.pagos({
            'metodosPago': ['yape'],
            'configPagos': {'yape': config},
          }).single.descuento;

      expect(
        de({'descuentoActivo': false, 'valorDescuento': 5.0}),
        DescuentoPago.ninguno,
      );
      expect(
        de({'descuentoActivo': true, 'valorDescuento': 0}),
        DescuentoPago.ninguno,
      );
      expect(
        de({'descuentoActivo': true, 'valorDescuento': -3}),
        DescuentoPago.ninguno,
      );
      final enorme = de({
        'descuentoActivo': true,
        'tipoDescuento': 'porcentaje',
        'valorDescuento': 250,
      });
      expect(enorme.valor, 10000, reason: 'nunca más de 100 %');
    });

    test('datos raros o repetidos se ignoran', () {
      expect(OpcionesCajaDesdeNegocio.pagos({}), isEmpty);
      expect(OpcionesCajaDesdeNegocio.pagos({'metodosPago': 'yape'}), isEmpty);
      final pagos = OpcionesCajaDesdeNegocio.pagos({
        'metodosPago': ['yape', 7, '', 'YAPE', null],
        'configPagos': 'nada',
      });
      expect([for (final p in pagos) p.id], ['yape']);
    });
  });

  group('zonas de delivery del negocio', () {
    test('las zonas con su costo en céntimos', () {
      final zonas = OpcionesCajaDesdeNegocio.zonas({
        'delivery': true,
        'deliveryZonas': [
          {'zona': 'Centro', 'costo': 3.0},
          {'zona': ' Norte ', 'costo': '5,50'},
          {'zona': 'Gratis', 'costo': 0},
        ],
      });

      expect([for (final z in zonas) z.nombre], ['Centro', 'Norte', 'Gratis']);
      expect([for (final z in zonas) z.costoCentavos], [300, 550, 0]);
    });

    test('si el negocio no hace delivery no hay zonas', () {
      final zonas = OpcionesCajaDesdeNegocio.zonas({
        'delivery': false,
        'deliveryZonas': [
          {'zona': 'Centro', 'costo': 3.0},
        ],
      });

      expect(zonas, isEmpty);
    });

    test('zonas sin nombre, repetidas o raras se ignoran', () {
      final zonas = OpcionesCajaDesdeNegocio.zonas({
        'delivery': true,
        'deliveryZonas': [
          {'zona': '', 'costo': 3.0},
          {'zona': 'Centro', 'costo': -2},
          {'zona': 'centro', 'costo': 9},
          'Sur',
          {'costo': 4},
        ],
      });

      expect(zonas.single.nombre, 'Centro');
      expect(zonas.single.costoCentavos, 0, reason: 'un costo negativo es 0');
      expect(OpcionesCajaDesdeNegocio.zonas({'delivery': true}), isEmpty);
    });
  });
}
