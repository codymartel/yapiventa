import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/config_pago_metodo.dart';
import 'package:mobile/features/negocio/domain/models/horario_dia.dart';
import 'package:mobile/features/negocio/domain/models/metodo_pago_tipo.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/domain/models/zona_delivery.dart';

void main() {
  late _MergeAwareFakeFirebaseFirestore firestore;
  late NegocioRepository repository;

  setUp(() {
    firestore = _MergeAwareFakeFirebaseFirestore();
    repository = NegocioRepository(firestore: firestore);
  });

  test(
    'obtiene categorías y unidades tipadas desde negocios/{negocioId}',
    () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {
          'rubro': 'Bodega',
          'categorias': ['Bebidas', ' Snacks ', 'Bebidas', 7],
          'unidadesMedida': [
            {
              'nombre': 'Unidad',
              'tipo': 'entera',
              'fraccionesPermitidas': ['1', '2'],
              'esOpcional': false,
            },
            {
              'nombre': 'kg',
              'tipo': 'fraccionaria',
              'fraccionesPermitidas': ['0.5', '1'],
              'esOpcional': true,
            },
          ],
        },
      );

      final catalogo = await repository.obtenerCatalogoNegocio('usuario-1');

      expect(catalogo.rubro, 'Bodega');
      expect(catalogo.categorias, ['Bebidas', 'Snacks']);
      expect(catalogo.unidadesMedida, hasLength(2));
      expect(catalogo.unidadesMedida.first.nombre, 'Unidad');
      expect(catalogo.unidadesMedida.first.tipo, TipoUnidad.entera);
      expect(catalogo.unidadesMedida.last.fraccionesPermitidas, ['0.5', '1']);
      expect(catalogo.unidadesMedida.last.esOpcional, isTrue);
    },
  );

  test(
    'devuelve un catálogo vacío cuando el documento no tiene datos',
    () async {
      await _prepararNegocio(firestore, 'usuario-1', datos: {});

      final catalogo = await repository.obtenerCatalogoNegocio('usuario-1');

      expect(catalogo.categorias, isEmpty);
      expect(catalogo.unidadesMedida, isEmpty);
    },
  );

  test('tolera datos incompletos sin crear unidades inválidas', () async {
    await _prepararNegocio(
      firestore,
      'usuario-1',
      datos: {
        'categorias': 'Bebidas',
        'unidadesMedida': [
          {'nombre': 'Unidad'},
          {'tipo': 'entera'},
          'kg',
        ],
      },
    );

    final catalogo = await repository.obtenerCatalogoNegocio('usuario-1');

    expect(catalogo.categorias, isEmpty);
    expect(catalogo.unidadesMedida, isEmpty);
  });

  test('actualiza la configuracion en negocios y serializa delivery, horarios '
      'y pagos sin tocar users/{uid}', () async {
    final negocioId = await _prepararNegocio(
      firestore,
      'usuario-1',
      datos: {
        'email': 'ana@example.com',
        'plantillaWeb': 'neon',
        'setupComplete': false,
        'webActiva': false,
      },
    );

    await repository.guardarConfiguracionNegocio(
      uid: 'usuario-1',
      rubro: 'Bodega',
      nombreNegocio: '  Bodega Ana  ',
      slug: 'bodega-ana',
      telefonoCompleto: '+51999999999',
      direccionCompleta: 'Av. Lima 123',
      ruc: '12345678901',
      facebook: 'facebook.com/bodegaana',
      tiktok: '',
      instagram: 'instagram.com/bodegaana',
      youtube: '',
      categorias: ['Bebidas'],
      unidadesMedida: const [
        UnidadInfo(
          nombre: 'Unidad',
          tipo: TipoUnidad.entera,
          fraccionesPermitidas: [],
          esOpcional: false,
        ),
      ],
      tieneDelivery: true,
      zonasDelivery: const [ZonaDelivery(zona: 'Centro', costo: '7.50')],
      horarios: const [
        HorarioDia(
          dia: 'Lunes',
          apertura: '08:00',
          cierre: '18:00',
          activo: true,
        ),
      ],
      metodosPagoConfig: const [
        ConfigPagoMetodo(
          metodoId: 'yape',
          activo: true,
          numeroPago: '999999999',
          descuentoActivo: true,
          tipoDescuento: TipoDescuento.porcentaje,
          valorDescuento: '10',
          montoMinimo: '20',
        ),
        ConfigPagoMetodo(metodoId: 'efectivo', activo: true),
        ConfigPagoMetodo(metodoId: 'plin'),
      ],
    );

    final datos = (await firestore.collection('negocios').doc(negocioId).get())
        .data()!;
    expect(datos['rubro'], 'Bodega');
    expect(datos['nombreNegocio'], 'Bodega Ana');
    expect(datos['ruc'], '12345678901');
    expect(datos['plantillaWeb'], 'neon');
    expect(datos['setupComplete'], isFalse);
    expect(datos['webActiva'], isFalse);
    expect(datos['deliveryZonas'], [
      {'zona': 'Centro', 'costo': 7.5},
    ]);
    expect(datos['horarios'], [
      {'dia': 'Lunes', 'apertura': '08:00', 'cierre': '18:00', 'activo': true},
    ]);
    expect(datos['metodosPago'], ['yape', 'efectivo']);
    expect(datos['configPagos'], {
      'yape': {
        'numero': '999999999',
        'descuentoActivo': true,
        'montoMinimo': 20.0,
        'tipoDescuento': 'porcentaje',
        'valorDescuento': 10.0,
      },
    });

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(perfil.keys.toSet(), {'email', 'negocioId'});
  });

  test('guardarPlantillaWeb completa onboarding sin tocar webActiva', () async {
    final negocioId = await _guardarCuentaConNegocioValido(
      firestore,
      'usuario-1',
      adicionales: {
        'slug': 'bodega-ana',
        'plantilla': 'neon',
        'webActiva': false,
      },
    );
    await _guardarProductoValido(firestore, 'usuario-1');

    await repository.guardarPlantillaWeb('usuario-1', PlantillaWeb.cristal);

    final datos = (await firestore.collection('negocios').doc(negocioId).get())
        .data()!;
    expect(datos['slug'], 'bodega-ana');
    expect(datos['plantilla'], 'neon');
    expect(datos['plantillaWeb'], 'cristal');
    expect(datos['onboardingProductsConfirmed'], isTrue);
    expect(datos['setupComplete'], isTrue);
    expect(datos['onboardingTemplateCompletedAt'], isNotNull);
    expect(datos['onboardingCompletedAt'], isNotNull);
    expect(datos['webActiva'], isFalse);

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(perfil.keys.toSet(), {'email', 'negocioId'});
  });

  group('obtenerProgresoConfiguracion', () {
    test('empieza en rubro para una cuenta sin datos', () async {
      await firestore.collection('users').doc('usuario-nuevo').set({
        'email': 'nuevo@example.com',
      });
      firestore.negociosCollectionAccesses = 0;

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-nuevo',
      );

      expect(progreso.rubroCompleto, isFalse);
      expect(progreso.negocioCompleto, isFalse);
      expect(progreso.productosCompletos, isFalse);
      expect(progreso.plantillaCompleta, isFalse);
      expect(progreso.completo, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.rubro);
      expect(firestore.negociosCollectionAccesses, 0);
    });

    test('acepta un negocioId ya resuelto sin releer users/{uid}', () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {'rubro': 'Bodega'},
      );
      firestore.usersCollectionAccesses = 0;

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
        negocioId: 'negocio-usuario-1',
      );

      expect(progreso.rubroCompleto, isTrue);
      expect(firestore.usersCollectionAccesses, 0);
    });

    test('avanza a negocio al encontrar un rubro válido', () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {'rubro': 'Bodega'},
      );

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.rubroCompleto, isTrue);
      expect(progreso.negocioCompleto, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.negocio);
    });

    test(
      'avanza a productos con una configuración de negocio válida',
      () async {
        await _guardarCuentaConNegocioValido(firestore, 'usuario-1');

        final progreso = await repository.obtenerProgresoConfiguracion(
          'usuario-1',
        );

        expect(progreso.negocioCompleto, isTrue);
        expect(progreso.productosCompletos, isFalse);
        expect(progreso.siguiente, EtapaConfiguracion.productos);
      },
    );

    test('avanza a plantilla al encontrar un producto válido', () async {
      await _guardarCuentaConNegocioValido(firestore, 'usuario-1');
      await _guardarProductoValido(firestore, 'usuario-1');

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.productosCompletos, isTrue);
      expect(progreso.plantillaCompleta, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.plantilla);
    });

    test('busca un producto válido más allá del primer documento', () async {
      await _guardarCuentaConNegocioValido(firestore, 'usuario-1');
      await firestore
          .collection('negocios')
          .doc('negocio-usuario-1')
          .collection('productos')
          .doc('a-invalido')
          .set({'nombre': 'Sin datos completos'});
      await _guardarProductoValido(firestore, 'usuario-1');

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.productosCompletos, isTrue);
      expect(progreso.siguiente, EtapaConfiguracion.plantilla);
    });

    test('queda completa cuando producto y plantilla son válidos', () async {
      await _guardarCuentaConNegocioValido(
        firestore,
        'usuario-1',
        adicionales: {'plantillaWeb': 'galeria'},
      );
      await _guardarProductoValido(firestore, 'usuario-1');

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.plantilla, PlantillaWeb.galeria);
      expect(progreso.completo, isTrue);
      expect(progreso.siguiente, EtapaConfiguracion.completa);
    });

    test('reconoce una cuenta legada completa', () async {
      await _guardarCuentaConNegocioValido(
        firestore,
        'usuario-legado',
        adicionales: {'plantilla': 'neon', 'setupComplete': true},
      );
      await _guardarProductoValido(firestore, 'usuario-legado');

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-legado',
      );

      expect(progreso.plantilla, PlantillaWeb.neon);
      expect(progreso.plantillaProvieneDeCampoOficial, isFalse);
      expect(progreso.completo, isTrue);
      expect(progreso.setupCompletePersistido, isTrue);
      expect(progreso.productosConfirmadosPersistidos, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.completa);
    });

    test('no confía en un setupComplete antiguo y prematuro', () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {'setupComplete': true},
      );

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.setupCompletePersistido, isTrue);
      expect(progreso.completo, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.rubro);
    });

    test('un producto confirmado no reinicia el flujo tras borrarlo', () async {
      await _guardarCuentaConNegocioValido(firestore, 'usuario-1');
      await _guardarProductoValido(firestore, 'usuario-1');
      await repository.guardarPlantillaWeb('usuario-1', PlantillaWeb.cristal);
      await firestore
          .collection('negocios')
          .doc('negocio-usuario-1')
          .collection('productos')
          .doc('producto-1')
          .delete();

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.productosConfirmadosPersistidos, isTrue);
      expect(progreso.productosCompletos, isTrue);
      expect(progreso.completo, isTrue);
      expect(progreso.siguiente, EtapaConfiguracion.completa);
    });
  });

  test('guardarRubro conserva webActiva en negocios y no toca users', () async {
    final negocioId = await _prepararNegocio(
      firestore,
      'usuario-1',
      datos: {'webActiva': true},
    );

    await repository.guardarRubro('usuario-1', '  Bodega  ');

    final datos = (await firestore.collection('negocios').doc(negocioId).get())
        .data()!;
    expect(datos['rubro'], 'Bodega');
    expect(datos['webActiva'], isTrue);
    expect(datos['onboardingRubroCompletedAt'], isNotNull);

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(perfil.keys.toSet(), {'email', 'negocioId'});
  });

  test('guardarRubro crea y vincula exactamente un negocio', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'terminosAceptados': true,
      'createdAt': Timestamp.now(),
    });

    await repository.guardarRubro('usuario-1', ' Bodega ');

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    final negocios = await firestore.collection('negocios').get();
    expect(negocios.docs, hasLength(1));
    expect(perfil['negocioId'], negocios.docs.single.id);
    expect(
      negocios.docs.single.data(),
      containsPair('propietarioUid', 'usuario-1'),
    );
    expect(negocios.docs.single.data(), containsPair('rubro', 'Bodega'));
    expect(
      negocios.docs.single.data(),
      containsPair('onboardingBusinessRubro', 'Bodega'),
    );
    expect(negocios.docs.single.data(), containsPair('setupComplete', false));
    expect(negocios.docs.single.data(), containsPair('webActiva', false));
    expect(negocios.docs.single.data()['createdAt'], isA<Timestamp>());
    expect(
      negocios.docs.single.data()['onboardingRubroCompletedAt'],
      isA<Timestamp>(),
    );
  });

  test('dos intentos de guardarRubro reutilizan el mismo negocio', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
    });

    await repository.guardarRubro('usuario-1', 'Bodega');
    final negocioIdInicial =
        (await firestore.collection('users').doc('usuario-1').get())
            .data()!['negocioId'];
    final completadoInicial =
        (await firestore
                .collection('negocios')
                .doc(negocioIdInicial as String)
                .get())
            .data()!['onboardingRubroCompletedAt'];
    await repository.guardarRubro('usuario-1', 'Bodega');

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    final negocios = await firestore.collection('negocios').get();
    expect(negocios.docs, hasLength(1));
    expect(perfil['negocioId'], negocioIdInicial);
    expect(negocios.docs.single.id, negocioIdInicial);
    expect(
      negocios.docs.single.data()['onboardingRubroCompletedAt'],
      completadoInicial,
    );
  });

  test('una transacción fallida no deja un vínculo parcial', () async {
    final firestoreConFalla = _AbortTransactionFakeFirebaseFirestore();
    final repositoryConFalla = NegocioRepository(firestore: firestoreConFalla);
    await firestoreConFalla.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
    });

    await expectLater(
      repositoryConFalla.guardarRubro('usuario-1', 'Bodega'),
      throwsA(isA<FirebaseException>()),
    );

    final perfil =
        (await firestoreConFalla.collection('users').doc('usuario-1').get())
            .data()!;
    expect(perfil.containsKey('negocioId'), isFalse);
    expect(
      (await firestoreConFalla.collection('negocios').get()).docs,
      isEmpty,
    );
  });

  test(
    'después de guardar Rubro el progreso desbloquea Configuración',
    () async {
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
      });

      await repository.guardarRubro('usuario-1', 'Bodega');
      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.rubroCompleto, isTrue);
      expect(progreso.negocioCompleto, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.negocio);
    },
  );

  test(
    'un usuario con negocio existente continúa cargando su progreso',
    () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {'propietarioUid': 'usuario-1', 'rubro': 'Bodega'},
      );

      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-1',
      );

      expect(progreso.rubroCompleto, isTrue);
      expect(progreso.siguiente, EtapaConfiguracion.negocio);
      expect((await firestore.collection('negocios').get()).docs, hasLength(1));
    },
  );

  test(
    'obtiene slug y prioriza plantillaWeb en una lectura conjunta',
    () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {
          'slug': ' bodega-ana ',
          'plantilla': 'neon',
          'plantillaWeb': 'galeria',
        },
      );

      final info = await repository.obtenerSeleccionPlantilla('usuario-1');

      expect(info.slug, 'bodega-ana');
      expect(info.plantillaGuardada, PlantillaWeb.galeria);
      expect(info.provieneDeCampoOficial, isTrue);
    },
  );

  test(
    'usa plantilla legada solo si plantillaWeb falta o esta vacia',
    () async {
      await _prepararNegocio(
        firestore,
        'sin-oficial',
        datos: {'slug': 'tienda-uno', 'plantilla': 'neon'},
      );
      await _prepararNegocio(
        firestore,
        'oficial-vacia',
        datos: {
          'slug': 'tienda-dos',
          'plantilla': 'sabroso',
          'plantillaWeb': '  ',
        },
      );

      final sinOficial = await repository.obtenerSeleccionPlantilla(
        'sin-oficial',
      );
      final oficialVacia = await repository.obtenerSeleccionPlantilla(
        'oficial-vacia',
      );

      expect(sinOficial.plantillaGuardada, PlantillaWeb.neon);
      expect(sinOficial.provieneDeCampoOficial, isFalse);
      expect(oficialVacia.plantillaGuardada, PlantillaWeb.sabroso);
      expect(oficialVacia.provieneDeCampoOficial, isFalse);
    },
  );

  test('no convierte limpio ni ignora un campo oficial no vacio', () async {
    await _prepararNegocio(
      firestore,
      'legado-limpio',
      datos: {'slug': 'tienda-uno', 'plantilla': 'limpio'},
    );
    await _prepararNegocio(
      firestore,
      'oficial-invalido',
      datos: {
        'slug': 'tienda-dos',
        'plantilla': 'neon',
        'plantillaWeb': 'limpio',
      },
    );

    final legado = await repository.obtenerSeleccionPlantilla('legado-limpio');
    final oficial = await repository.obtenerSeleccionPlantilla(
      'oficial-invalido',
    );

    expect(legado.plantillaGuardada, isNull);
    expect(legado.provieneDeCampoOficial, isFalse);
    expect(oficial.plantillaGuardada, isNull);
    expect(oficial.provieneDeCampoOficial, isTrue);
  });

  test('usa el campo legado si plantillaWeb no es texto', () async {
    await _prepararNegocio(
      firestore,
      'oficial-mal-tipado',
      datos: {'slug': 'tienda-uno', 'plantilla': 'neon', 'plantillaWeb': 7},
    );

    final info = await repository.obtenerSeleccionPlantilla(
      'oficial-mal-tipado',
    );

    expect(info.plantillaGuardada, PlantillaWeb.neon);
    expect(info.provieneDeCampoOficial, isFalse);
  });

  test(
    'rechaza operaciones posteriores sin negocioId y no escribe negocios',
    () async {
      await firestore.collection('users').doc('sin-negocio').set({
        'email': 'x@example.com',
      });

      expect(
        () => repository.guardarConfiguracionNegocio(
          uid: 'sin-negocio',
          rubro: 'Bodega',
          nombreNegocio: 'Bodega X',
          slug: 'bodega-x',
          telefonoCompleto: '+51999999999',
          direccionCompleta: 'Av. Lima 123',
          ruc: '',
          facebook: '',
          tiktok: '',
          instagram: '',
          youtube: '',
          categorias: const [],
          unidadesMedida: const [],
          tieneDelivery: false,
          zonasDelivery: const [],
          horarios: const [],
          metodosPagoConfig: const [],
        ),
        throwsStateError,
      );
      expect(
        () => repository.existenProductosDependientes(
          uid: 'sin-negocio',
          categorias: const ['Bebidas'],
          unidades: const [],
        ),
        throwsStateError,
      );

      final negocios = await firestore.collection('negocios').get();
      expect(negocios.docs, isEmpty);
    },
  );

  test(
    'existenProductosDependientes consulta negocios/{negocioId}/productos',
    () async {
      final negocioId = await _prepararNegocio(firestore, 'usuario-1');
      await firestore
          .collection('negocios')
          .doc(negocioId)
          .collection('productos')
          .doc('producto-1')
          .set({'categoria': 'Bebidas'});
      await firestore
          .collection('negocios')
          .doc(negocioId)
          .collection('productos')
          .doc('producto-2')
          .set({'unidadMedidaNombre': 'kg'});

      final porCategoria = await repository.existenProductosDependientes(
        uid: 'usuario-1',
        categorias: const ['Bebidas'],
        unidades: const [],
      );
      final porUnidad = await repository.existenProductosDependientes(
        uid: 'usuario-1',
        categorias: const [],
        unidades: const ['kg'],
      );
      final sinCoincidencias = await repository.existenProductosDependientes(
        uid: 'usuario-1',
        categorias: const ['Snacks'],
        unidades: const ['Unidad'],
      );

      expect(porCategoria, isTrue);
      expect(porUnidad, isTrue);
      expect(sinCoincidencias, isFalse);
    },
  );

  group('negocios_publicos (proyección pública)', () {
    const camposPublicos = {
      'negocioId',
      'nombreNegocio',
      'slug',
      'rubro',
      'telefono',
      'direccion',
      'facebook',
      'instagram',
      'tiktok',
      'youtube',
      'plantillaWeb',
      'webActiva',
      'categorias',
      'delivery',
      'deliveryZonas',
      'horarios',
      'metodosPago',
      'configPagos',
    };

    test('crea negocios_publicos/{slug} con solo los campos públicos al '
        'guardar la configuración', () async {
      final negocioId = await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {
          'email': 'ana@example.com',
          'plantillaWeb': 'neon',
          'webActiva': true,
          'setupComplete': false,
          'propietarioUid': 'usuario-1',
        },
      );

      await _guardarConfiguracionBasica(repository);

      final publico =
          (await firestore
                  .collection('negocios_publicos')
                  .doc('bodega-ana')
                  .get())
              .data()!;
      expect(publico.keys.toSet(), camposPublicos);
      expect(publico, {
        'negocioId': negocioId,
        'nombreNegocio': 'Bodega Ana',
        'slug': 'bodega-ana',
        'rubro': 'Bodega',
        'telefono': '+51999999999',
        'direccion': 'Av. Lima 123',
        'facebook': 'facebook.com/bodegaana',
        'instagram': 'instagram.com/bodegaana',
        'tiktok': '',
        'youtube': '',
        'plantillaWeb': 'neon',
        'webActiva': true,
        'categorias': ['Bebidas'],
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
        'metodosPago': ['yape', 'efectivo'],
        'configPagos': {
          'yape': {
            'numero': '999999999',
            'descuentoActivo': true,
            'montoMinimo': 20.0,
            'tipoDescuento': 'porcentaje',
            'valorDescuento': 10.0,
          },
        },
      });

      final negocio =
          (await firestore.collection('negocios').doc(negocioId).get()).data()!;
      expect(negocio['ruc'], '12345678901');
      expect(negocio['setupComplete'], isFalse);
      expect(negocio['webActiva'], isTrue);
    });

    test('se actualiza la proyección cuando cambia el nombre', () async {
      await _prepararNegocio(firestore, 'usuario-1', datos: const {});
      await _guardarConfiguracionBasica(repository);

      await _guardarConfiguracionBasica(
        repository,
        nombreNegocio: 'Bodega Ana S.A.',
        slug: 'bodega-ana-s-a',
      );

      final publico =
          (await firestore
                  .collection('negocios_publicos')
                  .doc('bodega-ana-s-a')
                  .get())
              .data()!;
      expect(publico['nombreNegocio'], 'Bodega Ana S.A.');
      expect(publico['slug'], 'bodega-ana-s-a');
      expect(publico['negocioId'], 'negocio-usuario-1');

      final perfil =
          (await firestore.collection('users').doc('usuario-1').get()).data()!;
      expect(perfil.keys.toSet(), {'email', 'negocioId'});
    });

    test('se actualiza la proyección al guardar la plantilla', () async {
      final negocioId = await _guardarCuentaConNegocioValido(
        firestore,
        'usuario-1',
        adicionales: {'webActiva': true},
      );
      await _guardarProductoValido(firestore, 'usuario-1');

      await repository.guardarPlantillaWeb('usuario-1', PlantillaWeb.cristal);

      final publico =
          (await firestore
                  .collection('negocios_publicos')
                  .doc('bodega-ana')
                  .get())
              .data()!;
      expect(publico['plantillaWeb'], 'cristal');
      expect(publico['webActiva'], isTrue);
      expect(publico['nombreNegocio'], 'Bodega Ana');
      expect(publico['negocioId'], negocioId);

      final negocio =
          (await firestore.collection('negocios').doc(negocioId).get()).data()!;
      expect(negocio['plantillaWeb'], 'cristal');
      expect(negocio['slug'], 'bodega-ana');
      expect(negocio['rubro'], 'Bodega');
      expect(negocio['telefono'], '+51999999999');
      expect(negocio['direccion'], 'Av. Lima 123');
      expect(negocio['categorias'], ['Bebidas']);
      expect(negocio['delivery'], isFalse);

      final perfil =
          (await firestore.collection('users').doc('usuario-1').get()).data()!;
      expect(perfil.keys.toSet(), {'email', 'negocioId'});
    });

    test('refleja la webActiva vigente al reescribir la proyección', () async {
      await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {'webActiva': true},
      );
      await _guardarConfiguracionBasica(repository);

      var publico =
          (await firestore
                  .collection('negocios_publicos')
                  .doc('bodega-ana')
                  .get())
              .data()!;
      expect(publico['webActiva'], isTrue);

      // Simula que el negocio desactiva su tienda web (toggle futuro).
      await firestore.collection('negocios').doc('negocio-usuario-1').set({
        'webActiva': false,
      }, SetOptions(merge: true));
      await _guardarConfiguracionBasica(repository);

      publico =
          (await firestore
                  .collection('negocios_publicos')
                  .doc('bodega-ana')
                  .get())
              .data()!;
      expect(publico['webActiva'], isFalse);
    });

    test('al cambiar el slug elimina la ruta pública anterior', () async {
      await _prepararNegocio(firestore, 'usuario-1', datos: const {});
      await _guardarConfiguracionBasica(repository, slug: 'bodega-ana');

      await _guardarConfiguracionBasica(repository, slug: 'bodega-ana-v2');

      final anterior = await firestore
          .collection('negocios_publicos')
          .doc('bodega-ana')
          .get();
      final actual = await firestore
          .collection('negocios_publicos')
          .doc('bodega-ana-v2')
          .get();
      final negocio =
          (await firestore
                  .collection('negocios')
                  .doc('negocio-usuario-1')
                  .get())
              .data()!;

      expect(anterior.exists, isFalse);
      expect(actual.data()!['slug'], 'bodega-ana-v2');
      expect(actual.data()!['negocioId'], 'negocio-usuario-1');
      expect(negocio['slug'], 'bodega-ana-v2');

      final publicos = await firestore.collection('negocios_publicos').get();
      expect(publicos.docs, hasLength(1));
    });

    test(
      'la plantilla no rompe la configuración del negocio ni la proyección',
      () async {
        final negocioId = await _guardarCuentaConNegocioValido(
          firestore,
          'usuario-1',
          adicionales: {'plantillaWeb': 'neon'},
        );
        await _guardarProductoValido(firestore, 'usuario-1');
        await _guardarConfiguracionBasica(repository);

        await repository.guardarPlantillaWeb('usuario-1', PlantillaWeb.neon);

        final negocio =
            (await firestore.collection('negocios').doc(negocioId).get())
                .data()!;
        expect(negocio['rubro'], 'Bodega');
        expect(negocio['nombreNegocio'], 'Bodega Ana');
        expect(negocio['telefono'], '+51999999999');
        expect(negocio['slug'], 'bodega-ana');
        expect(negocio['setupComplete'], isTrue);

        final publico =
            (await firestore
                    .collection('negocios_publicos')
                    .doc('bodega-ana')
                    .get())
                .data()!;
        expect(publico['plantillaWeb'], 'neon');
        expect(publico['nombreNegocio'], 'Bodega Ana');
        expect(publico['slug'], 'bodega-ana');
      },
    );

    group('actualizarWebActiva', () {
      test('sincroniza true en el negocio privado y público', () async {
        final negocioId = await _prepararNegocio(
          firestore,
          'usuario-1',
          datos: {
            'slug': 'bodega-ana',
            'webActiva': false,
            'nombreNegocio': 'Bodega Ana',
          },
        );
        await firestore.collection('negocios_publicos').doc('bodega-ana').set({
          'negocioId': negocioId,
          'webActiva': false,
          'nombreNegocio': 'Bodega Ana',
        });

        await repository.actualizarWebActiva('usuario-1', true);

        final privado =
            (await firestore.collection('negocios').doc(negocioId).get())
                .data()!;
        final publico =
            (await firestore
                    .collection('negocios_publicos')
                    .doc('bodega-ana')
                    .get())
                .data()!;
        expect(privado['webActiva'], isTrue);
        expect(publico['webActiva'], isTrue);
        expect(privado['nombreNegocio'], 'Bodega Ana');
        expect(publico['nombreNegocio'], 'Bodega Ana');
      });

      test('sincroniza false en el negocio privado y público', () async {
        final negocioId = await _prepararNegocio(
          firestore,
          'usuario-1',
          datos: {
            'slug': 'bodega-ana',
            'webActiva': true,
            'nombreNegocio': 'Bodega Ana',
          },
        );
        await firestore.collection('negocios_publicos').doc('bodega-ana').set({
          'negocioId': negocioId,
          'webActiva': true,
          'nombreNegocio': 'Bodega Ana',
        });

        await repository.actualizarWebActiva('usuario-1', false);

        final privado =
            (await firestore.collection('negocios').doc(negocioId).get())
                .data()!;
        final publico =
            (await firestore
                    .collection('negocios_publicos')
                    .doc('bodega-ana')
                    .get())
                .data()!;
        expect(privado['webActiva'], isFalse);
        expect(publico['webActiva'], isFalse);
        expect(privado['nombreNegocio'], 'Bodega Ana');
        expect(publico['nombreNegocio'], 'Bodega Ana');
      });

      test('sin negocioId lanza StateError y no escribe', () async {
        await firestore.collection('users').doc('usuario-1').set({
          'email': 'ana@example.com',
        });

        await expectLater(
          repository.actualizarWebActiva('usuario-1', true),
          throwsStateError,
        );

        expect(
          (await firestore.collection('users').doc('usuario-1').get()).data(),
          {'email': 'ana@example.com'},
        );
        expect((await firestore.collection('negocios').get()).docs, isEmpty);
        expect(
          (await firestore.collection('negocios_publicos').get()).docs,
          isEmpty,
        );
      });

      test('sin slug lanza StateError y no escribe', () async {
        final negocioId = await _prepararNegocio(
          firestore,
          'usuario-1',
          datos: {'webActiva': false, 'nombreNegocio': 'Bodega Ana'},
        );
        final datosAntes =
            (await firestore.collection('negocios').doc(negocioId).get())
                .data()!;

        await expectLater(
          repository.actualizarWebActiva('usuario-1', true),
          throwsStateError,
        );

        expect(
          (await firestore.collection('negocios').doc(negocioId).get()).data(),
          datosAntes,
        );
        expect(
          (await firestore.collection('negocios_publicos').get()).docs,
          isEmpty,
        );
      });

      test('con slug inválido lanza StateError y no escribe', () async {
        final negocioId = await _prepararNegocio(
          firestore,
          'usuario-1',
          datos: {
            'slug': 'Bodega Ana',
            'webActiva': false,
            'nombreNegocio': 'Bodega Ana',
          },
        );
        await firestore.collection('negocios_publicos').doc('Bodega Ana').set({
          'negocioId': negocioId,
          'webActiva': false,
        });
        final privadoAntes =
            (await firestore.collection('negocios').doc(negocioId).get())
                .data()!;
        final publicoAntes =
            (await firestore
                    .collection('negocios_publicos')
                    .doc('Bodega Ana')
                    .get())
                .data()!;

        await expectLater(
          repository.actualizarWebActiva('usuario-1', true),
          throwsStateError,
        );

        expect(
          (await firestore.collection('negocios').doc(negocioId).get()).data(),
          privadoAntes,
        );
        expect(
          (await firestore
                  .collection('negocios_publicos')
                  .doc('Bodega Ana')
                  .get())
              .data(),
          publicoAntes,
        );
      });

      test(
        'sin documento público lanza StateError y no cambia el privado',
        () async {
          final negocioId = await _prepararNegocio(
            firestore,
            'usuario-1',
            datos: {
              'slug': 'bodega-ana',
              'webActiva': false,
              'nombreNegocio': 'Bodega Ana',
            },
          );
          final privadoAntes =
              (await firestore.collection('negocios').doc(negocioId).get())
                  .data()!;

          await expectLater(
            repository.actualizarWebActiva('usuario-1', true),
            throwsStateError,
          );

          expect(
            (await firestore.collection('negocios').doc(negocioId).get())
                .data(),
            privadoAntes,
          );
          expect(
            (await firestore
                    .collection('negocios_publicos')
                    .doc('bodega-ana')
                    .get())
                .exists,
            isFalse,
          );
        },
      );

      test(
        'si el público apunta a otro negocio lanza StateError sin escribir',
        () async {
          final negocioId = await _prepararNegocio(
            firestore,
            'usuario-1',
            datos: {
              'slug': 'bodega-ana',
              'webActiva': false,
              'nombreNegocio': 'Bodega Ana',
            },
          );
          await firestore
              .collection('negocios_publicos')
              .doc('bodega-ana')
              .set({
                'negocioId': 'otro-negocio',
                'webActiva': false,
                'nombreNegocio': 'Otro negocio',
              });
          final privadoAntes =
              (await firestore.collection('negocios').doc(negocioId).get())
                  .data()!;
          final publicoAntes =
              (await firestore
                      .collection('negocios_publicos')
                      .doc('bodega-ana')
                      .get())
                  .data()!;

          await expectLater(
            repository.actualizarWebActiva('usuario-1', true),
            throwsStateError,
          );

          expect(
            (await firestore.collection('negocios').doc(negocioId).get())
                .data(),
            privadoAntes,
          );
          expect(
            (await firestore
                    .collection('negocios_publicos')
                    .doc('bodega-ana')
                    .get())
                .data(),
            publicoAntes,
          );
        },
      );
    });
  });
}

