import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/filtros_rapidos_caja.dart';
import 'package:mobile/features/caja/application/services/sugerencias_caja.dart';
import 'package:mobile/features/caja/application/services/textos_producto_caja.dart';
import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

void main() {
  group('FiltrosRapidosCaja', () {
    test(
      'Bodega: Frecuentes y por tipo (Simples, Por peso, Variables, Combos)',
      () {
        final f = FiltrosRapidosCaja.para(rubro: 'Bodega');

        expect(f.map((e) => e.etiqueta), [
          'Frecuentes',
          'Simples',
          'Por peso',
          'Variables',
          'Combos',
        ]);
        expect(f[2].tipo, CamposCatalogoProducto.tipoMedida);
        expect(f.first.esFrecuentes, isTrue);
      },
    );

    test('el rubro no distingue mayúsculas ni espacios', () {
      expect(FiltrosRapidosCaja.para(rubro: ' bodega ').length, 5);
    });

    test('otros rubros: sus categorías propias y Combos al final', () {
      final f = FiltrosRapidosCaja.para(
        rubro: 'Restaurante',
        categorias: ['Platos', 'Bebidas', 'Postres'],
      );

      expect(f.map((e) => e.etiqueta), [
        'Frecuentes',
        'Platos',
        'Bebidas',
        'Postres',
        'Combos',
      ]);
      expect(f[1].categoria, 'Platos');
      expect(f.last.tipo, CamposCatalogoProducto.tipoCombo);
    });

    test('quita repetidas y vacías, y deja hasta 5 categorías en la fila', () {
      final f = FiltrosRapidosCaja.para(
        rubro: 'Ropa',
        categorias: ['A', 'A', ' ', 'B', 'C', 'D', 'E', 'F', 'G'],
      );

      expect(f.map((e) => e.etiqueta), [
        'Frecuentes',
        'A',
        'B',
        'C',
        'D',
        'E',
        'Combos',
      ]);
      expect(
        FiltrosRapidosCaja.restantes([
          'A',
          'A',
          ' ',
          'B',
          'C',
          'D',
          'E',
          'F',
          'G',
        ]),
        ['F', 'G'],
      );
    });

    test('sin categorías: solo Frecuentes y Combos', () {
      final f = FiltrosRapidosCaja.para(rubro: 'Belleza');
      expect(f.map((e) => e.etiqueta), ['Frecuentes', 'Combos']);
    });

    test('qué chip está activo', () {
      final f = FiltrosRapidosCaja.para(rubro: 'Bodega');
      final porPeso = f[2];

      expect(f.first.estaActivo(null, null), isTrue);
      expect(f.first.estaActivo('medida', null), isFalse);
      expect(porPeso.estaActivo('medida', null), isTrue);
      expect(porPeso.estaActivo(null, null), isFalse);
      final cat = FiltrosRapidosCaja.para(
        rubro: 'Ropa',
        categorias: ['Polos'],
      )[1];
      expect(cat.estaActivo(null, 'Polos'), isTrue);
      expect(cat.estaActivo('combo', 'Polos'), isFalse);
    });

    test('cuántos avanzados hay: stock y una categoría fuera de la fila', () {
      final rapidos = FiltrosRapidosCaja.para(
        rubro: 'Ropa',
        categorias: ['Polos'],
      );

      expect(FiltrosRapidosCaja.avanzadosActivos(rapidos: rapidos), 0);
      expect(
        FiltrosRapidosCaja.avanzadosActivos(
          rapidos: rapidos,
          soloConStock: true,
        ),
        1,
      );
      expect(
        FiltrosRapidosCaja.avanzadosActivos(
          rapidos: rapidos,
          categoria: 'Polos',
        ),
        0,
        reason: 'es de la fila rápida',
      );
      expect(
        FiltrosRapidosCaja.avanzadosActivos(
          rapidos: rapidos,
          categoria: 'Otra',
          soloConStock: true,
        ),
        2,
      );
    });
  });

  group('SugerenciasCaja', () {
    final cargados = [
      productoSimple(id: 'a', nombre: 'Gaseosa Inca'),
      productoSimple(id: 'b', nombre: 'Agua sin gas'),
      productoSimple(id: 'c', nombre: 'Piña dulce'),
      productoSimple(id: 'd', nombre: 'Arroz costeño'),
    ];

    test('coincide con el inicio del nombre o de una palabra', () {
      expect(SugerenciasCaja.de(cargados, 'gase').map((p) => p.id), ['a']);
      expect(SugerenciasCaja.de(cargados, 'ga').map((p) => p.id), ['a', 'b']);
      expect(SugerenciasCaja.de(cargados, 'gas').map((p) => p.id), ['a', 'b']);
      expect(SugerenciasCaja.de(cargados, 'inca').map((p) => p.id), ['a']);
    });

    test('ignora mayúsculas y tildes (la ñ cuenta como n)', () {
      expect(SugerenciasCaja.de(cargados, 'PIÑ').map((p) => p.id), ['c']);
      expect(SugerenciasCaja.de(cargados, 'costeno').map((p) => p.id), ['d']);
    });

    test('no sugiere por el medio de una palabra', () {
      expect(SugerenciasCaja.de(cargados, 'seosa'), isEmpty);
    });

    test('con menos de 2 letras no sugiere', () {
      expect(SugerenciasCaja.de(cargados, 'g'), isEmpty);
      expect(SugerenciasCaja.de(cargados, ' '), isEmpty);
    });

    test('hasta 5 sugerencias', () {
      final muchos = [
        for (var i = 0; i < 12; i++)
          productoSimple(id: 'p$i', nombre: 'Pan $i'),
      ];
      expect(
        SugerenciasCaja.de(muchos, 'pa'),
        hasLength(SugerenciasCaja.maximo),
      );
    });
  });

  group('TextosProductoCaja', () {
    test('el precio lleva coma decimal', () {
      expect(
        TextosProductoCaja.precio(productoSimple(precioCentavos: 450)),
        'S/ 4,50',
      );
    });

    test('por peso dice el precio por la unidad', () {
      final t = TextosProductoCaja.precio(quesoPorMedida());
      expect(t, contains('S/ 24,00'));
      expect(t, isNot(contains('.')));
    });

    test('un combo muestra su precio propio', () {
      expect(TextosProductoCaja.precio(comboGaseosaYPapas()), 'S/ 15,00');
    });

    test('el stock también lleva coma y su unidad', () {
      final t = TextosProductoCaja.stock(productoSimple(stock: 22));
      expect(t, contains('22'));
      expect(
        TextosProductoCaja.stock(productoSimple(stock: 5, infinito: true)),
        'ilimitado',
      );
    });

    test('la palabra del tipo', () {
      expect(TextosProductoCaja.tipo(productoSimple()), '');
      expect(TextosProductoCaja.tipo(quesoPorMedida()), 'Por peso');
      expect(TextosProductoCaja.tipo(poloConModelos()), 'Variable');
      expect(TextosProductoCaja.tipo(comboGaseosaYPapas()), 'Combo');
    });
  });
}
