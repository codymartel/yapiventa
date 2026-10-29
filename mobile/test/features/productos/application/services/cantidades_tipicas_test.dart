import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/cantidades_tipicas.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  group('etiqueta', () {
    test('peso: enteros, cuartos y gramos', () {
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 1000), '1 kg');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 500), '½ kg');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 250), '¼ kg');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 750), '¾ kg');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 1500), '1½ kg');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 2000), '2 kg');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 100), '100 g');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 300), '300 g');
    });

    test('volumen, longitud y área', () {
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.volumen, 250), '¼ L');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.volumen, 100), '100 ml');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.longitud, 500), '½ m');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.longitud, 100), '10 cm');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.longitud, 5), '5 mm');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.area, 10000), '1 m²');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.area, 300), '300 cm²');
    });

    test('una cantidad que no es positiva no tiene etiqueta', () {
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, 0), '');
      expect(CantidadesTipicas.etiqueta(FamiliaUnidad.peso, -5), '');
    });
  });

  group('menú «Por»', () {
    test('peso: 1 kg, ½ kg, ¼ kg y 100 g', () {
      final tipicas = CantidadesTipicas.de(FamiliaUnidad.peso);
      expect(tipicas.map((t) => t.etiqueta), ['1 kg', '½ kg', '¼ kg', '100 g']);
      expect(tipicas.map((t) => t.base), [1000, 500, 250, 100]);
    });

    test('volumen, longitud y área', () {
      expect(
        CantidadesTipicas.de(FamiliaUnidad.volumen).map((t) => t.etiqueta),
        ['1 L', '½ L', '¼ L', '100 ml'],
      );
      expect(
        CantidadesTipicas.de(FamiliaUnidad.longitud).map((t) => t.etiqueta),
        ['1 m', '½ m', '10 cm'],
      );
      expect(CantidadesTipicas.de(FamiliaUnidad.area).map((t) => t.etiqueta), [
        '1 m²',
      ]);
    });

    test('el conteo no se vende por medida: no hay menú', () {
      expect(CantidadesTipicas.de(FamiliaUnidad.conteo), isEmpty);
    });

    test('coincidente reconoce solo las del menú', () {
      expect(
        CantidadesTipicas.coincidente(FamiliaUnidad.peso, 250)?.etiqueta,
        '¼ kg',
      );
      expect(CantidadesTipicas.coincidente(FamiliaUnidad.peso, 300), isNull);
    });
  });

  group('unidades', () {
    test('la unidad grande de cada familia', () {
      expect(CantidadesTipicas.unidadGrande(FamiliaUnidad.peso).nombre, 'kg');
      expect(CantidadesTipicas.unidadGrande(FamiliaUnidad.volumen).nombre, 'L');
      expect(
        CantidadesTipicas.unidadGrande(FamiliaUnidad.longitud).nombre,
        'm',
      );
      expect(CantidadesTipicas.unidadGrande(FamiliaUnidad.area).nombre, 'm²');
    });

    test('la unidad natural es la más grande que da un entero', () {
      expect(
        CantidadesTipicas.unidadNatural(FamiliaUnidad.peso, 2000).nombre,
        'kg',
      );
      expect(
        CantidadesTipicas.unidadNatural(FamiliaUnidad.peso, 300).nombre,
        'g',
      );
      expect(
        CantidadesTipicas.unidadNatural(FamiliaUnidad.longitud, 300).nombre,
        'cm',
      );
    });
  });
}