Future<void> _guardarPerfilConNegocioId(
  FakeFirebaseFirestore firestore,
  String uid,
) {
  return firestore.collection('users').doc(uid).set({
    'email': '$uid@example.com',
    'negocioId': _negocioIdDe(uid),
  });
}

String _negocioIdDe(String uid) => 'negocio-$uid';

Future<String> _prepararNegocio(
  FakeFirebaseFirestore firestore,
  String uid, {
  Map<String, dynamic> datos = const {},
}) async {
  await _guardarPerfilConNegocioId(firestore, uid);
  final negocioId = _negocioIdDe(uid);
  await firestore.collection('negocios').doc(negocioId).set({
    'propietarioUid': uid,
    ...datos,
  });
  return negocioId;
}

Future<String> _guardarCuentaConNegocioValido(
  FakeFirebaseFirestore firestore,
  String uid, {
  Map<String, dynamic> adicionales = const {},
}) {
  return _prepararNegocio(
    firestore,
    uid,
    datos: {
      'rubro': 'Bodega',
      'slug': 'bodega-ana',
      'nombreNegocio': 'Bodega Ana',
      'telefono': '+51999999999',
      'direccion': 'Av. Lima 123',
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
      ...adicionales,
    },
  );
}

Future<void> _guardarProductoValido(
  FakeFirebaseFirestore firestore,
  String uid,
) {
  final negocioId = _negocioIdDe(uid);
  return firestore
      .collection('negocios')
      .doc(negocioId)
      .collection('productos')
      .doc('producto-1')
      .set({
        'negocioId': negocioId,
        'nombre': 'Gaseosa',
        'precio': 4.5,
        'stock': 10,
        'categoria': 'Bebidas',
        'unidadMedidaNombre': 'Unidad',
        'fechaCreacion': Timestamp.now(),
      });
}

