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

  test('crea un perfil inicial con la estructura nueva', () async {
    await repository.crearPerfilEnFirestore(
      uid: 'usuario-1',
      email: 'ana@example.com',
    );

    final perfil = await firestore.collection('users').doc('usuario-1').get();
    expect(perfil.exists, isTrue);
    expect(perfil.data(), {
      'email': 'ana@example.com',
      'terminosAceptados': true,
      'createdAt': isA<Timestamp>(),
    });
    expect((await firestore.collection('negocios').get()).docs, isEmpty);
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

  test('reintentar la creación conserva solo los campos del perfil', () async {
    final creado = Timestamp.now();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'anterior@example.com',
      'terminosAceptados': true,
      'createdAt': creado,
      'negocioId': 'negocio-1',
    });

    await repository.crearPerfilEnFirestore(
      uid: 'usuario-1',
      email: 'ana@example.com',
    );

    final datos = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(datos['email'], 'ana@example.com');
    expect(datos['createdAt'], creado);
    expect(datos['negocioId'], 'negocio-1');
    expect(datos.keys.toSet(), {
      'email',
      'terminosAceptados',
      'createdAt',
      'negocioId',
    });
  });

  test('registro crea users/{uid} y plan, pero ningún negocio', () async {
    await repository.asegurarPerfilYPlan(
      uid: 'usuario-nuevo',
      email: 'nuevo@example.com',
      limiteProductos: 20,
      minimoProductos: 1,
    );

    final perfil =
        (await firestore.collection('users').doc('usuario-nuevo').get())
            .data()!;
    final plan =
        (await firestore
                .collection('users')
                .doc('usuario-nuevo')
                .collection('plan')
                .doc('actual')
                .get())
            .data()!;
    expect(perfil, {
      'email': 'nuevo@example.com',
      'terminosAceptados': true,
      'createdAt': isA<Timestamp>(),
    });
    expect(plan, containsPair('tipo', 'free'));
    expect(plan, containsPair('limiteProductos', 20));
    expect((await firestore.collection('negocios').get()).docs, isEmpty);
  });

  test('repara perfil y plan de forma idempotente sin crear negocio', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'anterior@example.com',
      'createdAt': Timestamp.now(),
    });

    await repository.asegurarPerfilYPlan(
      uid: 'usuario-1',
      email: 'ana@example.com',
      limiteProductos: 20,
      minimoProductos: 1,
    );
    final planInicial = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('plan')
        .doc('actual')
        .get();
    await repository.asegurarPerfilYPlan(
      uid: 'usuario-1',
      email: 'ana@example.com',
      limiteProductos: 999,
      minimoProductos: 99,
    );

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    final planFinal = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('plan')
        .doc('actual')
        .get();
    expect(perfil['email'], 'ana@example.com');
    expect(perfil['negocioId'], isNull);
    expect(perfil.keys.toSet(), {'email', 'terminosAceptados', 'createdAt'});
    expect(planFinal.data(), planInicial.data());
    expect(planFinal.data()?['limiteProductos'], 20);
    expect((await firestore.collection('negocios').get()).docs, isEmpty);
  });

  test('consulta existencia y estado de configuracion del perfil', () async {
    await firestore.collection('users').doc('configurado').set({
      'negocioId': 'negocio-configurado',
    });
    await firestore.collection('users').doc('pendiente').set({
      'negocioId': 'negocio-pendiente',
    });
    await firestore.collection('users').doc('sin-negocio').set({
      'email': 'sin@example.com',
    });
    await firestore.collection('users').doc('sin-doc-negocio').set({
      'negocioId': 'negocio-fantasma',
    });
    await firestore.collection('negocios').doc('negocio-configurado').set({
      'setupComplete': true,
    });
    await firestore.collection('negocios').doc('negocio-pendiente').set({
      'setupComplete': false,
    });

    expect(await repository.existePerfil('configurado'), isTrue);
    expect(await repository.existePerfil('inexistente'), isFalse);
    expect(await repository.setupCompleto('configurado'), isTrue);
    expect(await repository.setupCompleto('pendiente'), isFalse);
    expect(await repository.setupCompleto('sin-negocio'), isFalse);
    expect(await repository.setupCompleto('sin-doc-negocio'), isFalse);
    expect(await repository.setupCompleto('inexistente'), isFalse);
  });

  test(
    'conserva el negocioId de un usuario existente sin tocar su negocio',
    () async {
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'negocioId': 'negocio-existente',
      });
      await firestore.collection('negocios').doc('negocio-existente').set({
        'propietarioUid': 'usuario-1',
        'rubro': 'Bodega',
      });

      await repository.asegurarPerfilYPlan(
        uid: 'usuario-1',
        email: 'ana@example.com',
        limiteProductos: 20,
        minimoProductos: 1,
      );

      final perfil =
          (await firestore.collection('users').doc('usuario-1').get()).data()!;
      final negocio =
          (await firestore
                  .collection('negocios')
                  .doc('negocio-existente')
                  .get())
              .data()!;
      expect(perfil['negocioId'], 'negocio-existente');
      expect(negocio, {'propietarioUid': 'usuario-1', 'rubro': 'Bodega'});
    },
  );
}
