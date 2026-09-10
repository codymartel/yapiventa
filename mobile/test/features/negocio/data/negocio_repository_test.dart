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
  late FakeFirebaseFirestore firestore;
  late NegocioRepository repository;

  setUp(() {
    firestore = _MergeAwareFakeFirebaseFirestore();
    repository = NegocioRepository(firestore: firestore);
  });

  test('obtiene categorías y unidades tipadas en una lectura', () async {
    await firestore.collection('users').doc('usuario-1').set({
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
    });

    final catalogo = await repository.obtenerCatalogoNegocio('usuario-1');

    expect(catalogo.rubro, 'Bodega');
    expect(catalogo.categorias, ['Bebidas', 'Snacks']);
    expect(catalogo.unidadesMedida, hasLength(2));
    expect(catalogo.unidadesMedida.first.nombre, 'Unidad');
    expect(catalogo.unidadesMedida.first.tipo, TipoUnidad.entera);
    expect(catalogo.unidadesMedida.last.fraccionesPermitidas, ['0.5', '1']);
    expect(catalogo.unidadesMedida.last.esOpcional, isTrue);
  });

  test(
    'devuelve un catálogo vacío cuando el documento no tiene datos',
    () async {
      await firestore.collection('users').doc('usuario-1').set({});

      final catalogo = await repository.obtenerCatalogoNegocio('usuario-1');

      expect(catalogo.categorias, isEmpty);
      expect(catalogo.unidadesMedida, isEmpty);
    },
  );

  test('tolera datos incompletos sin crear unidades inválidas', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'categorias': 'Bebidas',
      'unidadesMedida': [
        {'nombre': 'Unidad'},
        {'tipo': 'entera'},
        'kg',
      ],
    });

    final catalogo = await repository.obtenerCatalogoNegocio('usuario-1');

    expect(catalogo.categorias, isEmpty);
    expect(catalogo.unidadesMedida, isEmpty);
  });

  test(
    'actualiza la configuracion y serializa delivery, horarios y pagos',
    () async {
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'plantillaWeb': 'neon',
        'setupComplete': false,
        'webActiva': false,
      });

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

      final datos = (await firestore.collection('users').doc('usuario-1').get())
          .data()!;

      expect(datos['email'], 'ana@example.com');
      expect(datos['rubro'], 'Bodega');
      expect(datos['nombreNegocio'], 'Bodega Ana');
      expect(datos['plantillaWeb'], 'neon');
      expect(datos['setupComplete'], isFalse);
      expect(datos['webActiva'], isFalse);
      expect(datos['deliveryZonas'], [
        {'zona': 'Centro', 'costo': 7.5},
      ]);
      expect(datos['horarios'], [
        {
          'dia': 'Lunes',
          'apertura': '08:00',
          'cierre': '18:00',
          'activo': true,
        },
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
    },
  );

  test('guardarPlantillaWeb completa onboarding sin tocar webActiva', () async {
    await _guardarCuentaConNegocioValido(
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

    final datos = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(datos['slug'], 'bodega-ana');
    expect(datos['plantilla'], 'neon');
    expect(datos['plantillaWeb'], 'cristal');
    expect(datos['onboardingProductsConfirmed'], isTrue);
    expect(datos['setupComplete'], isTrue);
    expect(datos['onboardingTemplateCompletedAt'], isNotNull);
    expect(datos['onboardingCompletedAt'], isNotNull);
    expect(datos['webActiva'], isFalse);
  });

  group('obtenerProgresoConfiguracion', () {
    test('empieza en rubro para una cuenta sin datos', () async {
      final progreso = await repository.obtenerProgresoConfiguracion(
        'usuario-nuevo',
      );

      expect(progreso.rubroCompleto, isFalse);
      expect(progreso.negocioCompleto, isFalse);
      expect(progreso.productosCompletos, isFalse);
      expect(progreso.plantillaCompleta, isFalse);
      expect(progreso.completo, isFalse);
      expect(progreso.siguiente, EtapaConfiguracion.rubro);
    });

    test('avanza a negocio al encontrar un rubro válido', () async {
      await firestore.collection('users').doc('usuario-1').set({
        'rubro': 'Bodega',
      });

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
          .collection('users')
          .doc('usuario-1')
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
      await firestore.collection('users').doc('usuario-1').set({
        'setupComplete': true,
      });

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
          .collection('users')
          .doc('usuario-1')
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

  test('guardarRubro conserva webActiva', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'webActiva': true,
    });

    await repository.guardarRubro('usuario-1', '  Bodega  ');

    final datos = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(datos['rubro'], 'Bodega');
    expect(datos['email'], 'ana@example.com');
    expect(datos['webActiva'], isTrue);
    expect(datos['onboardingRubroCompletedAt'], isNotNull);
  });

  test(
    'obtiene slug y prioriza plantillaWeb en una lectura conjunta',
    () async {
      await firestore.collection('users').doc('usuario-1').set({
        'slug': ' bodega-ana ',
        'plantilla': 'neon',
        'plantillaWeb': 'galeria',
      });

      final info = await repository.obtenerSeleccionPlantilla('usuario-1');

      expect(info.slug, 'bodega-ana');
      expect(info.plantillaGuardada, PlantillaWeb.galeria);
      expect(info.provieneDeCampoOficial, isTrue);
    },
  );

  test(
    'usa plantilla legada solo si plantillaWeb falta o esta vacia',
    () async {
      await firestore.collection('users').doc('sin-oficial').set({
        'slug': 'tienda-uno',
        'plantilla': 'neon',
      });
      await firestore.collection('users').doc('oficial-vacia').set({
        'slug': 'tienda-dos',
        'plantilla': 'sabroso',
        'plantillaWeb': '  ',
      });

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
    await firestore.collection('users').doc('legado-limpio').set({
      'slug': 'tienda-uno',
      'plantilla': 'limpio',
    });
    await firestore.collection('users').doc('oficial-invalido').set({
      'slug': 'tienda-dos',
      'plantilla': 'neon',
      'plantillaWeb': 'limpio',
    });

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
    await firestore.collection('users').doc('oficial-mal-tipado').set({
      'slug': 'tienda-uno',
      'plantilla': 'neon',
      'plantillaWeb': 7,
    });

    final info = await repository.obtenerSeleccionPlantilla(
      'oficial-mal-tipado',
    );

    expect(info.plantillaGuardada, PlantillaWeb.neon);
    expect(info.provieneDeCampoOficial, isFalse);
  });
}

Future<void> _guardarCuentaConNegocioValido(
  FakeFirebaseFirestore firestore,
  String uid, {
  Map<String, dynamic> adicionales = const {},
}) {
  return firestore.collection('users').doc(uid).set({
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
  });
}

Future<void> _guardarProductoValido(
  FakeFirebaseFirestore firestore,
  String uid,
) {
  return firestore
      .collection('users')
      .doc(uid)
      .collection('productos')
      .doc('producto-1')
      .set({
        'negocioId': uid,
        'nombre': 'Gaseosa',
        'precio': 4.5,
        'stock': 10,
        'categoria': 'Bebidas',
        'unidadMedidaNombre': 'Unidad',
        'fechaCreacion': Timestamp.now(),
      });
}

// fake_cloud_firestore 3.1.0 ignora SetOptions en transacciones. Este ajuste
// conserva el fake como almacenamiento, pero ejecuta los writes con sus
// opciones reales para poder verificar la semántica merge de guardarRubro.
class _MergeAwareFakeFirebaseFirestore extends FakeFirebaseFirestore {
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
