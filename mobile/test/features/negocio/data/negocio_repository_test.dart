import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/config_pago_metodo.dart';
import 'package:mobile/features/negocio/domain/models/horario_dia.dart';
import 'package:mobile/features/negocio/domain/models/metodo_pago_tipo.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/zona_delivery.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NegocioRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
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
      expect(datos['setupComplete'], isTrue);
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

  test('guardarPlantillaWeb actualiza solo el molde web', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'slug': 'bodega-ana',
      'plantilla': 'neon',
    });

    await repository.guardarPlantillaWeb('usuario-1', PlantillaWeb.cristal);

    final datos = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(datos, {
      'slug': 'bodega-ana',
      'plantilla': 'neon',
      'plantillaWeb': 'cristal',
    });
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
