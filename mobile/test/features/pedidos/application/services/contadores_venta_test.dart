import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/contadores_venta.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';

// 19:32 UTC = 14:32 en Lima (UTC−5).
final _tarde = DateTime.utc(2026, 11, 5, 19, 32);

Pedido _venta({
  List<LineaPedido>? lineas,
  OrigenPedido origen = OrigenPedido.mostrador,
  TipoEntrega entrega = TipoEntrega.recojo,
  bool enLocal = true,
  String pago = 'efectivo',
  int total = 1740,
}) {
  return Pedido(
    id: 'p1',
    origen: origen,
    tipoEntrega: entrega,
    enLocal: enLocal,
    estado: EstadoPedido.entregado,
    metodoPago: pago,
    totalCentavos: total,
    lineas:
        lineas ??
        const [
          LineaPedido(
            productoId: 'queso',
            nombre: 'Queso andino',
            cantidad: 350,
            precioCentavos: 2400,
            porMedida: true,
            cantidadReferencia: 1000,
            subtotalCentavos: 840,
          ),
          LineaPedido(
            productoId: 'gaseosa',
            nombre: 'Gaseosa Inca',
            cantidad: 2,
            precioCentavos: 450,
            subtotalCentavos: 900,
          ),
        ],
  );
}

void main() {
  group('lo que aporta una venta', () {
    test('de mostrador en el local: por pago, entrega, hora y producto', () {
      final a = ContadoresVenta.aporteDe(_venta(), _tarde);

      expect(a.totalCentavos, 1740);
      expect(a.esMostrador, isTrue);
      expect(a.pago, 'efectivo');
      expect(a.entrega, 'local');
      expect(a.hora, '14');
      expect(a.productos['queso']!.cantidad, 350);
      expect(a.productos['queso']!.centavos, 840);
      expect(a.productos['gaseosa']!.nombre, 'Gaseosa Inca');
      expect(a.variantes, isEmpty);
      expect(a.combos, isEmpty);
    });

    test('un pedido de la tienda no es de mostrador', () {
      final a = ContadoresVenta.aporteDe(
        _venta(origen: OrigenPedido.tienda, enLocal: false),
        _tarde,
      );

      expect(a.esMostrador, isFalse);
      expect(a.entrega, 'recojo');
    });

    test('delivery sale como delivery aunque «enLocal» venga en true', () {
      final a = ContadoresVenta.aporteDe(
        _venta(entrega: TipoEntrega.delivery),
        _tarde,
      );

      expect(a.entrega, 'delivery');
    });

    test('una línea con modelo y fila cuenta también como variable', () {
      final a = ContadoresVenta.aporteDe(
        _venta(
          lineas: const [
            LineaPedido(
              productoId: 'polo',
              modeloId: 'azul',
              filaId: 'm',
              nombre: 'Polo básico',
              etiqueta: 'Azul · M',
              cantidad: 2,
              precioCentavos: 3500,
            ),
          ],
        ),
        _tarde,
      );

      expect(a.productos['polo']!.cantidad, 2);
      expect(a.variantes['polo|azul|m']!.nombre, 'Polo básico · Azul · M');
      expect(a.variantes['polo|azul|m']!.centavos, 7000);
    });

    test('un combo va a los combos y no a los productos', () {
      final a = ContadoresVenta.aporteDe(
        _venta(
          lineas: const [
            LineaPedido(
              productoId: 'combo',
              nombre: 'Combo familiar',
              cantidad: 3,
              precioCentavos: 3800,
              esCombo: true,
            ),
          ],
        ),
        _tarde,
      );

      expect(a.combos['combo']!.cantidad, 3);
      expect(a.combos['combo']!.centavos, 11400);
      expect(a.productos, isEmpty);
    });

    test('la misma línea dos veces junta cantidades y montos', () {
      final a = ContadoresVenta.aporteDe(
        _venta(
          lineas: const [
            LineaPedido(
              productoId: 'gaseosa',
              nombre: 'Gaseosa Inca',
              cantidad: 1,
              precioCentavos: 450,
            ),
            LineaPedido(
              productoId: 'gaseosa',
              nombre: 'Gaseosa Inca',
              cantidad: 2,
              precioCentavos: 450,
            ),
          ],
        ),
        _tarde,
      );

      expect(a.productos['gaseosa']!.cantidad, 3);
      expect(a.productos['gaseosa']!.centavos, 1350);
    });

    test(
      'la forma de pago se normaliza: «Yape » → yape, vacía → sin_indicar',
      () {
        expect(ContadoresVenta.clavePago(' Yape '), 'yape');
        expect(ContadoresVenta.clavePago(''), 'sin_indicar');
        expect(ContadoresVenta.clavePago('Tarjeta/Visa!'), 'otro');
      },
    );

    test('la hora de Lima: 04:59 UTC es 23 del día anterior', () {
      expect(ContadoresVenta.claveHora(DateTime.utc(2026, 11, 6, 4, 59)), '23');
    });
  });

  group('sumar', () {
    test('sobre un día vacío deja la venta tal cual', () {
      final d = ContadoresVenta.sumar(
        ContadoresDia.vacio,
        ContadoresVenta.aporteDe(_venta(), _tarde),
      );

      expect(d.mostrador, 1);
      expect(d.mostradorCentavos, 1740);
      expect(d.porPago, {'efectivo': 1740});
      expect(d.porEntrega, {'local': 1740});
      expect(d.porHora, {'14': 1740});
      expect(d.porProducto['queso']!.centavos, 840);
    });

    test('dos ventas acumulan, y una de la tienda no suma a mostrador', () {
      final mostrador = ContadoresVenta.aporteDe(_venta(), _tarde);
      final tienda = ContadoresVenta.aporteDe(
        _venta(
          origen: OrigenPedido.tienda,
          enLocal: false,
          pago: 'yape',
          total: 1200,
        ),
        _tarde,
      );

      final d = ContadoresVenta.sumar(
        ContadoresVenta.sumar(ContadoresDia.vacio, mostrador),
        tienda,
      );

      expect(d.mostrador, 1);
      expect(d.mostradorCentavos, 1740);
      expect(d.porPago, {'efectivo': 1740, 'yape': 1200});
      expect(d.porHora, {'14': 2940});
      expect(d.porProducto['gaseosa']!.cantidad, 4);
    });

    test('no cambia el resumen que recibe (copia nueva)', () {
      const antes = ContadoresDia(porPago: {'efectivo': 100});

      ContadoresVenta.sumar(antes, ContadoresVenta.aporteDe(_venta(), _tarde));

      expect(antes.porPago, {'efectivo': 100});
    });
  });

  group('restar (anular)', () {
    test('deja el día como estaba y cuenta la anulación', () {
      final aporte = ContadoresVenta.aporteDe(_venta(), _tarde);
      final sumado = ContadoresVenta.sumar(ContadoresDia.vacio, aporte);

      final d = ContadoresVenta.restar(sumado, aporte);

      expect(d.mostrador, 0);
      expect(d.mostradorCentavos, 0);
      expect(d.porPago, isEmpty);
      expect(d.porEntrega, isEmpty);
      expect(d.porHora, isEmpty);
      expect(d.porProducto, isEmpty);
      expect(d.anuladas, 1);
      expect(d.anuladasCentavos, 1740);
    });

    test('resta solo lo anulado y deja el resto', () {
      final primera = ContadoresVenta.aporteDe(_venta(), _tarde);
      final segunda = ContadoresVenta.aporteDe(_venta(total: 500), _tarde);
      final sumado = ContadoresVenta.sumar(
        ContadoresVenta.sumar(ContadoresDia.vacio, primera),
        segunda,
      );

      final d = ContadoresVenta.restar(sumado, segunda);

      expect(d.porPago, {'efectivo': 1740});
      expect(d.porProducto['gaseosa']!.cantidad, 2);
      expect(d.mostrador, 1);
    });

    test(
      'nunca deja números negativos aunque el día no tenga lo que se resta',
      () {
        final aporte = ContadoresVenta.aporteDe(_venta(), _tarde);

        final d = ContadoresVenta.restar(const ContadoresDia(), aporte);

        expect(d.mostrador, 0);
        expect(d.mostradorCentavos, 0);
        expect(d.porPago, isEmpty);
        expect(d.anuladas, 1);
      },
    );
  });

  group('el tope de productos distintos por día', () {
    AporteVenta aporteConProducto(String id) => AporteVenta(
      totalCentavos: 100,
      productos: {id: ItemContador(nombre: id, cantidad: 1, centavos: 100)},
    );

    test('pasado el tope, los nuevos se juntan en «otros»', () {
      var d = ContadoresDia.vacio;
      for (var i = 0; i < ContadoresVenta.maximoPorLista; i++) {
        d = ContadoresVenta.sumar(d, aporteConProducto('p$i'));
      }
      expect(d.porProducto, hasLength(250));

      d = ContadoresVenta.sumar(d, aporteConProducto('nuevo1'));
      d = ContadoresVenta.sumar(d, aporteConProducto('nuevo2'));

      expect(d.porProducto, hasLength(251));
      expect(d.porProducto['otros']!.cantidad, 2);
      expect(d.porProducto['otros']!.nombre, 'Otros');
      expect(d.porProducto.containsKey('nuevo1'), isFalse);
    });

    test('un producto que ya estaba sigue sumando aunque se pasó el tope', () {
      var d = ContadoresDia.vacio;
      for (var i = 0; i < ContadoresVenta.maximoPorLista; i++) {
        d = ContadoresVenta.sumar(d, aporteConProducto('p$i'));
      }

      d = ContadoresVenta.sumar(d, aporteConProducto('p0'));

      expect(d.porProducto['p0']!.cantidad, 2);
      expect(d.porProducto.containsKey('otros'), isFalse);
    });

    test('anular algo que quedó en «otros» lo resta de ahí', () {
      var d = ContadoresDia.vacio;
      for (var i = 0; i < ContadoresVenta.maximoPorLista; i++) {
        d = ContadoresVenta.sumar(d, aporteConProducto('p$i'));
      }
      d = ContadoresVenta.sumar(d, aporteConProducto('nuevo1'));

      d = ContadoresVenta.restar(d, aporteConProducto('nuevo1'));

      expect(d.porProducto.containsKey('otros'), isFalse);
      expect(d.porProducto, hasLength(250));
    });
  });
}