Future<void> _guardarConfiguracionBasica(
  NegocioRepository repository, {
  String nombreNegocio = 'Bodega Ana',
  String slug = 'bodega-ana',
}) {
  return repository.guardarConfiguracionNegocio(
    uid: 'usuario-1',
    rubro: 'Bodega',
    nombreNegocio: nombreNegocio,
    slug: slug,
    telefonoCompleto: '+51999999999',
    direccionCompleta: 'Av. Lima 123',
    ruc: '12345678901',
    facebook: 'facebook.com/bodegaana',
    tiktok: '',
    instagram: 'instagram.com/bodegaana',
    youtube: '',
    categorias: const ['Bebidas'],
    unidadesMedida: const [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: [],
        esOpcional: false,
      ),
    ],
    tieneDelivery: true,
    zonasDelivery: const [ZonaDelivery(zona: 'Centro', costo: '7.50')],
    horarios: const [
      HorarioDia(
        dia: 'Lunes',
        apertura: '08:00',
        cierre: '18:00',
        activo: true,
      ),
    ],
    metodosPagoConfig: const [
      ConfigPagoMetodo(
        metodoId: 'yape',
        activo: true,
        numeroPago: '999999999',
        descuentoActivo: true,
        tipoDescuento: TipoDescuento.porcentaje,
        valorDescuento: '10',
        montoMinimo: '20',
      ),
      ConfigPagoMetodo(metodoId: 'efectivo', activo: true),
      ConfigPagoMetodo(metodoId: 'plin'),
    ],
  );
}

