import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';

import '../../helpers/pedidos_de_prueba.dart';

void main() {
  // Bodega: 350 g de queso (S/ 24,00 el kg) + 2 gaseosas a S/ 4,50.
  final bodega = [
    lineaQueso(350),
    lineaSimple(cantidad: 2, precioCentavos: 450),
  ];

  group('la cuenta', () {
    test('350 g a S/ 24,00 el kg = 840 y 2 × 450 = 900: subtotal 1 740', () {
      final v = CalculoVentaMostrador.calcular(lineas: bodega);

      expect(v.lineas.first.subtotalCentavos, 840);
      expect(v.lineas.last.subtotalCentavos, 900);
      expect(v.subtotalCentavos, 1740);
      expect(v.descuentoCentavos, 0);
      expect(v.totalCentavos, 1740);
    });

    test('por medida redondea hacia abajo una sola vez: 333 g = 799', () {
      final v = CalculoVentaMostrador.calcular(lineas: [lineaQueso(333)]);

      expect(v.subtotalCentavos, 799);
    });

    test(
      'los extras suman al precio de cada unidad: (350 + 100) × 2 = 900',
      () {
        final v = CalculoVentaMostrador.calcular(
          lineas: [
            lineaSimple(
              cantidad: 2,
              precioCentavos: 350,
              extras: const [
                ExtraLinea(nombre: 'Ají extra', precioCentavos: 100),
              ],
            ),
          ],
        );

        expect(v.subtotalCentavos, 900);
      },
    );

    test('una línea con cantidad 0 no cuenta', () {
      final v = CalculoVentaMostrador.calcular(
        lineas: [lineaSimple(cantidad: 0), lineaSimple(cantidad: 1)],
      );

      expect(v.lineas, hasLength(1));
      expect(v.subtotalCentavos, 350);
    });

    test('el delivery se suma al total y un costo negativo vale 0', () {
      final con = CalculoVentaMostrador.calcular(
        lineas: bodega,
        deliveryCentavos: 300,
      );
      final negativo = CalculoVentaMostrador.calcular(
        lineas: bodega,
        deliveryCentavos: -50,
      );

      expect(con.totalCentavos, 2040);
      expect(negativo.deliveryCentavos, 0);
      expect(negativo.totalCentavos, 1740);
    });
  });

  group('el descuento por forma de pago', () {
    const yape5 = DescuentoPago.porcentaje(centesimas: 500);

    test('5 % de 1 740 = 87: total 1 653', () {
      final v = CalculoVentaMostrador.calcular(
        lineas: bodega,
        descuento: yape5,
      );

      expect(v.descuentoCentavos, 87);
      expect(v.totalCentavos, 1653);
    });

    test('redondea a favor del cliente (hacia arriba): 5 % de 1 743 = 88', () {
      expect(CalculoVentaMostrador.descuentoDe(1743, yape5), 88);
    });

    test('una cuenta exacta no sube: 5 % de 1 740 sigue en 87', () {
      expect(CalculoVentaMostrador.descuentoDe(1740, yape5), 87);
    });

    test('un porcentaje con decimales: 7,5 % de 1 000 = 75', () {
      expect(
        CalculoVentaMostrador.descuentoDe(
          1000,
          const DescuentoPago.porcentaje(centesimas: 750),
        ),
        75,
      );
    });

    test('no se aplica si el subtotal no llega al mínimo', () {
      const desdeVeinte = DescuentoPago.porcentaje(
        centesimas: 500,
        minimoCentavos: 2000,
      );

      expect(CalculoVentaMostrador.descuentoDe(1740, desdeVeinte), 0);
      expect(CalculoVentaMostrador.descuentoDe(2000, desdeVeinte), 100);
    });

    test('monto fijo: S/ 2,00 y nunca más que el subtotal', () {
      const dosSoles = DescuentoPago.montoFijo(centavos: 200);

      expect(CalculoVentaMostrador.descuentoDe(1740, dosSoles), 200);
      expect(CalculoVentaMostrador.descuentoDe(150, dosSoles), 150);
    });

    test('un descuento mayor al 100 % se queda en el 100 %', () {
      final v = CalculoVentaMostrador.calcular(
        lineas: bodega,
        descuento: const DescuentoPago.porcentaje(centesimas: 25000),
      );

      expect(v.descuentoCentavos, 1740);
      expect(v.totalCentavos, 0);
    });

    test('el delivery no tiene descuento: 5 % sobre el subtotal', () {
      final v = CalculoVentaMostrador.calcular(
        lineas: bodega,
        deliveryCentavos: 300,
        descuento: yape5,
      );

      expect(v.descuentoCentavos, 87);
      expect(v.totalCentavos, 1740 + 300 - 87);
    });

    test('sin descuento, con valor 0 o sin subtotal no descuenta', () {
      expect(CalculoVentaMostrador.descuentoDe(1740, DescuentoPago.ninguno), 0);
      expect(
        CalculoVentaMostrador.descuentoDe(
          1740,
          const DescuentoPago.porcentaje(centesimas: 0),
        ),
        0,
      );
      expect(CalculoVentaMostrador.descuentoDe(0, yape5), 0);
    });
  });
}
