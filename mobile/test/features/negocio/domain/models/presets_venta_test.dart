import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_global.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/configuracion_medida.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  group('PresetsVenta (resolucion por rubro)', () {
    test('los seis rubros tienen preset propio', () {
      const rubros = [
        'Bodega',
        'Restaurante',
        'Ropa',
        'Accesorios y regalos',
        'Belleza y cuidado personal',
        'Otros',
      ];
      for (final rubro in rubros) {
        expect(
          PresetsVenta.porRubro.containsKey(rubro),
          isTrue,
          reason: 'Falta el preset de $rubro',
        );
        expect(PresetsVenta.esRubroConPresetPropio(rubro), isTrue);
      }
    });

    test('los legacy Farmacia y Ferreteria resuelven al preset de Otros', () {
      final farmacia = PresetsVenta.obtener('Farmacia');
      final ferreteria = PresetsVenta.obtener('Ferretería');
      expect(identical(farmacia, PresetsVenta.porRubro['Otros']), isTrue);
      expect(identical(ferreteria, PresetsVenta.porRubro['Otros']), isTrue);
      expect(PresetsVenta.rubrosLegacy, {'Farmacia', 'Ferretería'});
      expect(PresetsVenta.esRubroConPresetPropio('Farmacia'), isFalse);
    });

    test('un rubro desconocido resuelve a Otros sin reescribir el rubro', () {
      final preset = PresetsVenta.obtener('No existe');
      expect(identical(preset, PresetsVenta.porRubro['Otros']), isTrue);
    });
  });

  // ── Bodega ──────────────────────────────────────────────────────────────
  group('preset Bodega', () {
    final preset = PresetsVenta.obtener('Bodega');

    test('categorias sugeridas', () {
      expect(preset.categorias, [
        'Abarrotes',
        'Bebidas',
        'Snacks',
        'Limpieza',
        'Cuidado personal',
      ]);
    });

    test('obligatorias: unidad, botella, lata, bolsa, caja y paquete', () {
      const obligatorias = ['unidad', 'botella', 'lata', 'bolsa', 'caja', 'paquete'];
      for (final id in obligatorias) {
        expect(preset.estadoDe(id), EstadoVenta.obligatoria, reason: id);
        final opcion = preset.opcionPorId(id)!;
        expect(opcion.activa, isTrue, reason: id);
        expect(opcion.obligatoria, isTrue, reason: id);
      }
    });

    test('no tiene opcionales ni medidas fuera de Bodega', () {
      expect(preset.tieneOpcionales, isFalse);
    });

    test('botella: 250, 500, 625, 650, 1L, 1½L, 2L, 2½L, 3L', () {
      final formatos = preset.opcionPorId('botella')!.formatos;
      expect(
        formatos.map((f) => f.valorBase).toList(),
        [250, 500, 625, 650, 1000, 1500, 2000, 2500, 3000],
      );
      expect(
        formatos.every((f) => f.familia == FamiliaUnidad.volumen),
        isTrue,
      );
      expect(formatos.first.unidadVisible, RegistroUnidades.ml);
      expect(formatos.last.unidadVisible, RegistroUnidades.L);
    });

    test('lata: 170 g, 355 ml y 400 g', () {
      final formatos = preset.opcionPorId('lata')!.formatos;
      expect(
        formatos.map((f) => (f.familia, f.valorBase)).toList(),
        [
          (FamiliaUnidad.peso, 170),
          (FamiliaUnidad.volumen, 355),
          (FamiliaUnidad.peso, 400),
        ],
      );
    });

    test('caja y paquete: x6, x12 y x24', () {
      for (final id in ['caja', 'paquete']) {
        final formatos = preset.opcionPorId(id)!.formatos;
        expect(
          formatos.map((f) => f.valorBase).toList(),
          [6, 12, 24],
          reason: id,
        );
        expect(
          formatos.every((f) => f.familia == FamiliaUnidad.conteo),
          isTrue,
          reason: id,
        );
      }
    });

    test('peso activo: min 100, inc 50, rápidas 250..1000, monto sí', () {
      final peso = preset.medidaDe(FamiliaUnidad.peso)!;
      expect(peso.activa, isTrue);
      expect(peso.minimoBase, 100);
      expect(peso.incrementoBase, 50);
      expect(peso.cantidadesRapidasBase, [250, 500, 750, 1000]);
      expect(peso.permiteCantidad, isTrue);
      expect(peso.permiteMonto, isTrue);
      expect(peso.montoActivo, isTrue);
    });

    test('volumen activo: min 250, inc 250, rápidas 250..1000, monto opcional',
        () {
      final volumen = preset.medidaDe(FamiliaUnidad.volumen)!;
      expect(volumen.activa, isTrue);
      expect(volumen.minimoBase, 250);
      expect(volumen.incrementoBase, 250);
      expect(volumen.cantidadesRapidasBase, [250, 500, 750, 1000]);
      expect(volumen.permiteCantidad, isTrue);
      expect(volumen.permiteMonto, isTrue);
      expect(volumen.montoActivo, isFalse);
    });

    test('tiene medidas activas', () {
      expect(preset.tieneMedidasActivas, isTrue);
    });

    test('no admite presentaciones personalizadas', () {
      expect(preset.permitePersonalizadas, isFalse);
    });

    test('presentaciones inactivas: plato, porción, vaso, jarra, set y frasco',
        () {
      for (final id in ['plato', 'porcion', 'vaso', 'jarra', 'set', 'frasco']) {
        expect(preset.estadoDe(id), EstadoVenta.inactiva, reason: id);
        expect(preset.opcionPorId(id), isNull, reason: id);
      }
    });
  });

  // ── Restaurante ─────────────────────────────────────────────────────────
  group('preset Restaurante', () {
    final preset = PresetsVenta.obtener('Restaurante');

    test('categorias sugeridas', () {
      expect(preset.categorias, [
        'Entradas',
        'Platos principales',
        'Bebidas',
        'Postres',
        'Combos',
      ]);
    });

    test('obligatorias: unidad, porción, plato, combo, vaso y botella', () {
      const obligatorias = ['unidad', 'porcion', 'plato', 'combo', 'vaso', 'botella'];
      for (final id in obligatorias) {
        expect(preset.estadoDe(id), EstadoVenta.obligatoria, reason: id);
        expect(preset.opcionPorId(id)!.obligatoria, isTrue, reason: id);
      }
    });

    test('jarra es opcional', () {
      final jarra = preset.opcionPorId('jarra')!;
      expect(preset.estadoDe('jarra'), EstadoVenta.opcional);
      expect(jarra.activa, isFalse);
      expect(jarra.obligatoria, isFalse);
      expect(preset.tieneOpcionales, isTrue);
    });

    test('plato, combo y porción se cuentan, no se convierten en peso', () {
      for (final id in ['plato', 'combo', 'porcion']) {
        final formatos = preset.opcionPorId(id)!.formatos;
        expect(formatos, hasLength(1));
        expect(formatos.single.familia, FamiliaUnidad.conteo, reason: id);
        expect(formatos.single.valorBase, 1, reason: id);
      }
    });

    test('vaso: 250, 350 y 500 ml', () {
      final formatos = preset.opcionPorId('vaso')!.formatos;
      expect(formatos.map((f) => f.valorBase).toList(), [250, 350, 500]);
      expect(
        formatos.every((f) => f.familia == FamiliaUnidad.volumen),
        isTrue,
      );
    });

    test('peso y volumen disponibles pero inactivos', () {
      final peso = preset.medidaDe(FamiliaUnidad.peso)!;
      final volumen = preset.medidaDe(FamiliaUnidad.volumen)!;
      expect(peso.activa, isFalse);
      expect(volumen.activa, isFalse);
      expect(preset.tieneMedidasActivas, isFalse);
    });

    test('no admite presentaciones personalizadas', () {
      expect(preset.permitePersonalizadas, isFalse);
    });

    test('presentaciones inactivas: lata, bolsa, par, set, conjunto y frasco',
        () {
      for (final id in ['lata', 'bolsa', 'par', 'set', 'conjunto', 'frasco']) {
        expect(preset.estadoDe(id), EstadoVenta.inactiva, reason: id);
        expect(preset.opcionPorId(id), isNull, reason: id);
      }
    });
  });

  // ── Ropa ────────────────────────────────────────────────────────────────
  group('preset Ropa', () {
    final preset = PresetsVenta.obtener('Ropa');

    test('categorias sugeridas', () {
      expect(preset.categorias, ['Hombre', 'Mujer', 'Niños', 'Calzado', 'Accesorios']);
    });

    test('obligatorias: unidad, par y conjunto', () {
      for (final id in ['unidad', 'par', 'conjunto']) {
        expect(preset.estadoDe(id), EstadoVenta.obligatoria, reason: id);
        expect(preset.opcionPorId(id)!.obligatoria, isTrue, reason: id);
      }
    });

    test('sugeridas (opcionales): paquete, caja y bolsa', () {
      for (final id in ['paquete', 'caja', 'bolsa']) {
        expect(preset.estadoDe(id), EstadoVenta.opcional, reason: id);
        expect(preset.opcionPorId(id)!.activa, isFalse, reason: id);
      }
    });

    test('medidas inactivas: longitud para tela con rápidas ½/1/1½/2 m', () {
      final longitud = preset.medidaDe(FamiliaUnidad.longitud)!;
      expect(longitud.activa, isFalse);
      expect(longitud.minimoBase, 100);
      expect(longitud.incrementoBase, 100);
      expect(longitud.cantidadesRapidasBase, [500, 1000, 1500, 2000]);
      expect(preset.tieneMedidasActivas, isFalse);
    });

    test('talla y color no son medidas ni formatos', () {
      expect(CatalogoVentaGlobal.esIdValido('talla'), isFalse);
      expect(CatalogoVentaGlobal.esIdValido('color'), isFalse);
      for (final familia in CatalogoVentaGlobal.familiasMedida) {
        expect(preset.medidaDe(familia)?.activa, isNot(true));
      }
    });

    test('no admite presentaciones personalizadas', () {
      expect(preset.permitePersonalizadas, isFalse);
    });

    test('presentaciones inactivas: botella, vaso, porción, plato y set', () {
      for (final id in ['botella', 'vaso', 'porcion', 'plato', 'set']) {
        expect(preset.estadoDe(id), EstadoVenta.inactiva, reason: id);
        expect(preset.opcionPorId(id), isNull, reason: id);
      }
    });
  });

  // ── Accesorios y regalos ────────────────────────────────────────────────
  group('preset Accesorios y regalos', () {
    final preset = PresetsVenta.obtener('Accesorios y regalos');

    test('categorias sugeridas', () {
      expect(preset.categorias, [
        'Bisutería',
        'Carteras',
        'Peluches',
        'Regalos',
        'Detalles',
      ]);
    });

    test('obligatorias: unidad, par, set y juego', () {
      for (final id in ['unidad', 'par', 'set', 'juego']) {
        expect(preset.estadoDe(id), EstadoVenta.obligatoria, reason: id);
        expect(preset.opcionPorId(id)!.obligatoria, isTrue, reason: id);
      }
    });

    test('sugeridas (opcionales): paquete, caja y bolsa', () {
      for (final id in ['paquete', 'caja', 'bolsa']) {
        expect(preset.estadoDe(id), EstadoVenta.opcional, reason: id);
      }
    });

    test('todas las medidas inactivas; longitud 10..100 cm, inc 50 mm', () {
      final longitud = preset.medidaDe(FamiliaUnidad.longitud)!;
      expect(longitud.activa, isFalse);
      expect(longitud.minimoBase, 100);
      expect(longitud.incrementoBase, 50);
      expect(longitud.cantidadesRapidasBase, [100, 250, 500, 1000]);
      expect(preset.tieneMedidasActivas, isFalse);
    });

    test('no admite presentaciones personalizadas', () {
      expect(preset.permitePersonalizadas, isFalse);
    });

    test('presentaciones inactivas: plato, combo, botella, vaso y frasco', () {
      for (final id in ['plato', 'combo', 'botella', 'vaso', 'frasco']) {
        expect(preset.estadoDe(id), EstadoVenta.inactiva, reason: id);
        expect(preset.opcionPorId(id), isNull, reason: id);
      }
    });
  });

  // ── Belleza y cuidado personal ──────────────────────────────────────────
  group('preset Belleza y cuidado personal', () {
    final preset = PresetsVenta.obtener('Belleza y cuidado personal');

    test('categorias sugeridas', () {
      expect(preset.categorias, [
        'Cabello',
        'Rostro',
        'Cuerpo',
        'Maquillaje',
        'Perfumería',
      ]);
    });

    test('obligatorias: unidad, frasco, botella, pote, tubo, sachet y spray',
        () {
      const obligatorias = ['unidad', 'frasco', 'botella', 'pote', 'tubo', 'sachet', 'spray'];
      for (final id in obligatorias) {
        expect(preset.estadoDe(id), EstadoVenta.obligatoria, reason: id);
        expect(preset.opcionPorId(id)!.obligatoria, isTrue, reason: id);
      }
    });

    test('frasco: 30, 50, 100, 120, 200, 250 y 500 ml', () {
      final formatos = preset.opcionPorId('frasco')!.formatos;
      expect(formatos.map((f) => f.valorBase).toList(), [
        30,
        50,
        100,
        120,
        200,
        250,
        500,
      ]);
      expect(
        formatos.every((f) => f.familia == FamiliaUnidad.volumen),
        isTrue,
      );
    });

    test('botella: 100, 200, 250, 500, 750 ml y 1 L', () {
      final formatos = preset.opcionPorId('botella')!.formatos;
      expect(formatos.map((f) => f.valorBase).toList(), [
        100,
        200,
        250,
        500,
        750,
        1000,
      ]);
    });

    test('pote y tubo: 30, 50, 100, 250 y 500 g', () {
      for (final id in ['pote', 'tubo']) {
        final formatos = preset.opcionPorId(id)!.formatos;
        expect(formatos.map((f) => f.valorBase).toList(), [
          30,
          50,
          100,
          250,
          500,
        ]);
        expect(
          formatos.every((f) => f.familia == FamiliaUnidad.peso),
          isTrue,
          reason: id,
        );
      }
    });

    test('sachet: 5, 10, 15 y 20 ml', () {
      final formatos = preset.opcionPorId('sachet')!.formatos;
      expect(formatos.map((f) => f.valorBase).toList(), [5, 10, 15, 20]);
      expect(
        formatos.every((f) => f.familia == FamiliaUnidad.volumen),
        isTrue,
      );
    });

    test('peso y volumen disponibles pero inactivos', () {
      expect(preset.medidaDe(FamiliaUnidad.peso)!.activa, isFalse);
      expect(preset.medidaDe(FamiliaUnidad.volumen)!.activa, isFalse);
      expect(preset.tieneMedidasActivas, isFalse);
    });

    test('presentaciones inactivas: par, conjunto, lata y vaso', () {
      for (final id in ['par', 'conjunto', 'lata', 'vaso']) {
        expect(preset.estadoDe(id), EstadoVenta.inactiva, reason: id);
        expect(preset.opcionPorId(id), isNull, reason: id);
      }
    });

    test('no admite presentaciones personalizadas', () {
      expect(preset.permitePersonalizadas, isFalse);
    });
  });

  // ── Otros ───────────────────────────────────────────────────────────────
  group('preset Otros', () {
    final preset = PresetsVenta.obtener('Otros');

    test('categorias sugeridas', () {
      expect(preset.categorias, [
        'Productos',
        'Accesorios',
        'Servicios relacionados',
        'Otros',
      ]);
    });

    test('obligatoria unidad; par, set, caja, paquete y bolsa opcionales', () {
      expect(preset.estadoDe('unidad'), EstadoVenta.obligatoria);
      expect(preset.opcionPorId('unidad')!.obligatoria, isTrue);
      for (final id in ['par', 'set', 'caja', 'paquete', 'bolsa']) {
        expect(preset.estadoDe(id), EstadoVenta.opcional, reason: id);
        expect(preset.opcionPorId(id)!.activa, isFalse, reason: id);
      }
      expect(preset.tieneOpcionales, isTrue);
    });

    test('las cuatro medidas disponibles pero inactivas', () {
      for (final familia in CatalogoVentaGlobal.familiasMedida) {
        final medida = preset.medidaDe(familia);
        expect(medida, isNotNull, reason: familia.name);
        expect(medida!.activa, isFalse, reason: familia.name);
      }
      expect(preset.tieneMedidasActivas, isFalse);
    });

    test('presentaciones inexistentes en Otros: botella, plato, vaso y frasco',
        () {
      for (final id in ['botella', 'plato', 'vaso', 'frasco']) {
        expect(preset.estadoDe(id), EstadoVenta.inactiva, reason: id);
        expect(preset.opcionPorId(id), isNull, reason: id);
      }
    });

    test('es el único rubro que admite presentaciones personalizadas', () {
      expect(preset.permitePersonalizadas, isTrue);
      for (final rubro in [
        'Bodega',
        'Restaurante',
        'Ropa',
        'Accesorios y regalos',
        'Belleza y cuidado personal',
      ]) {
        expect(PresetsVenta.obtener(rubro).permitePersonalizadas, isFalse,
            reason: rubro);
      }
    });
  });

  // ── Protección del catálogo global ──────────────────────────────────────
  group('proteccion del catalogo global', () {
    test('estadoDe de un id ausente es inactiva', () {
      final bodega = PresetsVenta.obtener('Bodega');
      expect(bodega.estadoDe('porcion'), EstadoVenta.inactiva);
      expect(bodega.estadoDe('vaso'), EstadoVenta.inactiva);
    });

    test('estadoDe de un id inexistente lanza ArgumentError', () {
      final bodega = PresetsVenta.obtener('Bodega');
      expect(() => bodega.estadoDe('talla'), throwsArgumentError);
      expect(() => bodega.estadoDe('no_existe'), throwsArgumentError);
    });

    test('un preset no puede usar una presentación desconocida', () {
      expect(
        () => PresetVentaRubro.modelar(
          rubro: 'Prueba',
          categorias: const ['General'],
          presentaciones: {
            'no_existe': (
              estado: EstadoVenta.obligatoria,
              formatos: CatalogoVentaGlobal.formatosDe(
                'unidad',
                valoresBase: const [1],
              ),
            ),
          },
          medidas: const [],
        ),
        throwsArgumentError,
      );
    });

    test('un preset no puede usar un formato fuera del catálogo global', () {
      expect(
        () => PresetVentaRubro.modelar(
          rubro: 'Prueba',
          categorias: const ['General'],
          presentaciones: {
            'botella': (
              estado: EstadoVenta.obligatoria,
              formatos: CatalogoVentaGlobal.formatosDe(
                'botella',
                valoresBase: const [999],
              ),
            ),
          },
          medidas: const [],
        ),
        throwsArgumentError,
      );
    });

    test('un preset no puede incluir una medida de conteo', () {
      expect(
        () => PresetVentaRubro.modelar(
          rubro: 'Prueba',
          categorias: const ['General'],
          presentaciones: {
            'unidad': (
              estado: EstadoVenta.obligatoria,
              formatos: CatalogoVentaGlobal.formatosDe(
                'unidad',
                valoresBase: const [1],
              ),
            ),
          },
          medidas: [
            ConfiguracionMedida(
              familia: FamiliaUnidad.conteo,
              unidadVisual: RegistroUnidades.unidad,
              minimoBase: 1,
              incrementoBase: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('un preset no puede usar estado inactiva en una presentación', () {
      expect(
        () => PresetVentaRubro.modelar(
          rubro: 'Prueba',
          categorias: const ['General'],
          presentaciones: {
            'unidad': (
              estado: EstadoVenta.inactiva,
              formatos: CatalogoVentaGlobal.formatosDe(
                'unidad',
                valoresBase: const [1],
              ),
            ),
          },
          medidas: const [],
        ),
        throwsArgumentError,
      );
    });

    test('no admite categorías vacías ni duplicadas', () {
      expect(
        () => PresetVentaRubro.modelar(
          rubro: 'Prueba',
          categorias: const [],
          presentaciones: {},
          medidas: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => PresetVentaRubro.modelar(
          rubro: 'Prueba',
          categorias: const ['A', 'A'],
          presentaciones: {},
          medidas: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}