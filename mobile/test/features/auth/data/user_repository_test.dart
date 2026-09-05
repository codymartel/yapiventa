import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/user_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = UserRepository(firestore: firestore);
  });

  test('crea un perfil inicial con los valores esperados', () async {
    await repository.crearPerfilEnFirestore(
      uid: 'usuario-1',
      email: 'ana@example.com',
      webActivaInicial: true,
    );

    final perfil = await firestore.collection('users').doc('usuario-1').get();

    expect(perfil.exists, isTrue);
    expect(perfil.data(), containsPair('email', 'ana@example.com'));
    expect(perfil.data(), containsPair('setupComplete', false));
    expect(perfil.data(), containsPair('terminosAceptados', true));
    expect(perfil.data(), containsPair('webActiva', true));
    expect(perfil.data()?['createdAt'], isA<Timestamp>());
  });

  test('guarda el plan free sin eliminar campos existentes', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
    });

    await repository.guardarPlanFree(
      uid: 'usuario-1',
      limiteProductos: 100,
      minimoProductos: 5,
    );

    final perfil = await firestore.collection('users').doc('usuario-1').get();
    final plan = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('plan')
        .doc('actual')
        .get();

    expect(perfil.data(), containsPair('email', 'ana@example.com'));
    expect(plan.data(), containsPair('tipo', 'free'));
    expect(plan.data(), containsPair('ilimitado', true));
    expect(plan.data(), containsPair('limiteProductos', 100));
    expect(plan.data(), containsPair('minimoProductos', 5));
    expect(plan.data()?['fechaInicio'], isA<Timestamp>());
    expect(plan.data()?['fechaFin'], isA<Timestamp>());
  });

  test('consulta existencia y estado de configuracion del perfil', () async {
    await firestore.collection('users').doc('configurado').set({
      'setupComplete': true,
    });
    await firestore.collection('users').doc('pendiente').set({
      'setupComplete': false,
    });

    expect(await repository.existePerfil('configurado'), isTrue);
    expect(await repository.existePerfil('inexistente'), isFalse);
    expect(await repository.setupCompleto('configurado'), isTrue);
    expect(await repository.setupCompleto('pendiente'), isFalse);
    expect(await repository.setupCompleto('inexistente'), isFalse);
  });
}
