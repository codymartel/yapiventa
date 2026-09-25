import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/configuracion_medida.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

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
        {'id': 'no-es-un-mapa'},
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
    expect(peso.familia!.name, 'peso');
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

  test(
    'requiereRevision round-trip conserva la marca sin ocultar el nombre',
    () {
      final revision = MedidaVentaPersistida(
        id: 'docena',
        nombre: 'Docena',
        familia: null,
        unidadBase: null,
        unidadVisual: null,
        minimoBase: 0,
        incrementoBase: 0,
        cantidadesRapidasBase: const [],
        requiereRevision: true,
      );

      final releido = MedidaVentaPersistida.desdeMapa(revision.toMap());

      expect(releido, isNotNull);
      expect(releido!.requiereRevision, isTrue);
      expect(releido.nombre, 'Docena');
      expect(releido.id, 'docena');
      expect(releido.familia, isNull);
      expect(releido.unidadBase, isNull);
      expect(releido.unidadVisual, isNull);
      expect(releido.minimoBase, 0);
    },
  );

  test('desdeMapa de una medida normal no marca requiereRevision', () {
    final original = CatalogoVentaPersistido.desdePreset(
      PresetsVenta.obtener('Bodega'),
    );
    for (final medida in original.medidas) {
      expect(medida.requiereRevision, isFalse);
      final releida = MedidaVentaPersistida.desdeMapa(medida.toMap());
      expect(releida, isNotNull);
      expect(releida!.requiereRevision, isFalse);
    }
  });

  test('desdeUnidadesLegacy devuelve null cuando no hay nada que adaptar', () {
    expect(CatalogoVentaPersistido.desdeUnidadesLegacy(const []), isNull);
  });

  test(
    'desdeUnidadesLegacy mapea una unidad segura a medida sin requiereRevision',
    () {
      final catalogo = CatalogoVentaPersistido.desdeUnidadesLegacy([
        const UnidadInfo(
          nombre: 'kg',
          tipo: TipoUnidad.fraccionaria,
          fraccionesPermitidas: ['1'],
        ),
      ]);

      expect(catalogo, isNotNull);
      expect(catalogo!.medidas, hasLength(1));
      final medida = catalogo.medidas.single;
      expect(medida.nombre, 'kg');
      expect(medida.familia, FamiliaUnidad.peso);
      expect(medida.unidadBase, RegistroUnidades.g);
      expect(medida.unidadVisual, RegistroUnidades.kg);
      expect(medida.requiereRevision, isFalse);
      expect(medida.minimoBase, greaterThan(0));
      expect(catalogo.presentaciones, isEmpty);
    },
  );

  test(
    'desdeUnidadesLegacy adapta la unidad de conteo como presentación unidad',
    () {
      final catalogo = CatalogoVentaPersistido.desdeUnidadesLegacy([
        const UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      ]);

      expect(catalogo, isNotNull);
      final presentacion = catalogo!.presentaciones.firstWhere(
        (presentacion) => presentacion.id == 'unidad',
      );
      expect(presentacion.nombre, 'Unidad');
      expect(catalogo.medidas, isEmpty);
    },
  );

  test(
    'desdeUnidadesLegacy marca requiereRevision sin inventar conversión',
    () {
      final catalogo = CatalogoVentaPersistido.desdeUnidadesLegacy([
        const UnidadInfo(nombre: 'Docena', tipo: TipoUnidad.fraccionaria),
        const UnidadInfo(nombre: 'Bolsa', tipo: TipoUnidad.entera),
      ]);

      expect(catalogo, isNotNull);
      expect(catalogo!.medidas, hasLength(2));
      for (final medida in catalogo.medidas) {
        expect(medida.requiereRevision, isTrue);
        expect(medida.familia, isNull);
        expect(medida.unidadBase, isNull);
        expect(medida.unidadVisual, isNull);
        expect(medida.minimoBase, 0);
        expect(medida.incrementoBase, 0);
        expect(medida.cantidadesRapidasBase, isEmpty);
        expect(medida.nombre, isNot(isEmpty));
      }
      expect(catalogo.presentaciones, isEmpty);
    },
  );

  test(
    'desdeUnidadesLegacy combina segura y requiereRevision en el mismo catálogo',
    () {
      final catalogo = CatalogoVentaPersistido.desdeUnidadesLegacy([
        const UnidadInfo(nombre: 'kg', tipo: TipoUnidad.fraccionaria),
        const UnidadInfo(nombre: 'Docena', tipo: TipoUnidad.fraccionaria),
        const UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      ]);

      expect(catalogo, isNotNull);
      expect(catalogo!.presentaciones, hasLength(1));
      expect(
        catalogo.medidas.where((medida) => !medida.requiereRevision),
        hasLength(1),
      );
      expect(
        catalogo.medidas.where((medida) => medida.requiereRevision),
        hasLength(1),
      );
      final segura = catalogo.medidas.firstWhere(
        (medida) => !medida.requiereRevision,
      );
      expect(segura.familia, FamiliaUnidad.peso);
    },
  );

  test('un mapa sin presentaciones ni medidas se lee de forma tolerante', () {
    final catalogo = CatalogoVentaPersistido.desdeMapa({'versionEsquema': 1});

    expect(catalogo, isNotNull);
    expect(catalogo!.version, CatalogoVentaPersistido.versionEsquema);
    expect(catalogo.presentaciones, isEmpty);
    expect(catalogo.medidas, isEmpty);
  });

  test(
    'toConfiguracion reconstruye la ConfiguracionMedida de una medida segura',
    () {
      final configuracion = ConfiguracionMedida(
        familia: FamiliaUnidad.peso,
        unidadVisual: RegistroUnidades.kg,
        minimoBase: 300,
        incrementoBase: 50,
        cantidadesRapidasBase: const [300, 400],
        permiteCantidad: true,
        monto: EstadoMonto.activo,
        activa: true,
      );
      final medida = MedidaVentaPersistida.desdeConfiguracion(configuracion);

      final releida = medida.toConfiguracion();

      expect(releida, isNotNull);
      expect(releida!.familia, FamiliaUnidad.peso);
      expect(releida.unidadBase, RegistroUnidades.g);
      expect(releida.unidadVisual, RegistroUnidades.kg);
      expect(releida.minimoBase, 300);
      expect(releida.incrementoBase, 50);
      expect(releida.cantidadesRapidasBase, [300, 400]);
      expect(releida.permiteCantidad, isTrue);
      expect(releida.monto, EstadoMonto.activo);
      expect(releida.activa, isTrue);
    },
  );

  test('toConfiguracion devuelve null en medidas que requieren revisión', () {
    final medida = MedidaVentaPersistida(
      id: 'Docena',
      nombre: 'Docena',
      requiereRevision: true,
    );

    expect(medida.toConfiguracion(), isNull);
  });
}
