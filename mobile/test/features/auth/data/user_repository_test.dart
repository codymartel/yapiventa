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
      webActivaInicial: true,
    );

    final perfil = await firestore.collection('users').doc('usuario-1').get();

    expect(perfil.exists, isTrue);
    expect(perfil.data(), containsPair('email', 'ana@example.com'));
    expect(perfil.data(), containsPair('terminosAceptados', true));
    expect(perfil.data()?['createdAt'], isA<Timestamp>());
    final negocioId = perfil.data()?['negocioId'];
    expect(negocioId, isA<String>());
    expect(perfil.data()!.keys.toSet().difference({
      'email',
      'terminosAceptados',
      'createdAt',
      'negocioId',
    }), isEmpty);

    final negocio = await firestore
        .collection('negocios')
        .doc(negocioId as String)
        .get();
    expect(negocio.exists, isTrue);
    expect(negocio.data(), containsPair('setupComplete', false));
    expect(negocio.data(), containsPair('webActiva', true));
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

  test('reintentar la creación del perfil no reinicia el onboarding', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'anterior@example.com',
      'setupComplete': true,
      'webActiva': false,
      'rubro': 'Bodega',
    });

    await repository.crearPerfilEnFirestore(
      uid: 'usuario-1',
      email: 'ana@example.com',
      webActivaInicial: true,
    );

    final datos = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(datos['email'], 'ana@example.com');
    expect(datos['setupComplete'], isTrue);
    expect(datos['webActiva'], isFalse);
    expect(datos['rubro'], 'Bodega');
  });

  test('repara perfil y plan de forma idempotente', () async {
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'anterior@example.com',
      'rubro': 'Bodega',
    });

    await repository.asegurarPerfilYPlan(
      uid: 'usuario-1',
      email: 'ana@example.com',
      webActivaInicial: true,
      limiteProductos: 20,
      minimoProductos: 1,
    );
    final perfilInicial =
        (await firestore.collection('users').doc('usuario-1').get()).data()!;
    final negocioInicial = await firestore
        .collection('negocios')
        .doc(perfilInicial['negocioId'] as String)
        .get();
    final planInicial = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('plan')
        .doc('actual')
        .get();
    await repository.asegurarPerfilYPlan(
      uid: 'usuario-1',
      email: 'ana@example.com',
      webActivaInicial: false,
      limiteProductos: 999,
      minimoProductos: 99,
    );

    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    final negocioFinal = await firestore
        .collection('negocios')
        .doc(perfil['negocioId'] as String)
        .get();
    final planFinal = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('plan')
        .doc('actual')
        .get();
    expect(perfil['email'], 'ana@example.com');
    expect(perfil['rubro'], 'Bodega');
    expect(perfil['setupComplete'], isNull);
    expect(perfil['webActiva'], isNull);
    expect(perfil['negocioId'], perfilInicial['negocioId']);
    expect(negocioInicial.exists, isTrue);
    expect(negocioFinal.data(), negocioInicial.data());
    expect(planFinal.data(), planInicial.data());
    expect(planFinal.data()?['limiteProductos'], 20);
  });

  test('crea users/{uid} minimo y negocios/{negocioId} al registrarse', () async {
    await repository.asegurarPerfilYPlan(
      uid: 'usuario-nuevo',
      email: 'nuevo@example.com',
      webActivaInicial: true,
      limiteProductos: 20,
      minimoProductos: 1,
    );

    final perfil = (await firestore.collection('users').doc('usuario-nuevo').get())
        .data()!;
    expect(perfil, containsPair('email', 'nuevo@example.com'));
    expect(perfil, containsPair('terminosAceptados', true));
    expect(perfil, containsPair('negocioId', isA<String>()));
    expect(perfil['createdAt'], isA<Timestamp>());
    expect(perfil.keys.toSet().difference({
      'email',
      'terminosAceptados',
      'createdAt',
      'negocioId',
    }), isEmpty);

    final negocio = (await firestore
            .collection('negocios')
            .doc(perfil['negocioId'] as String)
            .get())
        .data()!;
    expect(negocio, containsPair('propietarioUid', 'usuario-nuevo'));
    expect(negocio, containsPair('setupComplete', false));
    expect(negocio, containsPair('webActiva', true));
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
