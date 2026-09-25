import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_global.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/negocio/domain/models/categoria_personalizada.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

/// Repository que falla al escribir, para comprobar que un error de red no
/// llega a la memoria del provider.
class RepositoryQueFalla extends NegocioRepository {
  RepositoryQueFalla(FirebaseFirestore instancia) : super(firestore: instancia);

  @override
  Future<void> guardarCategoriasPersonalizadas(
    String uid,
    List<CategoriaPersonalizada> categorias, {
    String? negocioId,
  }) async {
    throw StateError('sin conexión');
  }
}

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

    // ═════════════════════════════════════════════════════════
    // Regresión: cambio de rubro en el provider
    // ═════════════════════════════════════════════════════════

    group('cambio de rubro: regresión en el provider', () {
      test(
        'Restaurante → Accesorios y regalos: catálogo final solo tiene '
        'presentaciones del preset Accesorios',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = NegocioRepository(firestore: firestore);

          // 1. Crear negocio con rubro Restaurante
          await firestore.collection('users').doc('usuario-1').set({
            'email': 'test@example.com',
            'negocioId': 'negocio-1',
          });
          await firestore.collection('negocios').doc('negocio-1').set({
            'propietarioUid': 'usuario-1',
            'rubro': 'Restaurante',
            'nombreNegocio': 'Restaurante Test',
            'categorias': ['Entradas', 'Platos principales', 'Bebidas'],
            'unidadesMedida': [
              {'nombre': 'Unidad', 'tipo': 'entera', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
            ],
            'catalogoVenta': CatalogoVentaPersistido.desdePreset(
              PresetsVenta.obtener('Restaurante'),
            ).toMap(),
            'webActiva': true,
            'delivery': false,
            'telefono': '+51999999999',
            'direccion': 'Av. Lima 123',
            'slug': 'restaurante-test',
          });

          // 2. Ejecutar guardarRubro("Accesorios y regalos")
          await repository.guardarRubro('usuario-1', 'Accesorios y regalos');

          // 3. Leer el documento resultante
          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data()!;

          // 4. Construir ConfiguracionNegocioProvider con el documento
          final provider = ConfiguracionNegocioProvider(
            rubro: 'Accesorios y regalos',
            configuracionInicial: datos,
            repository: repository,
          );

          // 5. Verificar el catálogo FINAL del provider
          final idsPresentaciones =
              provider.catalogoVenta.presentaciones.map((p) => p.id).toSet();

          // Par → existe, Set → existe, Juego → existe
          expect(idsPresentaciones, contains('par'));
          expect(idsPresentaciones, contains('set'));
          expect(idsPresentaciones, contains('juego'));

          // Porción, Plato, Combo → NO existen
          expect(idsPresentaciones, isNot(contains('porcion')));
          expect(idsPresentaciones, isNot(contains('plato')));
          expect(idsPresentaciones, isNot(contains('combo')));

          // Las medidas deben coincidir con el preset actual de Accesorios
          final preset = PresetsVenta.obtener('Accesorios y regalos');
          expect(provider.medidas, hasLength(preset.medidas.length));
        },
      );

      test(
        'Bodega → Ropa: catálogo final únicamente el de Ropa',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = NegocioRepository(firestore: firestore);

          await firestore.collection('users').doc('usuario-1').set({
            'email': 'test@example.com',
            'negocioId': 'negocio-1',
          });
          await firestore.collection('negocios').doc('negocio-1').set({
            'propietarioUid': 'usuario-1',
            'rubro': 'Bodega',
            'nombreNegocio': 'Bodega Test',
            'categorias': ['Abarrotes', 'Bebidas'],
            'unidadesMedida': [
              {'nombre': 'Unidad', 'tipo': 'entera', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
            ],
            'catalogoVenta': CatalogoVentaPersistido.desdePreset(
              PresetsVenta.obtener('Bodega'),
            ).toMap(),
            'webActiva': true,
            'delivery': false,
            'telefono': '+51999999999',
            'direccion': 'Av. Lima 123',
            'slug': 'bodega-test',
          });

          // Cambiar rubro a Ropa
          await repository.guardarRubro('usuario-1', 'Ropa');

          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data()!;

          final provider = ConfiguracionNegocioProvider(
            rubro: 'Ropa',
            configuracionInicial: datos,
            repository: repository,
          );

          final idsPresentaciones =
              provider.catalogoVenta.presentaciones.map((p) => p.id).toSet();

          // Solo presentaciones de Ropa
          expect(idsPresentaciones, contains('unidad'));
          expect(idsPresentaciones, contains('par'));
          expect(idsPresentaciones, contains('conjunto'));
          expect(idsPresentaciones, contains('caja'));
          expect(idsPresentaciones, contains('paquete'));
          expect(idsPresentaciones, contains('bolsa'));

          // NO debe tener presentaciones de Bodega ni Restaurante
          expect(idsPresentaciones, isNot(contains('botella')));
          expect(idsPresentaciones, isNot(contains('lata')));
          expect(idsPresentaciones, isNot(contains('porcion')));
          expect(idsPresentaciones, isNot(contains('plato')));
          expect(idsPresentaciones, isNot(contains('combo')));

          // Solo Ropa: longitud medida (inactiva)
          final preset = PresetsVenta.obtener('Ropa');
          expect(provider.medidas, hasLength(preset.medidas.length));
        },
      );

      test(
        'Bodega → Bodega (mismo rubro): catalogoVenta se conserva en el provider',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = NegocioRepository(firestore: firestore);

          await firestore.collection('users').doc('usuario-1').set({
            'email': 'test@example.com',
            'negocioId': 'negocio-1',
          });

          final catalogoOriginal = CatalogoVentaPersistido.desdePreset(
            PresetsVenta.obtener('Bodega'),
          );
          await firestore.collection('negocios').doc('negocio-1').set({
            'propietarioUid': 'usuario-1',
            'rubro': 'Bodega',
            'catalogoVenta': catalogoOriginal.toMap(),
          });

          // rubro NO cambia
          await repository.guardarRubro('usuario-1', 'Bodega');

          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data()!;

          final provider = ConfiguracionNegocioProvider(
            rubro: 'Bodega',
            configuracionInicial: datos,
            repository: repository,
          );

          // catalogoVenta debe conservarse
          expect(provider.catalogoVenta.presentaciones, isNotEmpty);
        },
      );

      test(
        'Al cambiar rubro, el provider reconstruye todo desde el nuevo preset',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = NegocioRepository(firestore: firestore);

          await firestore.collection('users').doc('usuario-1').set({
            'email': 'test@example.com',
            'negocioId': 'negocio-1',
          });
          await firestore.collection('negocios').doc('negocio-1').set({
            'propietarioUid': 'usuario-1',
            'rubro': 'Restaurante',
            'categorias': ['Entradas', 'Platos principales', 'Bebidas'],
            'unidadesMedida': [
              {'nombre': 'Presentación propia', 'tipo': 'entera', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
            ],
            'catalogoVenta': CatalogoVentaPersistido.desdePreset(
              PresetsVenta.obtener('Restaurante'),
            ).toMap(),
            'delivery': false,
            'telefono': '+51999999999',
            'direccion': 'Av. Lima 123',
            'slug': 'test',
          });

          // Cambiar rubro con repository.guardarRubro
          await repository.guardarRubro('usuario-1', 'Accesorios y regalos');

          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data()!;

          // Verificar que el documento no contiene datos del rubro anterior
          expect(datos['categorias'], isNull);
          expect(datos['unidadesMedida'], isNull);

          final provider = ConfiguracionNegocioProvider(
            rubro: 'Accesorios y regalos',
            configuracionInicial: datos,
            repository: repository,
          );

          // El provider usa el preset de Accesorios y regalos
          final preset = PresetsVenta.obtener('Accesorios y regalos');
          expect(provider.categorias, preset.categorias);
          expect(provider.medidas, hasLength(preset.medidas.length));

          // No contiene categorías de Restaurante
          expect(provider.categorias, isNot(contains('Entradas')));
          expect(provider.categorias, isNot(contains('Platos principales')));
          expect(provider.categorias, isNot(contains('Bebidas')));
        },
      );

      test(
        'Bodega → Ropa: provider usa exclusivamente el preset de Ropa',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = NegocioRepository(firestore: firestore);

          await firestore.collection('users').doc('usuario-1').set({
            'email': 'test@example.com',
            'negocioId': 'negocio-1',
          });
          await firestore.collection('negocios').doc('negocio-1').set({
            'propietarioUid': 'usuario-1',
            'rubro': 'Bodega',
            'nombreNegocio': 'Bodega Test',
            'categorias': ['Abarrotes', 'Bebidas'],
            'unidadesMedida': [
              {'nombre': 'Unidad', 'tipo': 'entera', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
            ],
            'catalogoVenta': CatalogoVentaPersistido.desdePreset(
              PresetsVenta.obtener('Bodega'),
            ).toMap(),
            'webActiva': true,
            'delivery': false,
            'telefono': '+51999999999',
            'direccion': 'Av. Lima 123',
            'slug': 'bodega-test',
          });

          await repository.guardarRubro('usuario-1', 'Ropa');

          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data()!;

          expect(datos['categorias'], isNull);
          expect(datos['unidadesMedida'], isNull);

          final provider = ConfiguracionNegocioProvider(
            rubro: 'Ropa',
            configuracionInicial: datos,
            repository: repository,
          );

          final preset = PresetsVenta.obtener('Ropa');
          expect(provider.categorias, preset.categorias);
          expect(provider.medidas, hasLength(preset.medidas.length));

          // Solo presentaciones de Ropa
          final idsPresentaciones =
              provider.catalogoVenta.presentaciones.map((p) => p.id).toSet();
          expect(idsPresentaciones, contains('unidad'));
          expect(idsPresentaciones, contains('par'));
          expect(idsPresentaciones, contains('conjunto'));
          expect(idsPresentaciones, contains('caja'));
          expect(idsPresentaciones, contains('paquete'));
          expect(idsPresentaciones, contains('bolsa'));

          // Nada de Bodega
          expect(idsPresentaciones, isNot(contains('botella')));
          expect(idsPresentaciones, isNot(contains('lata')));
          expect(idsPresentaciones, isNot(contains('porcion')));
        },
      );

      test(
        'Mismo rubro: provider conserva categorias y unidadesMedida del documento',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repository = NegocioRepository(firestore: firestore);

          await firestore.collection('users').doc('usuario-1').set({
            'email': 'test@example.com',
            'negocioId': 'negocio-1',
          });
          await firestore.collection('negocios').doc('negocio-1').set({
            'propietarioUid': 'usuario-1',
            'rubro': 'Bodega',
            'categorias': ['Mis Abarrotes', 'Mis Bebidas'],
            'unidadesMedida': [
              {'nombre': 'MiUnidad', 'tipo': 'entera', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
            ],
            'catalogoVenta': CatalogoVentaPersistido.desdePreset(
              PresetsVenta.obtener('Bodega'),
            ).toMap(),
            // Ya completado: guardarRubro con el mismo rubro es un no-op
            // (early return) y no debe invalidar nada.
            'onboardingRubroCompletedAt': Timestamp.fromDate(
              DateTime(2024),
            ),
          });

          // rubro NO cambia
          await repository.guardarRubro('usuario-1', 'Bodega');

          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data()!;

          expect(datos['categorias'], ['Mis Abarrotes', 'Mis Bebidas']);
          expect(datos['unidadesMedida'], isNotNull);

          final provider = ConfiguracionNegocioProvider(
            rubro: 'Bodega',
            configuracionInicial: datos,
            repository: repository,
          );

          // Personalizaciones del usuario se conservan
          expect(provider.categorias, ['Mis Abarrotes', 'Mis Bebidas']);
          expect(provider.unidadesMedida.map((u) => u.nombre), contains('MiUnidad'));
        },
      );
    });

  group('categorías personalizadas: carga de solo lectura', () {

    test('carga las personalizadas guardadas en la configuración', () {
      final provider = crearProvider(
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'bebidas caseras', 'nombre': 'Bebidas Caseras', 'activa': true},
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': false},
          ],
        },
      );

      expect(provider.categoriasPersonalizadas, [
        const CategoriaPersonalizada(
          clave: 'bebidas caseras',
          nombre: 'Bebidas Caseras',
        ),
        const CategoriaPersonalizada(
          clave: 'dulces',
          nombre: 'Dulces',
          activa: false,
        ),
      ]);
    });

    test('sin datos guardados la lista queda vacía', () {
      final sinCampo = crearProvider(
        configuracionInicial: {'nombreNegocio': 'Bodega Ana'},
      );
      final conCampoVacio = crearProvider(
        configuracionInicial: {'categoriasPersonalizadas': null},
      );
      final nuevo = crearProvider();

      expect(sinCampo.categoriasPersonalizadas, isEmpty);
      expect(conCampoVacio.categoriasPersonalizadas, isEmpty);
      expect(nuevo.categoriasPersonalizadas, isEmpty);
    });

    test('el getter no permite modificar el estado interno', () {
      final provider = crearProvider(
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
      );

      expect(
        () => provider.categoriasPersonalizadas.add(
          const CategoriaPersonalizada(clave: 'salas', nombre: 'Salas'),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => provider.categoriasPersonalizadas.clear(),
        throwsUnsupportedError,
      );

      expect(provider.categoriasPersonalizadas.map((c) => c.clave), ['dulces']);
    });
  });

  group('categorías personalizadas: crear', () {
    ConfiguracionNegocioProvider crear({
      String? negocioId,
      List<Map<String, dynamic>> guardadas = const [],
    }) => ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: negocioId,
      configuracionInicial: {'categoriasPersonalizadas': guardadas},
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );

    test('agrega la categoría con su clave canónica y activa', () async {
      final provider = crear(negocioId: 'negocio-1');

      final agregado = await provider.agregarCategoriaPersonalizada(
        'usuario-1',
        '  Bebidas Caseras  ',
      );

      expect(agregado, isTrue);
      expect(provider.categoriasPersonalizadas, [
        const CategoriaPersonalizada(
          clave: 'bebidas caseras',
          nombre: 'Bebidas Caseras',
        ),
      ]);
    });

    test('rechaza una clave duplicada sin tocar el estado', () async {
      final provider = crear(negocioId: 'negocio-1', guardadas: [
        {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
      ]);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final agregado = await provider.agregarCategoriaPersonalizada(
        'usuario-1',
        'DULCES',
      );

      expect(agregado, isFalse);
      expect(provider.errorCatalogo, contains('Ya existe'));
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), ['dulces']);
      expect(notificaciones, 0);
    });

    test('rechaza un nombre vacío', () async {
      final provider = crear(negocioId: 'negocio-1');
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final agregado = await provider.agregarCategoriaPersonalizada(
        'usuario-1',
        '   ',
      );

      expect(agregado, isFalse);
      expect(provider.errorCatalogo, contains('no puede estar vacío'));
      expect(provider.categoriasPersonalizadas, isEmpty);
      expect(notificaciones, 0);
    });

    test('persiste la lista y notifica una sola vez', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final agregado = await provider.agregarCategoriaPersonalizada(
        'usuario-1',
        'Salas',
      );

      expect(agregado, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'dulces',
        'salas',
      ]);

      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
        {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
      ]);
    });
  });

  group('categorías personalizadas: desactivar', () {
    test('desactiva conservando clave y nombre, y persiste', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
            {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final desactivada = await provider.desactivarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
      );

      expect(desactivada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      // Sigue en la lista: desactivar oculta, no elimina.
      expect(provider.categoriasPersonalizadas, [
        const CategoriaPersonalizada(
          clave: 'dulces',
          nombre: 'Dulces',
          activa: false,
        ),
        const CategoriaPersonalizada(clave: 'salas', nombre: 'Salas'),
      ]);

      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'dulces', 'nombre': 'Dulces', 'activa': false},
        {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
      ]);
    });

    test('una categoría inexistente no cambia nada', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final desactivada = await provider.desactivarCategoriaPersonalizada(
        'usuario-1',
        'inexistente',
      );

      expect(desactivada, isFalse);
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.map((c) => c.activa), [true]);
      // Tampoco escribe: el documento no se crea por un intento imposible.
      final documento = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .get();
      expect(documento.exists, isFalse);
    });

    test('un fallo de persistencia conserva el estado anterior', () async {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
        repository: RepositoryQueFalla(FakeFirebaseFirestore()),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final desactivada = await provider.desactivarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
      );

      expect(desactivada, isFalse);
      expect(provider.errorCatalogo, contains('No se pudo desactivar'));
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.single.activa, isTrue);
    });
  });

  group('categorías personalizadas: reactivar', () {
    test('reactiva conservando clave y nombre, y persiste', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': false},
            {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final reactivada = await provider.reactivarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
      );

      expect(reactivada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      // Reactivar no renombra ni resucita: solo cambia `activa`.
      expect(provider.categoriasPersonalizadas, [
        const CategoriaPersonalizada(clave: 'dulces', nombre: 'Dulces'),
        const CategoriaPersonalizada(clave: 'salas', nombre: 'Salas'),
      ]);

      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
        {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
      ]);
    });

    test('una categoría inexistente no cambia nada', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': false},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final reactivada = await provider.reactivarCategoriaPersonalizada(
        'usuario-1',
        'inexistente',
      );

      expect(reactivada, isFalse);
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.single.activa, isFalse);
      // Tampoco escribe: el documento no se crea por un intento imposible.
      final documento = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .get();
      expect(documento.exists, isFalse);
    });

    test('un fallo de persistencia conserva activa: false', () async {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': false},
          ],
        },
        repository: RepositoryQueFalla(FakeFirebaseFirestore()),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final reactivada = await provider.reactivarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
      );

      expect(reactivada, isFalse);
      expect(provider.errorCatalogo, contains('No se pudo reactivar'));
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.single.activa, isFalse);
    });
  });

  group('categorías personalizadas: renombrar', () {
    test('renombra conservando clave y estado, y persiste', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': false},
            {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
        '  Golosinas  ',
      );

      expect(renombrada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      // La etiqueta cambia; la identidad y el estado no. Renombrar una
      // categoría desactivada no la reactiva.
      expect(provider.categoriasPersonalizadas, [
        const CategoriaPersonalizada(
          clave: 'dulces',
          nombre: 'Golosinas',
          activa: false,
        ),
        const CategoriaPersonalizada(clave: 'salas', nombre: 'Salas'),
      ]);

      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'dulces', 'nombre': 'Golosinas', 'activa': false},
        {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
      ]);
    });

    test('rechaza un nombre vacío', () async {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
        '   ',
      );

      expect(renombrada, isFalse);
      expect(provider.errorCatalogo, contains('no puede estar vacío'));
      expect(provider.categoriasPersonalizadas.single.nombre, 'Dulces');
      expect(notificaciones, 0);
    });

    test('rechaza un nombre que colisiona con otra categoría', () async {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
            {'clave': 'salas', 'nombre': 'Salas', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      // Canónicamente igual a "salas" aunque se escriba distinto.
      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
        '  SALAS ',
      );

      expect(renombrada, isFalse);
      expect(provider.errorCatalogo, contains('Ya existe'));
      expect(
        provider.categoriasPersonalizadas.map((c) => c.nombre),
        ['Dulces', 'Salas'],
      );
      expect(notificaciones, 0);
    });

    test('una categoría inexistente no cambia nada', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'inexistente',
        'Otro nombre',
      );

      expect(renombrada, isFalse);
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.single.nombre, 'Dulces');
      final documento = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .get();
      expect(documento.exists, isFalse);
    });

    test('un fallo de persistencia conserva el nombre anterior', () async {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'dulces', 'nombre': 'Dulces', 'activa': true},
          ],
        },
        repository: RepositoryQueFalla(FakeFirebaseFirestore()),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'dulces',
        'Golosinas',
      );

      expect(renombrada, isFalse);
      expect(provider.errorCatalogo, contains('No se pudo renombrar'));
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.single.nombre, 'Dulces');
    });
  });

  group('categorías personalizadas: renombrar con productos', () {
    Future<FirebaseFirestore> firestoreConProductos(
      List<Map<String, dynamic>> productos,
    ) async {
      final firestore = FakeFirebaseFirestore();
      for (final (indice, producto) in productos.indexed) {
        await firestore
            .collection('negocios')
            .doc('negocio-1')
            .collection('productos')
            .doc('producto-$indice')
            .set(producto);
      }
      return firestore;
    }

    ConfiguracionNegocioProvider crearProvider(
      FirebaseFirestore firestore, {
      bool activa = true,
    }) => ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
      configuracionInicial: {
        'categoriasPersonalizadas': [
          {'clave': 'mascotas', 'nombre': 'Mascotas', 'activa': activa},
        ],
      },
      repository: NegocioRepository(firestore: firestore),
    );

    test('bloquea el renombrado si un producto usa la categoría', () async {
      final firestore = await firestoreConProductos([
        {'nombre': 'Arena para gato', 'categoria': 'Mascotas'},
      ]);
      final provider = crearProvider(firestore);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
        'Animales',
      );

      expect(renombrada, isFalse);
      expect(provider.errorCatalogo, contains('Hay productos'));
      expect(provider.errorCatalogo, contains('Mascotas'));
      // Sigue llamándose Mascotas, con su clave intacta.
      expect(provider.categoriasPersonalizadas.single.nombre, 'Mascotas');
      expect(provider.categoriasPersonalizadas.single.clave, 'mascotas');
    });

    test('al bloquear no persiste ni notifica', () async {
      final firestore = await firestoreConProductos([
        {'nombre': 'Arena para gato', 'categoria': 'Mascotas'},
      ]);
      final provider = crearProvider(firestore);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
        'Animales',
      );

      expect(notificaciones, 0);
      // No se escribió categoriasPersonalizadas y el producto quedó intacto.
      final documento = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .get();
      expect(documento.data()?['categoriasPersonalizadas'], isNull);
      final productos = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .collection('productos')
          .get();
      expect(productos.docs.single.data(), {
        'nombre': 'Arena para gato',
        'categoria': 'Mascotas',
      });
    });

    test('sin productos dependientes renombra conservando clave y activa', () async {
      // Hay productos, pero de otra categoría: la comprobación es por
      // categoría, no "si el negocio tiene productos".
      final firestore = await firestoreConProductos([
        {'nombre': 'Leche', 'categoria': 'Importados'},
      ]);
      final provider = crearProvider(firestore, activa: false);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final renombrada = await provider.renombrarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
        'Animales',
      );

      expect(renombrada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      expect(provider.categoriasPersonalizadas, [
        const CategoriaPersonalizada(
          clave: 'mascotas',
          nombre: 'Animales',
          activa: false,
        ),
      ]);
      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'mascotas', 'nombre': 'Animales', 'activa': false},
      ]);
    });
  });

  group('categorías personalizadas: eliminar', () {
    test('elimina solo esa categoría y persiste', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'mascotas', 'nombre': 'Mascotas', 'activa': true},
            {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);
      final categoriasDelPreset = provider.categorias;

      final eliminada = await provider.eliminarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
      );

      expect(eliminada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'importados',
      ]);

      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
      ]);
      // Las categorías del preset no se tocan.
      expect(provider.categorias, categoriasDelPreset);
    });

    test('elimina también una categoría inactiva', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'mascotas', 'nombre': 'Mascotas', 'activa': false},
            {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );

      final eliminada = await provider.eliminarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
      );

      // Desactivar no blindaba contra eliminar: son operaciones distintas.
      expect(eliminada, isTrue);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'importados',
      ]);
      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
      ]);
    });

    test('una categoría inexistente no cambia nada', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'mascotas', 'nombre': 'Mascotas', 'activa': true},
          ],
        },
        repository: NegocioRepository(firestore: firestore),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final eliminada = await provider.eliminarCategoriaPersonalizada(
        'usuario-1',
        'inexistente',
      );

      expect(eliminada, isFalse);
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'mascotas',
      ]);
      final documento = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .get();
      expect(documento.exists, isFalse);
    });

    test('un fallo de persistencia conserva la categoría', () async {
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        negocioId: 'negocio-1',
        configuracionInicial: {
          'categoriasPersonalizadas': [
            {'clave': 'mascotas', 'nombre': 'Mascotas', 'activa': true},
            {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
          ],
        },
        repository: RepositoryQueFalla(FakeFirebaseFirestore()),
      );
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final eliminada = await provider.eliminarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
      );

      expect(eliminada, isFalse);
      expect(provider.errorCatalogo, contains('No se pudo eliminar'));
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'mascotas',
        'importados',
      ]);
    });
  });

  group('categorías personalizadas: eliminar con productos', () {
    Future<FirebaseFirestore> firestoreConProductos({
      required List<Map<String, dynamic>> productos,
    }) async {
      final firestore = FakeFirebaseFirestore();
      for (final (indice, producto) in productos.indexed) {
        await firestore
            .collection('negocios')
            .doc('negocio-1')
            .collection('productos')
            .doc('producto-$indice')
            .set(producto);
      }
      return firestore;
    }

    ConfiguracionNegocioProvider crearProvider(FirebaseFirestore firestore) =>
        ConfiguracionNegocioProvider(
          rubro: 'Bodega',
          negocioId: 'negocio-1',
          configuracionInicial: {
            'categoriasPersonalizadas': [
              {'clave': 'mascotas', 'nombre': 'Mascotas', 'activa': true},
              {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
            ],
          },
          repository: NegocioRepository(firestore: firestore),
        );

    test('bloquea si un producto usa la categoría', () async {
      final firestore = await firestoreConProductos(productos: [
        {'nombre': 'Arena para gato', 'categoria': 'Mascotas'},
      ]);
      final provider = crearProvider(firestore);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final eliminada = await provider.eliminarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
      );

      expect(eliminada, isFalse);
      expect(provider.errorCatalogo, contains('Hay productos'));
      expect(provider.errorCatalogo, contains('Mascotas'));
      // Ni notifica, ni elimina, ni escribe.
      expect(notificaciones, 0);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'mascotas',
        'importados',
      ]);
      final documento = await firestore
          .collection('negocios')
          .doc('negocio-1')
          .get();
      expect(documento.data()?['categoriasPersonalizadas'], isNull);
    });

    test('elimina si ningún producto usa la categoría', () async {
      // Hay productos, pero de otra categoría: la comprobación es por
      // categoría, no "si el negocio tiene productos".
      final firestore = await firestoreConProductos(productos: [
        {'nombre': 'Leche', 'categoria': 'Importados'},
        {'nombre': 'Atún', 'categoria': 'Abarrotes'},
      ]);
      final provider = crearProvider(firestore);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      final eliminada = await provider.eliminarCategoriaPersonalizada(
        'usuario-1',
        'mascotas',
      );

      expect(eliminada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), [
        'importados',
      ]);
      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(datos['categoriasPersonalizadas'], [
        {'clave': 'importados', 'nombre': 'Importados', 'activa': true},
      ]);
    });
  });

  group('categorías del preset desactivadas', () {
    ConfiguracionNegocioProvider crearProvider({
      FirebaseFirestore? firestore,
      Object? desactivadas,
      Map<String, dynamic>? configuracionInicial,
    }) => ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
      configuracionInicial:
          desactivadas != null
              ? {'categoriasDesactivadas': desactivadas}
              : configuracionInicial,
      repository: NegocioRepository(
        firestore: firestore ?? FakeFirebaseFirestore(),
      ),
    );

    test('carga vacía si el campo no existe', () {
      final sinCampo = crearProvider(configuracionInicial: {'nombreNegocio': 'B'});
      final sinConfiguracion = crearProvider();
      final conNull = crearProvider(desactivadas: null);

      expect(sinCampo.categoriasDesactivadas, isEmpty);
      expect(sinConfiguracion.categoriasDesactivadas, isEmpty);
      expect(conNull.categoriasDesactivadas, isEmpty);
      expect(sinCampo.categoriaPresetDesactivada('Snacks'), isFalse);
    });

    test('carga lo guardado usando la clave canónica', () {
      final provider = crearProvider(desactivadas: ['  SNACKS  ']);

      expect(provider.categoriasDesactivadas, {'snacks'});
      // La consulta es por clave, no por texto: da igual cómo se escriba.
      expect(provider.categoriaPresetDesactivada('snacks'), isTrue);
      expect(provider.categoriaPresetDesactivada('  Snacks '), isTrue);
      expect(provider.categoriaPresetDesactivada('Bebidas'), isFalse);
    });

    test('desactiva una categoría del preset sin tocarla', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = crearProvider(firestore: firestore);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);
      final categoriasIniciales = provider.categorias;

      final desactivada = await provider.desactivarCategoriaDelPreset(
        'usuario-1',
        'Snacks',
      );

      expect(desactivada, isTrue);
      expect(provider.errorCatalogo, isNull);
      expect(notificaciones, 1);
      expect(provider.categoriasDesactivadas, {'snacks'});
      expect(provider.categoriaPresetDesactivada('Snacks'), isTrue);
      // El preset y la lista visible siguen intactos: desactivar no borra.
      expect(provider.categorias, categoriasIniciales);
      expect(provider.categorias, contains('Snacks'));
    });

    test('no duplica claves al desactivar dos veces', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = crearProvider(firestore: firestore);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      await provider.desactivarCategoriaDelPreset('usuario-1', 'Snacks');
      // Misma categoría escrita con otra capitalización y con espacios.
      final repetida = await provider.desactivarCategoriaDelPreset(
        'usuario-1',
        '  SNACKS ',
      );

      expect(repetida, isTrue);
      expect(provider.categoriasDesactivadas, {'snacks'});
      expect(provider.categoriasDesactivadas, hasLength(1));
      // La segunda vez no hay nada que escribir ni que avisar.
      expect(notificaciones, 1);
    });

    test('persiste la lista completa de claves', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = crearProvider(firestore: firestore);

      await provider.desactivarCategoriaDelPreset('usuario-1', 'Snacks');
      await provider.desactivarCategoriaDelPreset('usuario-1', 'Limpieza');

      expect(provider.categoriasDesactivadas, {'snacks', 'limpieza'});
      final datos =
          (await firestore.collection('negocios').doc('negocio-1').get())
              .data()!;
      expect(
        (datos['categoriasDesactivadas'] as List).toSet(),
        {'snacks', 'limpieza'},
      );
    });

    test('el getter de desactivadas no es modificable', () {
      final provider = crearProvider(desactivadas: ['snacks']);

      expect(
        () => provider.categoriasDesactivadas.add('bebidas'),
        throwsUnsupportedError,
      );
      expect(provider.categoriasDesactivadas, {'snacks'});
    });

    test('rechaza una categoría que no es del preset', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = crearProvider(firestore: firestore);

      final desactivada = await provider.desactivarCategoriaDelPreset(
        'usuario-1',
        'Mascotas',
      );

      expect(desactivada, isFalse);
      expect(provider.errorCatalogo, contains('no es una categoría de Bodega'));
      expect(provider.categoriasDesactivadas, isEmpty);
    });
  });
}


