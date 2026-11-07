import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_informe_ventas.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';
import 'package:mobile/features/pedidos/domain/models/informe_ventas.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';

ResumenVentasDia _dia(
  String dia,
  int ventas,
  int entregados, {
  ContadoresDia contadores = ContadoresDia.vacio,
}) {
  return ResumenVentasDia(
    dia: dia,
    ventasCentavos: ventas,
    entregados: entregados,
    contadores: contadores,
  );
}

InformeVentas _armar(List<ResumenVentasDia> dias) =>
    CalculoInformeVentas.armar('2026-11-01', '2026-11-07', dias);

void main() {
  test('sin resúmenes: informe vacío, sin ticket ni mejor día', () {
    final i = _armar(const []);

    expect(i.sinMovimientos, isTrue);
    expect(i.ventasCentavos, 0);
    expect(i.ticketCentavos, isNull);
    expect(i.mejorDia, isNull);
    expect(i.diaMasFlojo, isNull);
  });

  test('suma ventas y entregados; el ticket se redondea hacia abajo', () {
    final i = _armar([
      _dia('2026-11-01', 1000, 1),
      _dia('2026-11-02', 1001, 2),
    ]);

    expect(i.ventasCentavos, 2001);
    expect(i.entregados, 3);
    expect(i.ticketCentavos, 667); // 2001 ÷ 3 = 667
    expect(i.diasConVentas, 2);
  });

  test('mejor día y día más flojo (solo entre días con ventas)', () {
    final i = _armar([
      _dia('2026-11-03', 5000, 3),
      _dia('2026-11-01', 800, 1),
      _dia('2026-11-02', 0, 0), // un día sin ventas no cuenta como flojo
      _dia('2026-11-04', 2000, 2),
    ]);

    expect(i.mejorDia!.dia, '2026-11-03');
    expect(i.diaMasFlojo!.dia, '2026-11-01');
    expect(i.diasConVentas, 3);
  });

  test('con un solo día con ventas no hay «más flojo»', () {
    final i = _armar([_dia('2026-11-01', 800, 1)]);

    expect(i.mejorDia!.dia, '2026-11-01');
    expect(i.diaMasFlojo, isNull);
  });

  test('si todos los días venden igual no hay «más flojo»', () {
    final i = _armar([_dia('2026-11-01', 800, 1), _dia('2026-11-02', 800, 1)]);

    expect(i.mejorDia!.dia, '2026-11-01', reason: 'empate: el primero');
    expect(i.diaMasFlojo, isNull);
  });

  test('suma los contadores de varios días', () {
    final i = _armar([
      _dia(
        '2026-11-01',
        1740,
        1,
        contadores: const ContadoresDia(
          mostradorCentavos: 1740,
          mostrador: 1,
          porPago: {'efectivo': 1740},
          porEntrega: {'local': 1740},
          porHora: {'14': 1740},
        ),
      ),
      _dia(
        '2026-11-02',
        2000,
        2,
        contadores: const ContadoresDia(
          mostradorCentavos: 450,
          mostrador: 1,
          anuladas: 1,
          anuladasCentavos: 900,
          porPago: {'efectivo': 450, 'yape': 1550},
          porEntrega: {'local': 450, 'delivery': 1550},
          porHora: {'14': 450, '18': 1550},
        ),
      ),
    ]);

    expect(i.porPago, {'efectivo': 2190, 'yape': 1550});
    expect(i.porEntrega, {'local': 2190, 'delivery': 1550});
    expect(i.porHora, {'14': 2190, '18': 1550});
    expect(i.mostradorCentavos, 2190);
    expect(i.mostrador, 2);
    expect(i.tiendaCentavos, 3740 - 2190);
    expect(i.anuladas, 1);
    expect(i.anuladasCentavos, 900);
  });

  group('rankings', () {
    ItemContador item(String n, int c, int m) =>
        ItemContador(nombre: n, cantidad: c, centavos: m);

    test('juntan el mismo producto de varios días y ordenan por dinero', () {
      final i = _armar([
        _dia(
          '2026-11-01',
          0,
          0,
          contadores: ContadoresDia(
            porProducto: {
              'queso': item('Queso', 350, 840),
              'gaseosa': item('Gaseosa', 2, 900),
            },
          ),
        ),
        _dia(
          '2026-11-02',
          0,
          0,
          contadores: ContadoresDia(
            porProducto: {'queso': item('Queso', 500, 1200)},
            porCombo: {'c1': item('Combo', 1, 1000)},
          ),
        ),
      ]);

      expect(i.productos.map((p) => p.clave), ['queso', 'gaseosa']);
      expect(i.productos.first.cantidad, 850);
      expect(i.productos.first.centavos, 2040);
      expect(i.combos.single.nombre, 'Combo');
      expect(i.variantes, isEmpty);
    });

    test('empate en dinero: más cantidad primero, luego por nombre', () {
      final i = _armar([
        _dia(
          '2026-11-01',
          0,
          0,
          contadores: ContadoresDia(
            porProducto: {
              'b': item('Beta', 1, 500),
              'a': item('Alfa', 1, 500),
              'c': item('Cero', 9, 500),
            },
          ),
        ),
      ]);

      expect(i.productos.map((p) => p.nombre), ['Cero', 'Alfa', 'Beta']);
    });

    test('traen como máximo 10 puestos', () {
      final muchos = {
        for (var n = 0; n < 15; n++) 'p$n': item('P$n', 1, 100 + n),
      };
      final i = _armar([
        _dia(
          '2026-11-01',
          0,
          0,
          contadores: ContadoresDia(porProducto: muchos),
        ),
      ]);

      expect(i.productos, hasLength(CalculoInformeVentas.maximoRanking));
      expect(i.productos.first.clave, 'p14');
    });
  });

  group('variación contra el periodo anterior', () {
    InformeVentas informe(int ventas, int entregados) => InformeVentas(
      desde: 'a',
      hasta: 'b',
      ventasCentavos: ventas,
      entregados: entregados,
    );

    test('sube y baja con porcentaje entero (hacia cero)', () {
      final sube = Variacion.entre(1500, 1000);
      final baja = Variacion.entre(667, 1000);

      expect([sube.diferencia, sube.porcentaje], [500, 50]);
      expect([baja.diferencia, baja.porcentaje], [-333, -33]);
    });

    test('si el anterior era 0 no hay porcentaje', () {
      final v = Variacion.entre(500, 0);

      expect(v.diferencia, 500);
      expect(v.porcentaje, isNull);
    });

    test('el comparado calcula ventas, entregados y ticket', () {
      final c = InformeComparado(
        actual: informe(3000, 3), // ticket 1000
        anterior: informe(2000, 4), // ticket 500
      );

      expect(c.ventas!.diferencia, 1000);
      expect(c.entregados!.diferencia, -1);
      expect(c.ticket!.porcentaje, 100);
    });

    test('sin comparar, o sin entregas en un periodo, no hay variación', () {
      expect(InformeComparado(actual: informe(1, 1)).ventas, isNull);
      final sinEntregas = InformeComparado(
        actual: informe(3000, 3),
        anterior: informe(0, 0),
      );
      expect(sinEntregas.ticket, isNull);
      expect(sinEntregas.ventas!.porcentaje, isNull);
    });
  });
}
