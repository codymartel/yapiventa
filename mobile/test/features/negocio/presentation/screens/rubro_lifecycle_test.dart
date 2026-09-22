import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/auth/domain/politica_acceso.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_negocio_screen.dart';
import 'package:mobile/main.dart';

class _AuthRepositoryMock extends Mock implements AuthRepository {}

class _UserMock extends Mock implements User {}

void main() {
  testWidgets('usuario verificado sin negocioId entra al dashboard en Rubro', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final authRepository = _authRepositoryVerificado();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'terminosAceptados': true,
      'createdAt': Timestamp.now(),
    });

    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);
    expect(find.text('Rubro'), findsOneWidget);
    expect(find.text('Configurar negocio'), findsOneWidget);
    expect(find.text('Siguiente etapa pendiente.'), findsOneWidget);
    expect(find.text('Requiere un rubro guardado.'), findsOneWidget);
    expect((await firestore.collection('negocios').get()).docs, isEmpty);
    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(perfil.containsKey('negocioId'), isFalse);
  });

  testWidgets('guardar Rubro vuelve al dashboard y desbloquea Configuración', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final authRepository = _authRepositoryVerificado();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'terminosAceptados': true,
      'createdAt': Timestamp.now(),
    });

    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continuar-configuracion')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bodega'));
    await tester.pump();
    await tester.ensureVisible(find.text('Confirmar rubro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar rubro'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);
    expect(find.text('Configurar negocio'), findsOneWidget);
    expect(find.text('¿A qué se dedica\ntu negocio?'), findsNothing);
    expect(find.text('Completado. Puedes revisarlo.'), findsOneWidget);
    expect(find.text('Siguiente etapa pendiente.'), findsOneWidget);
    expect(find.text('Requiere un rubro guardado.'), findsNothing);
    final negocios = await firestore.collection('negocios').get();
    expect(negocios.docs, hasLength(1));
    final perfil = (await firestore.collection('users').doc('usuario-1').get())
        .data()!;
    expect(perfil['negocioId'], negocios.docs.single.id);

    expect(
      find.text('Requiere la configuración obligatoria del negocio.'),
      findsOneWidget,
    );
    expect(find.text('Requiere al menos un producto válido.'), findsOneWidget);

    await tester.tap(find.text('Agregar productos').first);
    await tester.pump();
    expect(find.text('Lista de productos'), findsNothing);

    await tester.tap(find.text('Plantilla web').first);
    await tester.pump();
    expect(find.text('Seleccion de plantilla'), findsNothing);
  });

  testWidgets(
    'la ruta raíz /elegir-rubro sigue usando SeleccionNegocioScreen',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final authRepository = _authRepositoryVerificado();
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'terminosAceptados': true,
        'createdAt': Timestamp.now(),
      });

      await tester.pumpWidget(
        MyApp(
          initialRoute: RutasAcceso.rubro,
          authRepository: authRepository,
          userRepository: UserRepository(firestore: firestore),
          negocioRepository: NegocioRepository(firestore: firestore),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionNegocioScreen), findsOneWidget);
      expect(find.text('¿A qué se dedica\ntu negocio?'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-setup-panel')), findsNothing);
    },
  );
}

AuthRepository _authRepositoryVerificado() {
  final repository = _AuthRepositoryMock();
  final usuario = _UserMock();
  when(() => usuario.uid).thenReturn('usuario-1');
  when(() => usuario.email).thenReturn('ana@example.com');
  when(() => usuario.emailVerified).thenReturn(true);
  when(() => usuario.providerData).thenReturn(const []);
  when(() => repository.usuarioActual).thenReturn(usuario);
  when(() => repository.cambiosDeAuth).thenAnswer((_) => Stream.value(usuario));
  return repository;
}
