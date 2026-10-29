import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/sugerencias_modelos.dart';
import 'package:mobile/features/productos/application/services/totales_producto.dart';
import 'package:mobile/features/productos/application/services/validador_modelos.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';

void main() {
  group('TotalesProducto', () {
    const azul = ModeloProducto(
      id: 'a',
      filas: [
        FilaVenta(id: 's', precioCentavos: 3500, stock: 4),
        FilaVenta(id: 'm', precioCentavos: 3500, stock: 6),
        FilaVenta(id: 'l', precioCentavos: 3800, stock: 2),
      ],
    );
    const amarillo = ModeloProducto(
      id: 'b',
      filas: [FilaVenta(id: 'l', precioCentavos: 3200, stock: 5)],
    );

    test('el stock del modelo es la suma de sus filas', () {
      expect(TotalesProducto.stockDelModelo(azul), 12);
      expect(TotalesProducto.stockDelModelo(amarillo), 5);
    });

    test('el stock del producto es la suma de todos los modelos', () {
      expect(TotalesProducto.stockTotal(const [azul, amarillo]), 17);
    });

    test('el precio desde es el menor con precio', () {
      expect(TotalesProducto.precioDesdeCentavos(const [azul, amarillo]), 3200);
    });

    test('las filas sin precio no cuentan como desde', () {
      const sinPrecio = ModeloProducto(
        id: 'c',
        filas: [
          FilaVenta(id: 'x'),
          FilaVenta(id: 'y', precioCentavos: 900),
        ],
      );
      expect(TotalesProducto.precioDesdeCentavos(const [sinPrecio]), 900);
      expect(TotalesProducto.precioDesdeCentavos(const []), 0);
    });

    test('por medida suma el stock en unidad base', () {
      const queso = [
        ModeloProducto(
          id: 'a',
          filas: [FilaVenta(id: 'f', stockBase: 4000)],
        ),
        ModeloProducto(
          id: 'b',
          filas: [FilaVenta(id: 'f', stockBase: 2500)],
        ),
      ];
      expect(TotalesProducto.stockBaseTotal(queso), 6500);
      expect(TotalesProducto.stockBaseDelModelo(queso.first), 4000);
    });
  });

  group('ValidadorModelos', () {
    test('encuentra el primer repetido sin distinguir mayúsculas', () {
      expect(ValidadorModelos.primerRepetido(['S', 'M', ' m ']), 'm');
      expect(ValidadorModelos.primerRepetido(['Azul', 'azul']), 'azul');
    });

    test('sin repetidos devuelve null y los vacíos no cuentan', () {
      expect(ValidadorModelos.primerRepetido(['S', 'M', 'L']), isNull);
      expect(ValidadorModelos.primerRepetido(['', '  ', 'S']), isNull);
      expect(ValidadorModelos.primerRepetido(const []), isNull);
    });

    test('los límites caben en el documento', () {
      expect(ValidadorModelos.maxModelos, 30);
      expect(ValidadorModelos.maxFilas, 20);
    });
  });

  group('SugerenciasModelos', () {
    test('cada rubro propone sus palabras, nunca solo Color', () {
      expect(SugerenciasModelos.de('Ropa').palabras, [
        'Color',
        'Estilo',
        'Diseño',
      ]);
      expect(SugerenciasModelos.de('Bodega').palabras, [
        'Sabor',
        'Marca',
        'Tipo',
      ]);
      expect(SugerenciasModelos.de('Belleza y cuidado personal').palabras, [
        'Aroma',
        'Tono',
        'Fragancia',
      ]);
    });

    test('también propone el título de las filas del rubro', () {
      expect(SugerenciasModelos.de('Ropa').tituloFilas, 'Talla');
      expect(SugerenciasModelos.de('Bodega').tituloFilas, 'Formato');
    });

    test('los rubros desconocidos o antiguos usan «Otros»', () {
      final otros = SugerenciasModelos.de('Otros');
      expect(SugerenciasModelos.de('Farmacia').palabras, otros.palabras);
      expect(SugerenciasModelos.de('').palabras, otros.palabras);
    });
  });
}
