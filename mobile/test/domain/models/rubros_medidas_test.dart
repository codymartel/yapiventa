import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/categoria.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/domain/models/unidad_medida.dart';

void main() {
  const rubros = [
    'Bodega',
    'Restaurante',
    'Ropa',
    'Accesorios y regalos',
    'Belleza y cuidado personal',
    'Otros',
  ];

  test('define categorías únicamente para los seis rubros vigentes', () {
    expect(Categorias.porRubro.keys, rubros);
    expect(Categorias.porRubro, isNot(contains('Farmacia')));
    expect(Categorias.porRubro, isNot(contains('Ferretería')));
  });

  test('Bodega contiene exactamente sus medidas predefinidas', () {
    final unidades = UnidadesMedida.obtener('Bodega');

    expect(_nombres(unidades), [
      'Unidad',
      'Docena',
      'g',
      'kg',
      'ml',
      'L',
      'Bolsa',
      'Botella',
      'Lata',
      'Caja',
      'Paquete',
      'Bandeja',
      'Saco',
      'Bidón',
      'Pote',
      'Frasco',
      'Rollo',
    ]);
    expect(_fracciones(unidades, 'Docena'), ['0.5', '1']);
    expect(_fracciones(unidades, 'g'), ['100', '250', '500', '750']);
    expect(_fracciones(unidades, 'kg'), ['1', '1.5', '2', '5']);
    expect(_fracciones(unidades, 'ml'), ['250', '500', '750']);
    expect(_fracciones(unidades, 'L'), [
      '1',
      '1.5',
      '2',
      '2.5',
      '3',
      '5',
      '20',
    ]);
  });

  test('Restaurante conserva porciones sin convertirlas a peso', () {
    final unidades = UnidadesMedida.obtener('Restaurante');

    expect(_nombres(unidades), [
      'Unidad',
      'Porción',
      'ml',
      'L',
      'Vaso',
      'Botella',
      'Lata',
      'Jarra',
      'Plato',
      'Combo',
      'Bandeja',
      'Caja',
      'Paquete',
    ]);
    expect(_fracciones(unidades, 'Porción'), ['0.125', '0.25', '0.5', '1']);
    expect(_fracciones(unidades, 'ml'), ['250', '500']);
    expect(_fracciones(unidades, 'L'), ['1']);
    expect(_nombres(unidades), isNot(containsAll(['g', 'kg'])));
  });

  test('Ropa no mezcla talla ni color con medidas', () {
    final nombres = _nombres(UnidadesMedida.obtener('Ropa'));

    expect(nombres, ['Unidad', 'Par', 'Conjunto', 'Paquete']);
    expect(nombres, isNot(contains('Talla')));
    expect(nombres, isNot(contains('Color')));
  });

  test('Accesorios y regalos contiene solo presentaciones definidas', () {
    expect(_nombres(UnidadesMedida.obtener('Accesorios y regalos')), [
      'Unidad',
      'Par',
      'Juego',
      'Set',
      'Paquete',
      'Caja',
      'Bolsa',
    ]);
  });

  test(
    'Belleza contiene exactamente sus bases, cantidades y presentaciones',
    () {
      final unidades = UnidadesMedida.obtener('Belleza y cuidado personal');

      expect(_nombres(unidades), [
        'Unidad',
        'Set',
        'Paquete',
        'g',
        'kg',
        'ml',
        'L',
        'Frasco',
        'Botella',
        'Pote',
        'Tubo',
        'Sachet',
        'Spray',
        'Caja',
      ]);
      expect(_fracciones(unidades, 'g'), [
        '10',
        '30',
        '50',
        '100',
        '250',
        '500',
      ]);
      expect(_fracciones(unidades, 'kg'), ['1']);
      expect(_fracciones(unidades, 'ml'), [
        '30',
        '50',
        '100',
        '120',
        '200',
        '250',
        '500',
        '750',
      ]);
      expect(_fracciones(unidades, 'L'), ['1']);
    },
  );

  test('Otros no agrega medidas especializadas', () {
    expect(_nombres(UnidadesMedida.obtener('Otros')), [
      'Unidad',
      'Par',
      'Juego',
      'Set',
      'Paquete',
      'Caja',
      'Bolsa',
      'Botella',
      'Frasco',
    ]);
  });

  for (final legacy in ['Farmacia', 'Ferretería']) {
    test('$legacy conserva compatibilidad cargando los presets de Otros', () {
      expect(Categorias.obtener(legacy), Categorias.obtener('Otros'));
      expect(
        _nombres(UnidadesMedida.obtener(legacy)),
        _nombres(UnidadesMedida.obtener('Otros')),
      );
    });
  }
}

List<String> _nombres(List<UnidadInfo> unidades) =>
    unidades.map((unidad) => unidad.nombre).toList();

List<String> _fracciones(List<UnidadInfo> unidades, String nombre) => unidades
    .firstWhere((unidad) => unidad.nombre == nombre)
    .fraccionesPermitidas
    .toList();
