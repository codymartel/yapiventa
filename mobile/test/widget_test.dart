import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/main.dart';

class _AuthRepositoryFake extends Mock implements AuthRepository {}

class _UserFake extends Mock implements User {}

void main() {
  testWidgets('muestra la pantalla de inicio de sesión', (tester) async {
    final authRepository = _AuthRepositoryFake();
    final firestore = FakeFirebaseFirestore();
    when(
      () => authRepository.cambiosDeAuth,
    ).thenAnswer((_) => Stream.value(null));
    when(() => authRepository.usuarioActual).thenReturn(null);
    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YapiVenta'), findsOneWidget);
    expect(find.text('Ingresar con mi cuenta'), findsOneWidget);
    expect(find.text('Crear cuenta nueva'), findsOneWidget);
  });

  testWidgets('envía una sesión no verificada a verificación', (tester) async {
    final authRepository = _AuthRepositoryFake();
    final usuario = _UserFake();
    final firestore = FakeFirebaseFirestore();
    when(() => usuario.uid).thenReturn('usuario-1');
    when(() => usuario.email).thenReturn('ana@example.com');
    when(() => usuario.emailVerified).thenReturn(false);
    when(
      () => authRepository.cambiosDeAuth,
    ).thenAnswer((_) => Stream.value(usuario));
    when(() => authRepository.usuarioActual).thenReturn(usuario);
    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
        initialRoute: '/productos',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verifica tu correo'), findsOneWidget);
    expect(find.text('Productos'), findsNothing);
  });

  testWidgets('bloquea un salto directo y vuelve al dashboard pendiente', (
    tester,
  ) async {
    final authRepository = _AuthRepositoryFake();
    final usuario = _UserFake();
    final firestore = FakeFirebaseFirestore();
    when(() => usuario.uid).thenReturn('usuario-1');
    when(() => usuario.email).thenReturn('ana@example.com');
    when(() => usuario.emailVerified).thenReturn(true);
    when(
      () => authRepository.cambiosDeAuth,
    ).thenAnswer((_) => Stream.value(usuario));
    when(() => authRepository.usuarioActual).thenReturn(usuario);
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
    });

    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
        initialRoute: '/elegir-plantilla',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);
    expect(find.text('Continuar configuración'), findsOneWidget);
    expect(find.text('Elige el estilo\nde tu tienda'), findsNothing);
  });
}
