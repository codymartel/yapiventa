import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';

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
        nombre: 'Botella',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.5', '1'],
      ),
    );
    provider.editarUnidad(
      totalInicial,
      const UnidadInfo(
        nombre: 'Botella grande',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1', '2'],
      ),
    );

    expect(provider.unidadesMedida[totalInicial].nombre, 'Botella grande');
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

    while (provider.unidadesMedida.isNotEmpty) {
      provider.eliminarUnidad(0);
    }

    expect(provider.faltaUnidad, isTrue);
    expect(provider.puedeAvanzarPaso1, isFalse);
  });

  test('bloquea un segundo guardado concurrente', () async {
    final firestore = FakeFirebaseFirestore();
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
    final datos = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(datos['setupComplete'], isNull);
    expect(datos['onboardingBusinessRubro'], 'Bodega');
  });

  test(
    'desbloquea el guardado si un producto usa una categoría eliminada',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('usuario-1')
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
}
