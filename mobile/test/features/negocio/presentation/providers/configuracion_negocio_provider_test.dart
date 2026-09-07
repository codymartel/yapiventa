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
