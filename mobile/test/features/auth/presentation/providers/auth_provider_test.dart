import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/google_sign_in_service.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

class _AuthRepositoryMock extends Mock implements AuthRepository {}

class _UserRepositoryMock extends Mock implements UserRepository {}

class _GoogleSignInServiceMock extends Mock implements GoogleSignInService {}

class _UserMock extends Mock implements User {}

void main() {
  late _AuthRepositoryMock authRepository;
  late _UserRepositoryMock userRepository;
  late _GoogleSignInServiceMock googleSignInService;
  late AuthProvider provider;

  setUp(() {
    authRepository = _AuthRepositoryMock();
    userRepository = _UserRepositoryMock();
    googleSignInService = _GoogleSignInServiceMock();
    when(() => googleSignInService.cerrarSesionGoogle()).thenAnswer(
      (_) async {},
    );
    provider = AuthProvider(
      repository: authRepository,
      userRepository: userRepository,
      googleSignInService: googleSignInService,
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
      ).thenAnswer((_) async => (existiaPerfil: true, negocioId: null));

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

  group('registro con Google', () {
    test('crea el perfil y deja la sesión abierta', () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('nuevo@example.com');
      when(
        () => authRepository.autenticarConGoogle('id', 'access'),
      ).thenAnswer((_) async => usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.existePerfil('usuario-1'),
      ).thenAnswer((_) async => false);
      when(
        () => userRepository.asegurarPerfilYPlan(
          uid: 'usuario-1',
          email: 'nuevo@example.com',
          limiteProductos: 20,
          minimoProductos: 1,
        ),
      ).thenAnswer((_) async => (existiaPerfil: false, negocioId: null));

      await provider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: true,
      );

      expect(provider.status, AuthStatus.success);
      expect(provider.errorMessage, isNull);
      // El camino feliz NO cierra sesión: nada revierte lo que se logró.
      verifyNever(() => authRepository.cerrarSesion());
      verifyNever(() => googleSignInService.cerrarSesionGoogle());
    });

    test('si falla el perfil, cierra Firebase y limpia Google', () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('nuevo@example.com');
      when(
        () => authRepository.autenticarConGoogle('id', 'access'),
      ).thenAnswer((_) async => usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.existePerfil('usuario-1'),
      ).thenAnswer((_) async => false);
      when(
        () => userRepository.asegurarPerfilYPlan(
          uid: any(named: 'uid'),
          email: any(named: 'email'),
          limiteProductos: any(named: 'limiteProductos'),
          minimoProductos: any(named: 'minimoProductos'),
        ),
      ).thenThrow(Exception('Firestore no disponible'));
      when(() => authRepository.cerrarSesion()).thenAnswer((_) async {});

      await provider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: true,
      );

      // Sin esto quedaría una sesión de Firebase viva sin users/{uid}.
      verify(() => authRepository.cerrarSesion()).called(1);
      verify(() => googleSignInService.cerrarSesionGoogle()).called(1);
      expect(provider.status, AuthStatus.error);
      expect(provider.isLoading, isFalse);
    });

    test('el error reportado es el del perfil, no el genérico de Google', () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('nuevo@example.com');
      when(
        () => authRepository.autenticarConGoogle('id', 'access'),
      ).thenAnswer((_) async => usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.existePerfil('usuario-1'),
      ).thenAnswer((_) async => false);
      when(
        () => userRepository.asegurarPerfilYPlan(
          uid: any(named: 'uid'),
          email: any(named: 'email'),
          limiteProductos: any(named: 'limiteProductos'),
          minimoProductos: any(named: 'minimoProductos'),
        ),
      ).thenThrow(Exception('Firestore no disponible'));
      when(() => authRepository.cerrarSesion()).thenAnswer((_) async {});

      await provider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: true,
      );

      expect(provider.errorMessage, contains('Firestore no disponible'));
      expect(
        provider.errorMessage,
        isNot(contains('No se pudo completar el acceso con Google')),
      );
    });

    test('reporta el fallo del perfil aunque la limpieza también falle', () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('nuevo@example.com');
      when(
        () => authRepository.autenticarConGoogle('id', 'access'),
      ).thenAnswer((_) async => usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.existePerfil('usuario-1'),
      ).thenAnswer((_) async => false);
      when(
        () => userRepository.asegurarPerfilYPlan(
          uid: any(named: 'uid'),
          email: any(named: 'email'),
          limiteProductos: any(named: 'limiteProductos'),
          minimoProductos: any(named: 'minimoProductos'),
        ),
      ).thenThrow(Exception('Firestore no disponible'));
      when(
        () => authRepository.cerrarSesion(),
      ).thenThrow(Exception('Firebase tampoco responde'));

      await provider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: true,
      );

      expect(provider.status, AuthStatus.error);
      expect(provider.errorMessage, contains('Firestore no disponible'));
    });
  });

  group('login con Google', () {
    test('cuenta ya registrada entra sin escribir nada', () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(
        () => authRepository.autenticarConGoogle('id', 'access'),
      ).thenAnswer((_) async => usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.existePerfil('usuario-1'),
      ).thenAnswer((_) async => true);

      await provider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: false,
      );

      expect(provider.status, AuthStatus.success);
      expect(provider.errorMessage, isNull);
      // LOGIN nunca aprovisiona: ni perfil, ni plan, ni cierre de sesión.
      verifyNever(() => userRepository.asegurarPerfilYPlan(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        limiteProductos: any(named: 'limiteProductos'),
        minimoProductos: any(named: 'minimoProductos'),
        crearPerfilSiNoExiste: any(named: 'crearPerfilSiNoExiste'),
      ));
      verifyNever(() => authRepository.cerrarSesion());
    });

    test('cuenta no registrada cierra sesión y no crea nada', () async {
      final usuario = _UserMock();
      when(() => usuario.uid).thenReturn('desconocido');
      when(
        () => authRepository.autenticarConGoogle('id', 'access'),
      ).thenAnswer((_) async => usuario);
      when(
        () => authRepository.emailEstaVerificado(),
      ).thenAnswer((_) async => true);
      when(
        () => userRepository.existePerfil('desconocido'),
      ).thenAnswer((_) async => false);
      when(() => authRepository.cerrarSesion()).thenAnswer((_) async {});

      await provider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: false,
      );

      expect(provider.status, AuthStatus.error);
      expect(
        provider.errorMessage,
        'Esta cuenta aún no está registrada. Regístrate para crear tu negocio.',
      );
      expect(provider.isLoading, isFalse);
      // Se cierra la sesión que Google abrió, pero NO se escribe nada.
      verify(() => authRepository.cerrarSesion()).called(1);
      verifyNever(() => userRepository.asegurarPerfilYPlan(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        limiteProductos: any(named: 'limiteProductos'),
        minimoProductos: any(named: 'minimoProductos'),
        crearPerfilSiNoExiste: any(named: 'crearPerfilSiNoExiste'),
      ));
      verifyNever(() => userRepository.guardarPlanFree(
        uid: any(named: 'uid'),
        limiteProductos: any(named: 'limiteProductos'),
        minimoProductos: any(named: 'minimoProductos'),
      ));
    });
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
      ).thenAnswer((_) async => (existiaPerfil: false, negocioId: null));

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

  group('cerrar sesión', () {
    test('cierra Firebase y limpia la sesión de Google', () async {
      when(() => authRepository.cerrarSesion()).thenAnswer((_) async {});

      await provider.cerrarSesion();

      verify(() => authRepository.cerrarSesion()).called(1);
      verify(() => googleSignInService.cerrarSesionGoogle()).called(1);
      expect(provider.status, AuthStatus.idle);
      expect(provider.isLoading, isFalse);
    });

    test('también limpia Google para usuarios de correo y contraseña', () async {
      when(() => authRepository.cerrarSesion()).thenAnswer((_) async {});

      await provider.cerrarSesion();

      verify(() => googleSignInService.cerrarSesionGoogle()).called(1);
      expect(provider.status, AuthStatus.idle);
      expect(provider.errorMessage, isNull);
    });

    test(
      'si Google falla, el usuario sigue habiendo salido de Firebase',
      () async {
        when(() => authRepository.cerrarSesion()).thenAnswer((_) async {});
        when(
          () => googleSignInService.cerrarSesionGoogle(),
        ).thenThrow(Exception('Google no respondió'));

        await provider.cerrarSesion();

        // Firebase se cerró igual, y el logout NO se reporta como error.
        verify(() => authRepository.cerrarSesion()).called(1);
        expect(provider.status, AuthStatus.idle);
        expect(provider.errorMessage, isNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test('si Firebase falla, el error se reporta sin tocar Google', () async {
      when(
        () => authRepository.cerrarSesion(),
      ).thenThrow(Exception('Firebase no disponible'));

      await provider.cerrarSesion();

      expect(provider.status, AuthStatus.error);
      expect(provider.errorMessage, 'No se pudo cerrar la sesión. Intenta de nuevo.');
      verifyNever(() => googleSignInService.cerrarSesionGoogle());
    });

    test('ignora un segundo cierre de sesión concurrente', () async {
      final respuesta = Completer<void>();
      when(
        () => authRepository.cerrarSesion(),
      ).thenAnswer((_) => respuesta.future);

      final primero = provider.cerrarSesion();
      final segundo = provider.cerrarSesion();
      respuesta.complete();
      await Future.wait([primero, segundo]);

      verify(() => authRepository.cerrarSesion()).called(1);
      verify(() => googleSignInService.cerrarSesionGoogle()).called(1);
    });
  });
}
