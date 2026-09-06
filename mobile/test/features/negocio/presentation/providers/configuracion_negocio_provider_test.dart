import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
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
}
