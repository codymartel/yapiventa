import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/contadores_venta.dart';
import 'package:mobile/features/pedidos/data/contadores_dia_mapper.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';

void main() {
  const completo = ContadoresDia(
    mostradorCentavos: 1740,
    mostrador: 1,
    anuladas: 2,
    anuladasCentavos: 900,
    porPago: {'efectivo': 1740, 'yape': 1200},
    porEntrega: {'local': 1740},
    porHora: {'14': 2940},
    porProducto: {
      'queso': ItemContador(
        nombre: 'Queso andino',
        cantidad: 350,
        centavos: 840,
      ),
    },
    porVariante: {
      'polo|azul|m': ItemContador(
        nombre: 'Polo básico · Azul · M',
        cantidad: 2,
        centavos: 7000,
      ),
    },
    porCombo: {
      'combo': ItemContador(
        nombre: 'Combo familiar',
        cantidad: 3,
        centavos: 11400,
      ),
    },
  );

  group('escribir y leer', () {
    test('lo que se escribe se lee igual (ida y vuelta)', () {
      final leido = ContadoresDiaMapper.desdeFirestore(
        ContadoresDiaMapper.aCampos(completo),
      );

      expect(leido.mostradorCentavos, 1740);
      expect(leido.mostrador, 1);
      expect(leido.anuladas, 2);
      expect(leido.anuladasCentavos, 900);
      expect(leido.porPago, {'efectivo': 1740, 'yape': 1200});
      expect(leido.porEntrega, {'local': 1740});
      expect(leido.porHora, {'14': 2940});
      expect(leido.porProducto['queso']!.nombre, 'Queso andino');
      expect(leido.porProducto['queso']!.cantidad, 350);
      expect(leido.porProducto['queso']!.centavos, 840);
      expect(leido.porVariante['polo|azul|m']!.centavos, 7000);
      expect(leido.porCombo['combo']!.cantidad, 3);
    });

    test('escribe exactamente los campos de camposContadores', () {
      final campos = ContadoresDiaMapper.aCampos(completo);

      expect(campos.keys.toSet(), ContadoresDiaMapper.camposContadores.toSet());
    });

    test(
      'un día vacío escribe ceros y mapas vacíos (lista para reemplazar)',
      () {
        final campos = ContadoresDiaMapper.aCampos(ContadoresDia.vacio);

        expect(campos['mostrador'], 0);
        expect(campos['porPago'], isEmpty);
        expect(campos['porProducto'], isEmpty);
      },
    );

    test('un producto con nombre y números se escribe como mapa simple', () {
      final campos = ContadoresDiaMapper.aCampos(completo);

      expect((campos['porProducto'] as Map)['queso'], {
        'nombre': 'Queso andino',
        'cantidad': 350,
        'centavos': 840,
      });
    });
  });

  group('lectura defensiva', () {
    test('un resumen viejo, sin contadores, es un día sin movimientos', () {
      final c = ContadoresDiaMapper.desdeFirestore({'ventasCentavos': 500});

      expect(c.mostrador, 0);
      expect(c.porPago, isEmpty);
      expect(c.porProducto, isEmpty);
    });

    test('números negativos o de otro tipo cuentan como 0', () {
      final c = ContadoresDiaMapper.desdeFirestore({
        'mostrador': -3,
        'anuladas': 'dos',
        'porPago': {'efectivo': -50, 'yape': 'mucho', 'plin': 300},
      });

      expect(c.mostrador, 0);
      expect(c.anuladas, 0);
      expect(c.porPago, {'plin': 300});
    });

    test('un campo que no es un mapa se ignora', () {
      final c = ContadoresDiaMapper.desdeFirestore({
        'porPago': 'raro',
        'porProducto': [1, 2, 3],
        'porHora': 42,
      });

      expect(c.porPago, isEmpty);
      expect(c.porProducto, isEmpty);
      expect(c.porHora, isEmpty);
    });

    test('una entrada de producto rara o vacía se salta', () {
      final c = ContadoresDiaMapper.desdeFirestore({
        'porProducto': {
          'a': 'no es un mapa',
          'b': {'nombre': 'Vacío', 'cantidad': 0, 'centavos': 0},
          'c': {'nombre': 'Bien', 'cantidad': 2, 'centavos': 900},
        },
      });

      expect(c.porProducto.keys, ['c']);
      expect(c.porProducto['c']!.nombre, 'Bien');
    });

    test('lee como máximo el tope del día más «Otros»', () {
      final muchos = {
        for (var i = 0; i < 400; i++)
          'p$i': {'nombre': 'P$i', 'cantidad': 1, 'centavos': 100},
      };

      final c = ContadoresDiaMapper.desdeFirestore({'porProducto': muchos});

      expect(c.porProducto, hasLength(ContadoresVenta.maximoPorLista + 1));
    });
  });

  group('dentro del resumen del día', () {
    test('el resumen lee sus contadores', () {
      final r = ResumenVentasDiaMapper.desdeFirestore('2026-11-05', {
        'ventasCentavos': 1740,
        'entregados': 1,
        ...ContadoresDiaMapper.aCampos(completo),
      });

      expect(r.ventasCentavos, 1740);
      expect(r.contadores.porPago['yape'], 1200);
      expect(r.contadores.porCombo['combo']!.nombre, 'Combo familiar');
    });

    test('un día que no existe tiene contadores vacíos', () {
      final r = ResumenVentasDiaMapper.desdeFirestore('2026-11-05', null);

      expect(r.contadores.mostrador, 0);
      expect(r.contadores.porProducto, isEmpty);
    });

    test('un resumen anterior a los contadores sigue leyéndose igual', () {
      final r = ResumenVentasDiaMapper.desdeFirestore('2026-11-05', {
        'ventasCentavos': 1200,
        'entregados': 1,
        'confirmados': 2,
        'sumaMinutosConfirmar': 14,
      });

      expect(r.ventasCentavos, 1200);
      expect(r.minutosPromedioConfirmar, 7);
      expect(r.contadores.porPago, isEmpty);
      expect(r.contadores.porCobrarCentavos, 0);
    });

    test('lo por cobrar va y vuelve; un negativo se lee como 0', () {
      const c = ContadoresDia(porCobrarCentavos: 4000, porCobrar: 1);
      final campos = ContadoresDiaMapper.aCampos(c);

      expect(campos['porCobrarCentavos'], 4000);
      expect(campos['porCobrar'], 1);
      expect(ContadoresDiaMapper.camposContadores, contains('porCobrar'));
      final leido = ContadoresDiaMapper.desdeFirestore(campos);
      expect(leido.porCobrarCentavos, 4000);
      expect(leido.porCobrar, 1);
      expect(
        ContadoresDiaMapper.desdeFirestore({
          'porCobrarCentavos': -5,
        }).porCobrarCentavos,
        0,
      );
    });
  });
}
