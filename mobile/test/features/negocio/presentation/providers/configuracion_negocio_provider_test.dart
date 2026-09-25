import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_global.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  test('limita el telefono al maximo de digitos del pais seleccionado', () {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );

    provider.telefono = '999abc888777';
    expect(provider.telefono, '999888777');

    provider.paisTelefono = paisesLatam.firstWhere(
      (pais) => pais.nombre == 'Bolivia',
    );
    expect(provider.telefono, '99988877');
  });

  test('agrega y edita una unidad con sus fracciones permitidas', () {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );
    final totalInicial = provider.unidadesMedida.length;

    provider.agregarUnidad(
      const UnidadInfo(
        nombre: 'Medida propia',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.5', '1'],
      ),
    );
    provider.editarUnidad(
      totalInicial,
      const UnidadInfo(
        nombre: 'Medida propia grande',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1', '2'],
      ),
    );

    expect(
      provider.unidadesMedida[totalInicial].nombre,
      'Medida propia grande',
    );
    expect(provider.unidadesMedida[totalInicial].fraccionesPermitidas, [
      '1',
      '2',
    ]);
  });

  test('exige al menos una unidad para completar el catálogo', () {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );

    for (final unidad in provider.unidadesPredefinidas) {
      provider.establecerUnidadPredefinidaActiva(unidad, activa: false);
    }

    expect(provider.faltaUnidad, isTrue);
    expect(provider.puedeAvanzarPaso1, isFalse);
  });

  test('las unidades base no se eliminan ni se renombran', () {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );
    final bases = ['Unidad', 'g', 'kg', 'ml', 'L'];

    for (final nombre in bases) {
      final index = provider.unidadesMedida.indexWhere(
        (unidad) => unidad.nombre == nombre,
      );
      final actual = provider.unidadesMedida[index];
      provider.editarUnidad(
        index,
        UnidadInfo(
          nombre: '$nombre editada',
          tipo: actual.tipo,
          fraccionesPermitidas: actual.fraccionesPermitidas,
        ),
      );
      provider.eliminarUnidad(index);
    }

    expect(
      provider.unidadesMedida.map((unidad) => unidad.nombre),
      containsAll(bases),
    );
  });

  test(
    'un preset puede desactivarse y reactivarse sin eliminar su definición',
    () {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );
      final botella = provider.unidadesPredefinidas.firstWhere(
        (unidad) => unidad.nombre == 'Botella',
      );

      provider.establecerUnidadPredefinidaActiva(botella, activa: false);
      expect(provider.unidadPredefinidaActiva('Botella'), isFalse);
      expect(
        provider.unidadesPredefinidas.map((unidad) => unidad.nombre),
        contains('Botella'),
      );

      provider.establecerUnidadPredefinidaActiva(botella, activa: true);
      expect(provider.unidadPredefinidaActiva('Botella'), isTrue);
    },
  );

  for (final legacy in ['Farmacia', 'Ferretería']) {
    test('$legacy carga presets compatibles sin cambiar el rubro', () {
      final provider = ConfiguracionNegocioProvider(
        rubro: legacy,
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );

      expect(provider.rubro, legacy);
      expect(provider.unidadesPredefinidas.map((unidad) => unidad.nombre), [
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
  }

  test(
    'un negocio nuevo se siembra con el preset como única fuente, sin mapas legacy',
    () {
      final preset = PresetsVenta.obtener('Bodega');
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );

      // Categorías: las del preset, no las de Categorias.porRubro.
      expect(provider.categorias, preset.categorias);
      expect(provider.categorias, isNot(containsAll(['Lácteos', 'Panadería'])));

      // Presentaciones y medidas del catálogo: las del preset.
      expect(
        provider.catalogoVenta.presentaciones.map((p) => p.id),
        preset.presentaciones.map((p) => p.id),
      );
      expect(
        provider.catalogoVenta.medidas.map(
          (medida) => (medida.familia, medida.activa),
        ),
        preset.medidas.map(
          (configuracion) => (configuracion.familia, configuracion.activa),
        ),
      );
      expect(provider.medidasPendientesRevision, isEmpty);

      // El espejo legacy de unidades no arrastra las fantasma del mapa legacy.
      const unidadesFantasma = [
        'Docena',
        'Bandeja',
        'Saco',
        'Bidón',
        'Pote',
        'Frasco',
        'Rollo',
      ];
      final nombresUnidades = provider.unidadesMedida.map((u) => u.nombre);
      for (final fantasma in unidadesFantasma) {
        expect(nombresUnidades, isNot(contains(fantasma)));
      }
      expect(provider.faltaCategoria, isFalse);
      expect(provider.faltaUnidad, isFalse);
      expect(provider.puedeAvanzarPaso1, isTrue);
    },
  );

  test(
    "caso legacy 'dasdsad': el documento heredado se lee sin inventar conversiones",
    () {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Ropa',
        configuracionInicial: {
          'nombreNegocio': 'dasdsad',
          'categorias': ['Hombre', 'Mujer', 'Niños'],
          'unidadesMedida': [
            {
              'nombre': 'Unidad',
              'tipo': 'entera',
              'fraccionesPermitidas': <String>[],
              'esOpcional': false,
            },
            {
              'nombre': 'Par',
              'tipo': 'entera',
              'fraccionesPermitidas': <String>[],
              'esOpcional': false,
            },
            {
              'nombre': 'Paquete',
              'tipo': 'entera',
              'fraccionesPermitidas': <String>[],
              'esOpcional': false,
            },
          ],
          'delivery': false,
        },
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );

      // Las unidades del documento legacy se conservan tal cual (solo lectura).
      expect(provider.categorias, ['Hombre', 'Mujer', 'Niños']);
      expect(provider.unidadesMedida.map((u) => u.nombre), [
        'Unidad',
        'Par',
        'Paquete',
      ]);

      // Con la corrección, el catálogo se mantiene desde el preset
      // del rubro; no se reconstruye desde unidades legacy.
      // Las unidades legacy no generan medidas pendientes de revisión.
      expect(provider.medidasPendientesRevision, isEmpty);
      expect(provider.puedeAvanzarPaso1, isTrue);

      // El preset del rubro sigue siendo la semilla para un negocio nuevo.
      final nuevo = ConfiguracionNegocioProvider(
        rubro: 'Ropa',
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );
      expect(nuevo.medidasPendientesRevision, isEmpty);
      expect(nuevo.categorias, PresetsVenta.obtener('Ropa').categorias);
    },
  );

  test('bloquea un segundo guardado concurrente', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: firestore),
    );
    provider.nombreNegocio = 'Bodega Ana';
    provider.telefono = '999999999';
    provider.direccion = 'Av. Lima 123';
    provider.referencia = 'Frente al parque';

    final primero = provider.guardar('usuario-1');
    final segundo = provider.guardar('usuario-1');

    expect(await segundo, isFalse);
    expect(await primero, isTrue);
    final datos =
        (await firestore.collection('negocios').doc('negocio-1').get()).data()!;
    expect(datos['setupComplete'], isNull);
    expect(datos['onboardingBusinessRubro'], 'Bodega');
  });

  test(
    'desbloquea el guardado si un producto usa una categoría eliminada',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'negocioId': 'negocio-1',
      });
      await firestore
          .collection('negocios')
          .doc('negocio-1')
          .collection('productos')
          .doc('producto-1')
          .set({'categoria': 'Bebidas'});
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        configuracionInicial: {
          'nombreNegocio': 'Bodega Ana',
          'telefono': '+51999999999',
          'direccion': 'Av. Lima 123 (Ref: Frente al parque)',
          'categorias': ['Bebidas'],
          'unidadesMedida': [
            {
              'nombre': 'Unidad',
              'tipo': 'entera',
              'fraccionesPermitidas': <String>[],
              'esOpcional': false,
            },
          ],
          'delivery': false,
        },
        repository: NegocioRepository(firestore: firestore),
      );
      provider.eliminarCategoria(0);
      provider.agregarCategoria('Snacks');

      final guardado = await provider.guardar('usuario-1');

      expect(guardado, isFalse);
      expect(provider.guardando, isFalse);
      expect(provider.errorValidacion, contains('Hay productos'));
    },
  );

  test('restaura la configuración guardada para editarla', () {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      configuracionInicial: {
        'nombreNegocio': 'Bodega Ana',
        'telefono': '+51999999999',
        'direccion': 'Av. Lima 123 (Ref: Frente al parque)',
        'ruc': '12345678901',
        'facebook': 'https://facebook.com/bodegaana',
        'categorias': ['Bebidas'],
        'unidadesMedida': [
          {
            'nombre': 'Botella',
            'tipo': 'fraccionaria',
            'fraccionesPermitidas': ['0.5'],
            'esOpcional': true,
          },
        ],
        'delivery': true,
        'deliveryZonas': [
          {'zona': 'Centro', 'costo': 7.5},
        ],
        'horarios': [
          {
            'dia': 'Lunes',
            'apertura': '08:00',
            'cierre': '18:00',
            'activo': true,
          },
        ],
        'metodosPago': ['yape'],
        'configPagos': {
          'yape': {
            'numero': '999999999',
            'descuentoActivo': true,
            'tipoDescuento': 'porcentaje',
            'valorDescuento': 10,
            'montoMinimo': 20,
          },
        },
      },
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );

    expect(provider.nombreNegocio, 'Bodega Ana');
    expect(provider.telefono, '999999999');
    expect(provider.direccion, 'Av. Lima 123');
    expect(provider.referencia, 'Frente al parque');
    expect(provider.categorias, ['Bebidas']);
    expect(provider.unidadesMedida.single.nombre, 'Botella');
    expect(provider.tieneDelivery, isTrue);
    expect(provider.zonasDelivery.single.costo, '7.5');
    expect(provider.horarios.single.dia, 'Lunes');
    expect(
      provider.metodosPagoConfig
          .firstWhere((m) => m.metodoId == 'yape')
          .numeroPago,
      '999999999',
    );
  });

  test('con negocioId inyectado guarda sin leer el perfil de users', () async {
    final firestore = FakeFirebaseFirestore();
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
      repository: NegocioRepository(firestore: firestore),
    );
    provider.nombreNegocio = 'Bodega Ana';
    provider.telefono = '999999999';
    provider.direccion = 'Av. Lima 123';
    provider.referencia = 'Frente al parque';

    final guardado = await provider.guardar('usuario-sin-perfil');

    expect(guardado, isTrue);
    expect(provider.guardando, isFalse);
    final perfil = await firestore
        .collection('users')
        .doc('usuario-sin-perfil')
        .get();
    expect(perfil.exists, isFalse);
    final datos =
        (await firestore.collection('negocios').doc('negocio-1').get()).data()!;
    expect(datos['nombreNegocio'], 'Bodega Ana');
    expect(datos['onboardingBusinessRubro'], 'Bodega');
    expect(
      (await firestore
              .collection('negocios_publicos')
              .doc('bodega-ana-9999')
              .get())
          .exists,
      isTrue,
    );
  });

  test(
    'negocioId vacío conserva el fallback y no escribe en rutas incorrectas',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'negocioId': 'negocio-1',
      });
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: '   ',
        repository: NegocioRepository(firestore: firestore),
      );
      provider.nombreNegocio = 'Bodega Ana';
      provider.telefono = '999999999';
      provider.direccion = 'Av. Lima 123';
      provider.referencia = 'Frente al parque';

      final guardado = await provider.guardar('usuario-1');

      expect(guardado, isTrue);
      expect(provider.errorValidacion, isNull);
      final negocios = await firestore.collection('negocios').get();
      expect(negocios.docs, hasLength(1));
      expect(negocios.docs.single.id, 'negocio-1');
    },
  );

  test('valida dependencias con negocioId sin depender del perfil', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('negocios')
        .doc('negocio-1')
        .collection('productos')
        .doc('producto-1')
        .set({'categoria': 'Bebidas'});
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
      configuracionInicial: {
        'nombreNegocio': 'Bodega Ana',
        'telefono': '+51999999999',
        'direccion': 'Av. Lima 123 (Ref: Frente al parque)',
        'categorias': ['Bebidas'],
        'unidadesMedida': [
          {
            'nombre': 'Unidad',
            'tipo': 'entera',
            'fraccionesPermitidas': <String>[],
            'esOpcional': false,
          },
        ],
        'delivery': false,
      },
      repository: NegocioRepository(firestore: firestore),
    );
    provider.eliminarCategoria(0);
    provider.agregarCategoria('Snacks');

    final guardado = await provider.guardar('usuario-sin-perfil');

    expect(guardado, isFalse);
    expect(provider.guardando, isFalse);
    expect(provider.errorValidacion, contains('Hay productos'));
  });

  // ── Catálogo de venta: borrador, presentaciones y medidas ─────────────

  FormatoPresentacion conteo(int valor) => FormatoPresentacion(
    valorBase: valor,
    familia: FamiliaUnidad.conteo,
    unidadVisible: RegistroUnidades.unidad,
  );
  FormatoPresentacion peso(int valorG) => FormatoPresentacion(
    valorBase: valorG,
    familia: FamiliaUnidad.peso,
    unidadVisible: valorG >= 1000 ? RegistroUnidades.kg : RegistroUnidades.g,
  );

  FormatoPresentacion volumen(int valorMl) => FormatoPresentacion(
    valorBase: valorMl,
    familia: FamiliaUnidad.volumen,
    unidadVisible: valorMl >= 1000 ? RegistroUnidades.L : RegistroUnidades.ml,
  );
  ConfiguracionNegocioProvider crearProvider({
    String rubro = 'Bodega',
    String? negocioId,
    Map<String, dynamic>? configuracionInicial,
  }) => ConfiguracionNegocioProvider(
    rubro: rubro,
    negocioId: negocioId,
    configuracionInicial: configuracionInicial,
    repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
  );

  group('catálogo de venta: borrador', () {
    test('siembra el preset del rubro', () {
      final bodega = crearProvider(rubro: 'Bodega');

      expect(bodega.presentaciones, hasLength(6));
      for (final presentacion in bodega.presentaciones) {
        expect(presentacion.obligatoria, isTrue);
        expect(presentacion.activa, isTrue);
      }
      expect(bodega.medidas, hasLength(2));
      expect(bodega.medidaActiva(FamiliaUnidad.peso), isTrue);
      expect(bodega.medidaActiva(FamiliaUnidad.volumen), isTrue);

      final otros = crearProvider(rubro: 'Otros');
      expect(otros.presentaciones, hasLength(6));
      expect(otros.presentacionActiva('unidad'), isTrue);
      expect(otros.presentacionActiva('par'), isFalse);
      expect(otros.medidas, hasLength(4));
      expect(otros.medidaActiva(FamiliaUnidad.peso), isFalse);
    });

    test('restaura un catalogoVenta guardado', () {
      final provider = crearProvider(
        configuracionInicial: {
          'catalogoVenta': {
            'versionEsquema': 1,
            'presentaciones': CatalogoVentaGlobal.nombres.entries
                .take(3)
                .map(
                  (entrada) => {
                    'id': entrada.key,
                    'nombre': entrada.value,
                    'formatos': [
                      {
                        'valorBase': 250,
                        'familia': 'volumen',
                        'unidadVisible': 'ml',
                      },
                    ],
                    'activa': true,
                    'obligatoria': false,
                    'personalizada': false,
                  },
                )
                .toList(),
            'medidas': <Map<String, dynamic>>[],
          },
        },
      );

      expect(provider.catalogoVenta.version, 1);
      expect(provider.presentaciones, hasLength(3));
      expect(provider.presentacionActiva('botella'), isTrue);
      expect(provider.medidas, isEmpty);
    });

    test('catálogo de venta: borrador usa el preset cuando no hay catalogoVenta guardado', () {
      final provider = crearProvider(
        configuracionInicial: {
          'unidadesMedida': [
            {
              'nombre': 'Unidad',
              'tipo': 'entera',
              'fraccionesPermitidas': <String>[],
              'esOpcional': false,
            },
            {
              'nombre': 'L',
              'tipo': 'entera',
              'fraccionesPermitidas': <String>[],
              'esOpcional': false,
            },
            {
              'nombre': 'Docena',
              'tipo': 'fraccionaria',
              'fraccionesPermitidas': ['0.5'],
              'esOpcional': false,
            },
          ],
        },
      );

      // El catálogo proviene del preset, no de la adaptación legacy.
      // Docena ya no genera una medida con requiereRevision.
      expect(provider.presentacionActiva('unidad'), isTrue);
      expect(provider.medidasPendientesRevision, isEmpty);
    });
  });

  group('catálogo de venta: presentaciones', () {
    test('no desactiva presentaciones obligatorias', () {
      final provider = crearProvider(rubro: 'Bodega');

      provider.establecerPresentacionActiva('unidad', activa: false);

      expect(provider.errorCatalogo, contains('obligatoria'));
      expect(provider.presentacionActiva('unidad'), isTrue);
    });

    test('activa y desactiva presentaciones no obligatorias', () {
      final provider = crearProvider(rubro: 'Otros');

      provider.establecerPresentacionActiva('par', activa: true);
      expect(provider.presentacionActiva('par'), isTrue);

      provider.establecerPresentacionActiva('par', activa: false);
      expect(provider.presentacionActiva('par'), isFalse);
      expect(provider.presentacionPorId('par'), isNotNull);
    });

    test('crea presentación personalizada solo en rubros permitidos', () {
      final otros = crearProvider(rubro: 'Otros');
      otros.agregarPresentacionPersonalizada(
        nombre: 'Caja premio',
        formatos: [conteo(1)],
      );

      expect(otros.errorCatalogo, isNull);
      final creada = otros.presentacionPorId('personalizada-1');
      expect(creada, isNotNull);
      expect(creada!.nombre, 'Caja premio');
      expect(creada.personalizada, isTrue);
      expect(creada.activa, isTrue);

      final bodega = crearProvider(rubro: 'Bodega');
      bodega.agregarPresentacionPersonalizada(
        nombre: 'Caja premio',
        formatos: [conteo(1)],
      );
      expect(bodega.errorCatalogo, contains('no admite'));
      expect(bodega.presentaciones, hasLength(6));
    });

    test('rechaza personalizada con nombre duplicado', () {
      final provider = crearProvider(rubro: 'Otros');
      provider.agregarPresentacionPersonalizada(
        nombre: 'Bolsa grande',
        formatos: [conteo(1)],
      );
      provider.limpiarErrorCatalogo();

      provider.agregarPresentacionPersonalizada(
        nombre: ' bolsa grande ',
        formatos: [conteo(1)],
      );

      expect(
        provider.errorCatalogo,
        'Ya existe una presentación con ese nombre.',
      );
      expect(provider.presentaciones, hasLength(7));
    });

    test('renombra solo presentaciones personalizadas', () {
      final provider = crearProvider(rubro: 'Otros');
      provider.agregarPresentacionPersonalizada(
        nombre: 'Bolsa grande',
        formatos: [conteo(1)],
      );

      provider.renombrarPresentacion('personalizada-1', 'Bolsa familiar');
      expect(
        provider.presentacionPorId('personalizada-1')!.nombre,
        'Bolsa familiar',
      );

      provider.limpiarErrorCatalogo();
      provider.renombrarPresentacion('unidad', 'Unidades');
      expect(provider.errorCatalogo, contains('personalizadas'));
      expect(provider.presentacionPorId('unidad')!.nombre, 'Unidad');
    });

    test('agrega formato permitido y rechaza duplicados equivalentes', () {
      final provider = crearProvider(rubro: 'Bodega');
      final botellaInicial = provider
          .presentacionPorId('botella')!
          .formatos
          .length;

      provider.agregarFormato('botella', volumen(100));
      expect(provider.errorCatalogo, isNull);
      expect(
        provider.presentacionPorId('botella')!.formatos,
        hasLength(botellaInicial + 1),
      );

      provider.limpiarErrorCatalogo();
      provider.agregarFormato('botella', volumen(1000));
      expect(provider.errorCatalogo, contains('ya es un formato'));
    });

    test('rechaza formatos fuera del catálogo global', () {
      final provider = crearProvider(rubro: 'Bodega');

      provider.agregarFormato('botella', peso(250));

      expect(provider.errorCatalogo, contains('no está permitido'));
    });

    test('elimina formatos pero nunca el último', () {
      final provider = crearProvider(rubro: 'Bodega');
      final botella = provider.presentacionPorId('botella')!;
      final sin3000 = botella.formatos
          .where((f) => f.valorBase != 3000)
          .toList();

      provider.eliminarFormato('botella', volumen(3000));
      expect(
        provider.presentacionPorId('botella')!.formatos,
        hasLength(sin3000.length),
      );

      provider.limpiarErrorCatalogo();
      provider.eliminarFormato('unidad', conteo(1));
      expect(provider.errorCatalogo, contains('único formato'));
      expect(provider.presentacionPorId('unidad')!.formatos, hasLength(1));
    });

    test('no elimina presentaciones obligatorias y sí el resto', () {
      final provider = crearProvider(rubro: 'Otros');

      provider.eliminarPresentacion('unidad');
      expect(provider.errorCatalogo, contains('obligatoria'));
      expect(provider.presentacionPorId('unidad'), isNotNull);

      provider.limpiarErrorCatalogo();
      provider.eliminarPresentacion('par');
      expect(provider.errorCatalogo, isNull);
      expect(provider.presentacionPorId('par'), isNull);

      provider.agregarPresentacionPersonalizada(
        nombre: 'Extra',
        formatos: [conteo(1)],
      );
      provider.eliminarPresentacion('personalizada-1');
      expect(provider.presentacionPorId('personalizada-1'), isNull);
    });
  });

  group('catálogo de venta: medidas', () {
    test('activa y desactiva una medida', () {
      final provider = crearProvider(rubro: 'Bodega');

      provider.establecerMedidaActiva(FamiliaUnidad.peso, activa: false);
      expect(provider.medidaActiva(FamiliaUnidad.peso), isFalse);

      provider.establecerMedidaActiva(FamiliaUnidad.peso, activa: true);
      expect(provider.medidaActiva(FamiliaUnidad.peso), isTrue);
    });

    test('edita el mínimo y exige que sea positivo', () {
      final provider = crearProvider(rubro: 'Bodega');

      // Subir el mínimo exige primero acomodar las cantidades rápidas.
      provider.editarCantidadesRapidasBase(FamiliaUnidad.peso, [300, 400, 500]);
      provider.editarMinimoBase(FamiliaUnidad.peso, 300);
      expect(provider.medidaDe(FamiliaUnidad.peso)!.minimoBase, 300);

      provider.limpiarErrorCatalogo();
      provider.editarMinimoBase(FamiliaUnidad.peso, 0);
      expect(provider.errorCatalogo, contains('mínimo'));
      expect(provider.medidaDe(FamiliaUnidad.peso)!.minimoBase, 300);
    });

    test('valida cantidades rápidas contra mínimo e incremento', () {
      final provider = crearProvider(rubro: 'Bodega');

      provider.editarCantidadesRapidasBase(FamiliaUnidad.peso, [100, 200, 400]);
      expect(provider.medidaDe(FamiliaUnidad.peso)!.cantidadesRapidasBase, [
        100,
        200,
        400,
      ]);

      provider.limpiarErrorCatalogo();
      provider.editarCantidadesRapidasBase(FamiliaUnidad.peso, [10]);
      expect(provider.errorCatalogo, contains('menor al mínimo'));

      provider.limpiarErrorCatalogo();
      provider.editarCantidadesRapidasBase(FamiliaUnidad.peso, [120]);
      expect(provider.errorCatalogo, contains('incremento'));
    });

    test('exige venta por cantidad o por monto', () {
      final provider = crearProvider(rubro: 'Bodega');

      provider.establecerPermiteCantidad(FamiliaUnidad.peso, permite: false);
      expect(provider.errorCatalogo, isNull);
      expect(provider.medidaDe(FamiliaUnidad.peso)!.permiteCantidad, isFalse);

      provider.establecerPermiteMonto(FamiliaUnidad.peso, permite: false);
      expect(provider.errorCatalogo, contains('cantidad o por monto'));
      expect(provider.medidaDe(FamiliaUnidad.peso)!.permiteMonto, isTrue);
    });

    test('edita la unidad habitual de una medida', () {
      final provider = crearProvider(rubro: 'Bodega');
      expect(provider.medidaDe(FamiliaUnidad.peso)!.unidadVisual, isNotNull);

      provider.editarUnidadVisual(FamiliaUnidad.peso, RegistroUnidades.g);
      expect(
        provider.medidaDe(FamiliaUnidad.peso)!.unidadVisual,
        RegistroUnidades.g,
      );
      expect(provider.errorCatalogo, isNull);

      provider.editarUnidadVisual(FamiliaUnidad.peso, RegistroUnidades.kg);
      expect(
        provider.medidaDe(FamiliaUnidad.peso)!.unidadVisual,
        RegistroUnidades.kg,
      );
    });

    test('rechaza una unidad habitual fuera de la familia', () {
      final provider = crearProvider(rubro: 'Bodega');

      provider.editarUnidadVisual(FamiliaUnidad.peso, RegistroUnidades.L);
      expect(provider.errorCatalogo, contains('no pertenece a la familia'));
      expect(
        provider.medidaDe(FamiliaUnidad.peso)!.unidadVisual,
        isNot(RegistroUnidades.L),
      );
    });

    test('no edita medidas sin familia resuelta', () {
      final provider = crearProvider(
        rubro: 'Ropa',
        configuracionInicial: {
          'unidadesMedida': [
            {
              'nombre': 'Docena',
              'tipo': 'fraccionaria',
              'fraccionesPermitidas': ['0.5'],
              'esOpcional': false,
            },
          ],
        },
      );

      provider.editarMinimoBase(FamiliaUnidad.peso, 100);

      expect(provider.errorCatalogo, contains('No hay una medida'));
    });

    test('guardar persiste el borrador editado del catálogo', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        repository: NegocioRepository(firestore: firestore),
      );
      provider.nombreNegocio = 'Bodega Ana';
      provider.telefono = '999999999';
      provider.direccion = 'Av. Lima 123';
      provider.referencia = 'Frente al parque';
      provider.editarCantidadesRapidasBase(FamiliaUnidad.peso, [300, 400, 600]);
      provider.editarMinimoBase(FamiliaUnidad.peso, 300);

      final guardado = await provider.guardar('usuario-sin-perfil');

      expect(guardado, isTrue);
      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      final medidasGuardadas =
          (datos['catalogoVenta'] as Map)['medidas'] as List;
      final pesoGuardado = (medidasGuardadas
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['id'] == 'peso'));
      expect(pesoGuardado['minimoBase'], 300);
      expect(pesoGuardado['cantidadesRapidasBase'], [300, 400, 600]);
    });

    test('bloquea guardar si quedan medidas pendientes de revisión', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'nombreNegocio': 'Bodega Ana',
          'telefono': '+51999999999',
          'direccion': 'Av. Lima 123 (Ref: Frente al parque)',
          'catalogoVenta': {
            'versionEsquema': 1,
            'presentaciones': <Map<String, dynamic>>[],
            'medidas': [
              {
                'id': 'docena',
                'nombre': 'Docena',
                'minimoBase': 0,
                'incrementoBase': 0,
                'cantidadesRapidasBase': <int>[],
                'permiteCantidad': true,
                'permiteMonto': false,
                'activa': false,
                'obligatoria': false,
                'requiereRevision': true,
              },
            ],
          },
          'delivery': false,
        },
        repository: NegocioRepository(firestore: firestore),
      );

      final guardado = await provider.guardar('usuario-sin-perfil');

      expect(guardado, isFalse);
      expect(provider.guardando, isFalse);
      expect(provider.errorValidacion, isNotNull);
      expect(provider.errorValidacion, contains('Docena'));
      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data();
      expect(datos, isNull);
    });

    test(
      'round-trip: una segunda lectura refleja la edición guardada, no el preset',
      () async {
        final firestore = FakeFirebaseFirestore();
        final primer = ConfiguracionNegocioProvider(
          rubro: 'Bodega',
          negocioId: 'negocio-1',
          repository: NegocioRepository(firestore: firestore),
        );
        primer.nombreNegocio = 'Bodega Ana';
        primer.telefono = '999999999';
        primer.direccion = 'Av. Lima 123';
        primer.referencia = 'Frente al parque';
        primer
          ..editarCantidadesRapidasBase(FamiliaUnidad.peso, [300, 400, 600])
          ..editarMinimoBase(FamiliaUnidad.peso, 300)
          ..editarIncrementoBase(FamiliaUnidad.peso, 100);

        expect(await primer.guardar('usuario-sin-perfil'), isTrue);

        final datos =
            (await firestore.collection('negocios').doc('negocio-1').get())
                .data()!;
        final releido = ConfiguracionNegocioProvider(
          rubro: 'Bodega',
          negocioId: 'negocio-1',
          configuracionInicial: datos,
          repository: NegocioRepository(firestore: firestore),
        );
        final pesoReleido = releido.medidaDe(FamiliaUnidad.peso)!;
        expect(pesoReleido.minimoBase, 300);
        expect(pesoReleido.incrementoBase, 100);
        expect(pesoReleido.cantidadesRapidasBase, [300, 400, 600]);

        final presetPeso = PresetsVenta.obtener(
          'Bodega',
        ).medidaDe(FamiliaUnidad.peso)!;
        expect(pesoReleido.minimoBase, isNot(presetPeso.minimoBase));
        expect(pesoReleido.incrementoBase, isNot(presetPeso.incrementoBase));
        expect(
          pesoReleido.cantidadesRapidasBase,
          isNot(presetPeso.cantidadesRapidasBase),
        );
      },
    );
  });
}
