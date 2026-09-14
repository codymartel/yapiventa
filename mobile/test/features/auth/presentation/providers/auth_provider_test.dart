import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

class _AuthRepositoryMock extends Mock implements AuthRepository {}

class _UserRepositoryMock extends Mock implements UserRepository {}

class _UserMock extends Mock implements User {}

void main() {
  late _AuthRepositoryMock authRepository;
  late _UserRepositoryMock userRepository;
  late AuthProvider provider;

  setUp(() {
    authRepository = _AuthRepositoryMock();
    userRepository = _UserRepositoryMock();
    provider = AuthProvider(
      repository: authRepository,
      userRepository: userRepository,
    );
  });

  tearDown(() => provider.dispose());

  test('login no verificado conserva la sesión para verificar', () async {
    when(
      () => authRepository.iniciarSesion(
        email: 'ana@example.com',
        password: 'secreto',
      ),
    ).thenAnswer((_) async => null);
    when(
      () => authRepository.emailEstaVerificado(),
    ).thenAnswer((_) async => false);

    await provider.iniciarSesion('ana@example.com', 'secreto');

    expect(provider.status, AuthStatus.emailNotVerified);
    expect(provider.isLoading, isFalse);
  });

  test('ignora un segundo login mientras el primero está pendiente', () async {
    final respuesta = Completer<User?>();
    when(
      () => authRepository.iniciarSesion(
        email: 'ana@example.com',
        password: 'secreto',
      ),
    ).thenAnswer((_) => respuesta.future);
    when(
      () => authRepository.emailEstaVerificado(),
    ).thenAnswer((_) async => true);

    final primero = provider.iniciarSesion('ana@example.com', 'secreto');
    final segundo = provider.iniciarSesion('ana@example.com', 'secreto');
    respuesta.complete(null);
    await Future.wait([primero, segundo]);

    verify(
      () => authRepository.iniciarSesion(
        email: 'ana@example.com',
        password: 'secreto',
      ),
    ).called(1);
    expect(provider.status, AuthStatus.success);
  });

  test(
    'verificación confirmada aprovisiona el perfil de forma idempotente',
    () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('ana@example.com');
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.asegurarPerfilYPlan(
          uid: 'usuario-1',
          email: 'ana@example.com',
          limiteProductos: 20,
          minimoProductos: 1,
        ),
      ).thenAnswer((_) async {});

      await provider.revisarSiYaVerificoEmail();

      expect(provider.status, AuthStatus.success);
      verify(
        () => userRepository.asegurarPerfilYPlan(
          uid: 'usuario-1',
          email: 'ana@example.com',
          limiteProductos: 20,
          minimoProductos: 1,
        ),
      ).called(1);
    },
  );

  test('no asume que Google esté verificado por el proveedor', () async {
    final usuario = _UserMock();
    when(
      () => authRepository.autenticarConGoogle('id', 'access'),
    ).thenAnswer((_) async => usuario);
    when(
      () => authRepository.emailEstaVerificado(),
    ).thenAnswer((_) async => false);

    await provider.autenticarConGoogle('id', 'access', esModoRegistro: true);

    expect(provider.status, AuthStatus.emailNotVerified);
    verifyNever(() => userRepository.existePerfil(any()));
  });

  test(
    'negocioYaConfigurado delega en setupCompleto del repositorio',
    () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      when(
        () => userRepository.setupCompleto('usuario-1'),
      ).thenAnswer((_) async => true);

      expect(await provider.negocioYaConfigurado(), isTrue);
      verify(() => userRepository.setupCompleto('usuario-1')).called(1);
    },
  );

  test('negocioYaConfigurado es false sin sesión activa', () async {
    when(() => authRepository.usuarioActual).thenReturn(null);

    expect(await provider.negocioYaConfigurado(), isFalse);
    verifyNever(() => userRepository.setupCompleto(any()));
  });

  test('registrarse crea solamente el perfil y el plan de la cuenta', () async {
    final usuario = _UserMock();
    when(() => usuario.uid).thenReturn('usuario-1');
    when(() => usuario.email).thenReturn('nuevo@example.com');
    when(
      () => authRepository.registrarse(
        email: 'nuevo@example.com',
        password: 'secreto',
      ),
    ).thenAnswer((_) async => usuario);
    when(
      () => userRepository.asegurarPerfilYPlan(
        uid: 'usuario-1',
        email: 'nuevo@example.com',
        limiteProductos: 20,
        minimoProductos: 1,
      ),
    ).thenAnswer((_) async {});

    await provider.registrarse('nuevo@example.com', 'secreto');

    expect(provider.status, AuthStatus.emailNotVerified);
    verify(
      () => userRepository.asegurarPerfilYPlan(
        uid: 'usuario-1',
        email: 'nuevo@example.com',
        limiteProductos: 20,
        minimoProductos: 1,
      ),
    ).called(1);
  });

  test(
    'registrarse falla en estado de error si no se puede aprovisionar',
    () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('nuevo@example.com');
      when(
        () => authRepository.registrarse(
          email: 'nuevo@example.com',
          password: 'secreto',
        ),
      ).thenAnswer((_) async => usuario);
      when(
        () => userRepository.asegurarPerfilYPlan(
          uid: any(named: 'uid'),
          email: any(named: 'email'),
          limiteProductos: any(named: 'limiteProductos'),
          minimoProductos: any(named: 'minimoProductos'),
        ),
      ).thenThrow(Exception('Firestore no disponible'));

      await provider.registrarse('nuevo@example.com', 'secreto');

      expect(provider.status, AuthStatus.error);
      expect(provider.isLoading, isFalse);
    },
  );
}
