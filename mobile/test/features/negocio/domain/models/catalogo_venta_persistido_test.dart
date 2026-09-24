import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';

void main() {
  const rubros = [
    'Bodega',
    'Restaurante',
    'Ropa',
    'Accesorios y regalos',
    'Belleza y cuidado personal',
    'Otros',
    'Farmacia',
    'Ferretería',
  ];

  for (final rubro in rubros) {
    test('round-trip de $rubro conserva el catálogo maestro', () {
      final original = CatalogoVentaPersistido.desdePreset(
        PresetsVenta.obtener(rubro),
      );
      final mapa = original.toMap();
      final releido = CatalogoVentaPersistido.desdeMapa(mapa);

      expect(releido, isNotNull);
      expect(releido!.version, original.version);
      expect(releido.presentaciones, hasLength(original.presentaciones.length));
      expect(releido.medidas, hasLength(original.medidas.length));
      expect(releido.toMap(), mapa);
    });
  }

  test('las cantidades permanecen int tras el round-trip', () {
    final mapa = CatalogoVentaPersistido.desdePreset(
      PresetsVenta.obtener('Bodega'),
    ).toMap();
    final medidas = (mapa['medidas'] as List).cast<Map<String, dynamic>>();
    for (final medida in medidas) {
      expect(medida['minimoBase'], isA<int>());
      expect(medida['incrementoBase'], isA<int>());
      for (final cantidad in medida['cantidadesRapidasBase'] as List) {
        expect(cantidad, isA<int>());
      }
    }

    final releido = CatalogoVentaPersistido.desdeMapa(mapa)!;
    for (final medida in releido.medidas) {
      expect(medida.minimoBase, isA<int>());
      expect(medida.incrementoBase, isA<int>());
      for (final cantidad in medida.cantidadesRapidasBase) {
        expect(cantidad, isA<int>());
      }
    }
  });

  test('desdeMapa tolera campos inválidos y no inventa conversiones', () {
    final catalogo = CatalogoVentaPersistido.desdeMapa({
      'versionEsquema': 1,
      'presentaciones': [
        {
          'id': 'unidad',
          'nombre': 'Unidad',
          'formatos': [
            {'valorBase': 1, 'familia': 'conteo', 'unidadVisible': 'unidad'},
          ],
          'activa': true,
          'obligatoria': true,
          'personalizada': false,
        },
        {
          'id': '',
          'nombre': 'Sin id',
          'formatos': [
            {'valorBase': 1, 'familia': 'conteo', 'unidadVisible': 'unidad'},
          ],
        },
        {
          'id': 'no-es-un-mapa',
        },
        {
          'id': 'botella',
          'nombre': 'Botella',
          'formatos': [
            {'valorBase': 250, 'familia': 'volumen', 'unidadVisible': 'ml'},
            {'valorBase': 1, 'familia': 'volumen', 'unidadVisible': 'L'},
            {'valorBase': 250, 'familia': 'volumen', 'unidadVisible': 'kg'},
          7,
          ],
        },
      ],
      'medidas': [
        {
          'id': 'peso',
          'nombre': 'Peso',
          'familia': 'peso',
          'unidadBase': 'g',
          'unidadVisual': 'kg',
          'minimoBase': 100,
          'incrementoBase': 50,
          'cantidadesRapidasBase': [250, 500.0, 1000],
          'permiteCantidad': true,
          'permiteMonto': true,
          'activa': true,
          'obligatoria': false,
        },
        {
          'nombre': 'Sin id',
          'familia': 'peso',
          'unidadVisual': 'kg',
          'minimoBase': 100,
          'incrementoBase': 50,
        },
        {
          'id': 'volumen',
          'nombre': 'Volumen',
          'familia': 'conteo',
          'unidadBase': 'g',
          'unidadVisual': 'L',
          'minimoBase': 250,
          'incrementoBase': 250,
        },
      ],
    });

    expect(catalogo, isNotNull);
    expect(catalogo!.presentaciones, hasLength(2));
    final botella = catalogo.presentaciones.firstWhere(
      (presentacion) => presentacion.id == 'botella',
    );
    expect(botella.formatos, hasLength(2));
    expect(catalogo.medidas, hasLength(1));

    final peso = catalogo.medidas.single;
    expect(peso.id, 'peso');
    expect(peso.nombre, 'Peso');
    expect(peso.familia.name, 'peso');
    expect(peso.minimoBase, 100);
    expect(peso.incrementoBase, 50);
    expect(peso.cantidadesRapidasBase, [250, 1000]);
    expect(peso.permiteCantidad, isTrue);
    expect(peso.permiteMonto, isTrue);
    expect(peso.activa, isTrue);
    expect(peso.obligatoria, isFalse);
  });

  test('desdeMapa devuelve null si catalogoVenta no es un mapa', () {
    expect(CatalogoVentaPersistido.desdeMapa(null), isNull);
    expect(CatalogoVentaPersistido.desdeMapa('no es un mapa'), isNull);
    expect(CatalogoVentaPersistido.desdeMapa(42), isNull);
  });

  test('un mapa sin presentaciones ni medidas se lee de forma tolerante', () {
    final catalogo = CatalogoVentaPersistido.desdeMapa({
      'versionEsquema': 1,
    });

    expect(catalogo, isNotNull);
    expect(catalogo!.version, CatalogoVentaPersistido.versionEsquema);
    expect(catalogo.presentaciones, isEmpty);
    expect(catalogo.medidas, isEmpty);
  });
}