import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/verificacion_total_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../helpers/pedidos_de_prueba.dart';

Producto? Function(String) catalogo(List<Producto> productos) {
  final porId = {for (final p in productos) p.id: p};
  return (id) => porId[id];
}

void main() {
  group('subtotalLinea', () {
    test('queso a S/ 24,00 el kg: 350 g son S/ 8,40', () {
      expect(CalculoPedido.subtotalLinea(lineaQueso(350)), 840);
    });

    test('redondea hacia abajo, a favor del cliente: 333 g son 799', () {
      // 2400 × 333 ÷ 1000 = 799,2 → 799.
      expect(CalculoPedido.subtotalLinea(lineaQueso(333)), 799);
    });

    test('se cuenta: precio × cantidad', () {
      expect(
        CalculoPedido.subtotalLinea(
          lineaSimple(cantidad: 2, precioCentavos: 350),
        ),
        700,
      );
    });

    test('los extras suman al precio y se multiplican por la cantidad', () {
      final linea = lineaSimple(
        cantidad: 2,
        precioCentavos: 1200,
        extras: const [ExtraLinea(nombre: 'Papas', precioCentavos: 600)],
      );

      expect(CalculoPedido.subtotalLinea(linea), 3600);
    });

    test('una referencia en 0 no divide por cero', () {
      final linea = LineaPedido(
        productoId: 'queso',
        nombre: 'Queso',
        cantidad: 100,
        precioCentavos: 5,
        porMedida: true,
        cantidadReferencia: 0,
      );

      expect(CalculoPedido.subtotalLinea(linea), 500);
    });
  });

  group('total', () {
    test('subtotal + delivery − descuento', () {
      expect(
        CalculoPedido.total(
          subtotalCentavos: 1540,
          deliveryCentavos: 300,
          descuentoCentavos: 100,
        ),
        1740,
      );
    });

    test('un descuento mayor que la cuenta deja 0, no negativo', () {
      expect(
        CalculoPedido.total(subtotalCentavos: 500, descuentoCentavos: 900),
        0,
      );
    });
  });

  group('verificar con los precios de hoy', () {
    final lineas = [
      lineaQueso(350),
      lineaSimple(nombre: 'Gaseosa Inca', cantidad: 2, precioCentavos: 350),
    ];
    final pedido = pedidoDe(lineas, deliveryCentavos: 300, totalCentavos: 1840);

    test('si los precios no cambiaron, el total coincide', () {
      final v = CalculoPedido.verificar(
        pedido,
        catalogo([quesoPorMedida(), productoSimple(precioCentavos: 350)]),
      );

      expect(v.difiere, isFalse);
      expect(v.totalActualCentavos, 1840);
      expect(v.lineasCambiadas, isEmpty);
    });

    test('si subió la gaseosa, avisa qué línea y el total nuevo', () {
      final v = CalculoPedido.verificar(
        pedido,
        catalogo([quesoPorMedida(), productoSimple(precioCentavos: 400)]),
      );

      expect(v.difiere, isTrue);
      expect(v.totalActualCentavos, 1940); // 840 + 800 + 300
      expect(v.lineasCambiadas, ['Gaseosa Inca']);
    });

    test('un producto borrado conserva su precio guardado y se avisa', () {
      final v = CalculoPedido.verificar(pedido, catalogo([quesoPorMedida()]));

      expect(v.sinProducto, ['Gaseosa Inca']);
      expect(v.totalActualCentavos, 1840);
    });

    test('con modelos usa el precio de la fila de hoy', () {
      final polo = pedidoDe([
        lineaSimple(
          productoId: 'polo',
          nombre: 'Polo básico',
          precioCentavos: 5000,
          modeloId: 'luna',
          filaId: 'l',
        ),
      ], totalCentavos: 5000);

      final v = CalculoPedido.verificar(polo, catalogo([poloConModelos()]));

      expect(v.totalActualCentavos, 5500); // la fila L hoy vale S/ 55,00
      expect(v.lineasCambiadas, ['Polo básico']);
    });
  });
}