// fake_cloud_firestore 3.1.0 ignora SetOptions en transacciones. Este ajuste
// conserva el fake como almacenamiento, pero ejecuta los writes con sus
// opciones reales para poder verificar la semántica merge de guardarRubro.
class _MergeAwareFakeFirebaseFirestore extends FakeFirebaseFirestore {
  int negociosCollectionAccesses = 0;
  int usersCollectionAccesses = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'negocios') negociosCollectionAccesses++;
    if (collectionPath == 'users') usersCollectionAccesses++;
    return super.collection(collectionPath);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _MergeAwareTransaction();
    final result = await transactionHandler(transaction);
    await transaction.commit();
    return result;
  }
}

class _AbortTransactionFakeFirebaseFirestore
    extends _MergeAwareFakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    await transactionHandler(_MergeAwareTransaction());
    throw FirebaseException(
      plugin: 'cloud_firestore',
      message: 'Transacción abortada para la prueba.',
    );
  }
}

class _MergeAwareTransaction implements Transaction {
  final List<Future<void> Function()> _writes = [];

  Future<void> commit() async {
    for (final write in _writes) {
      await write();
    }
  }

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) {
    return documentReference.get();
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _writes.add(() => documentReference.set(data, options));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<String, dynamic> data,
  ) {
    _writes.add(() => documentReference.update(data));
    return this;
  }

  @override
  Transaction delete(DocumentReference<Object?> documentReference) {
    _writes.add(documentReference.delete);
    return this;
  }
}
