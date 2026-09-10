import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/auth/presentation/providers/acceso_provider.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart'
    as app_auth;
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_progreso_configuracion.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAuthProvider extends Mock implements app_auth.AuthProvider {}

class _MockProgresoRepository extends Mock
    implements RepositorioProgresoConfiguracion {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

void main() {
  late _MockAuthRepository authRepository;
  late _MockAuthProvider authProvider;
  late _MockUserRepository userRepository;
  late _MockProgresoRepository progresoRepository;
  late StreamController<User?> cambiosDeAuth;
  AccesoProvider? provider;

  setUp(() {
    authRepository = _MockAuthRepository();
    authProvider = _MockAuthProvider();
    userRepository = _MockUserRepository();
    progresoRepository = _MockProgresoRepository();
    cambiosDeAuth = StreamController<User?>();
    when(
      () => authRepository.cambiosDeAuth,
    ).thenAnswer((_) => cambiosDeAuth.stream);
    when(() => authProvider.isLoading).thenReturn(false);
    when(
      () => userRepository.existePerfil(any()),
    ).thenAnswer((_) async => true);
    when(
      () => userRepository.asegurarPerfilYPlan(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        webActivaInicial: any(named: 'webActivaInicial'),
        limiteProductos: any(named: 'limiteProductos'),
        minimoProductos: any(named: 'minimoProductos'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    provider?.dispose();
    await cambiosDeAuth.close();
  });

  test(
    'muestra error de lectura y permite reintentar con la sesión actual',
    () async {
      final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
      var intentos = 0;
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      when(
        () => progresoRepository.obtenerProgresoConfiguracion('usuario-1'),
      ).thenAnswer((_) async {
        intentos++;
        if (intentos == 1) throw Exception('Firestore no disponible');
        return _progreso(slug: 'bodega-ana');
      });
      provider = AccesoProvider(
        authRepository: authRepository,
        authProvider: authProvider,
        userRepository: userRepository,
        progresoRepository: progresoRepository,
      );

      cambiosDeAuth.add(usuario);
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.error);
      expect(provider!.progreso, isNull);
      expect(provider!.errorMessage, contains('No se pudo consultar'));

      await provider!.recargar();
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.progreso!.slug, 'bodega-ana');
      expect(provider!.errorMessage, isNull);
      verify(
        () => progresoRepository.obtenerProgresoConfiguracion('usuario-1'),
      ).called(2);
    },
  );

  test('ignora una respuesta antigua después de cambiar de sesión', () async {
    final usuarioAnterior = _usuario(
      uid: 'usuario-anterior',
      email: 'anterior@example.com',
    );
    final usuarioActual = _usuario(
      uid: 'usuario-actual',
      email: 'actual@example.com',
    );
    final respuestaAnterior = Completer<ProgresoConfiguracion>();
    final respuestaActual = Completer<ProgresoConfiguracion>();
    when(
      () => progresoRepository.obtenerProgresoConfiguracion('usuario-anterior'),
    ).thenAnswer((_) => respuestaAnterior.future);
    when(
      () => progresoRepository.obtenerProgresoConfiguracion('usuario-actual'),
    ).thenAnswer((_) => respuestaActual.future);
    provider = AccesoProvider(
      authRepository: authRepository,
      authProvider: authProvider,
      userRepository: userRepository,
      progresoRepository: progresoRepository,
    );

    cambiosDeAuth.add(usuarioAnterior);
    await pumpEventQueue();
    cambiosDeAuth.add(usuarioActual);
    await pumpEventQueue();
    respuestaActual.complete(_progreso(slug: 'tienda-actual'));
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.listo);
    expect(provider!.uid, 'usuario-actual');
    expect(provider!.email, 'actual@example.com');
    expect(provider!.progreso!.slug, 'tienda-actual');

    respuestaAnterior.complete(_progreso(slug: 'tienda-anterior'));
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.listo);
    expect(provider!.uid, 'usuario-actual');
    expect(provider!.progreso!.slug, 'tienda-actual');
    verifyNever(
      () => progresoRepository.sincronizarProgresoReconstruido(
        'usuario-anterior',
        setupComplete: any(named: 'setupComplete'),
        confirmarProductos: any(named: 'confirmarProductos'),
      ),
    );
  });

  test('aprovisiona una sesión de correo verificada sin perfil', () async {
    final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
    final proveedor = _MockUserInfo();
    when(() => proveedor.providerId).thenReturn(EmailAuthProvider.PROVIDER_ID);
    when(() => usuario.providerData).thenReturn([proveedor]);
    when(
      () => userRepository.existePerfil('usuario-1'),
    ).thenAnswer((_) async => false);
    when(
      () => progresoRepository.obtenerProgresoConfiguracion('usuario-1'),
    ).thenAnswer((_) async => _progreso(slug: ''));
    provider = AccesoProvider(
      authRepository: authRepository,
      authProvider: authProvider,
      userRepository: userRepository,
      progresoRepository: progresoRepository,
    );

    cambiosDeAuth.add(usuario);
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.listo);
    verify(
      () => userRepository.asegurarPerfilYPlan(
        uid: 'usuario-1',
        email: 'ana@example.com',
        webActivaInicial: true,
        limiteProductos: 20,
        minimoProductos: 1,
      ),
    ).called(1);
  });

  test('no autoriza una cuenta social sin perfil registrado', () async {
    final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
    final proveedor = _MockUserInfo();
    when(() => proveedor.providerId).thenReturn(GoogleAuthProvider.PROVIDER_ID);
    when(() => usuario.providerData).thenReturn([proveedor]);
    when(
      () => userRepository.existePerfil('usuario-1'),
    ).thenAnswer((_) async => false);
    provider = AccesoProvider(
      authRepository: authRepository,
      authProvider: authProvider,
      userRepository: userRepository,
      progresoRepository: progresoRepository,
    );

    cambiosDeAuth.add(usuario);
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.error);
    expect(provider!.errorMessage, contains('perfil registrado'));
    verifyNever(() => progresoRepository.obtenerProgresoConfiguracion(any()));
  });

  test('espera a que termine la operación de autenticación', () async {
    final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
    final respuestaLogin = Completer<User?>();
    when(
      () => authRepository.iniciarSesion(
        email: 'ana@example.com',
        password: 'secreto',
      ),
    ).thenAnswer((_) => respuestaLogin.future);
    when(
      () => authRepository.emailEstaVerificado(),
    ).thenAnswer((_) async => true);
    when(
      () => progresoRepository.obtenerProgresoConfiguracion('usuario-1'),
    ).thenAnswer((_) async => _progreso(slug: ''));
    final authProviderReal = app_auth.AuthProvider(
      repository: authRepository,
      userRepository: userRepository,
    );
    provider = AccesoProvider(
      authRepository: authRepository,
      authProvider: authProviderReal,
      userRepository: userRepository,
      progresoRepository: progresoRepository,
    );

    final login = authProviderReal.iniciarSesion(
      'ana@example.com',
      'secreto',
    );
    cambiosDeAuth.add(usuario);
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.cargandoSesion);
    verifyNever(() => progresoRepository.obtenerProgresoConfiguracion(any()));

    respuestaLogin.complete(usuario);
    await login;
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.listo);
    verify(
      () => progresoRepository.obtenerProgresoConfiguracion('usuario-1'),
    ).called(1);
    provider!.dispose();
    provider = null;
    authProviderReal.dispose();
  });
}

User _usuario({required String uid, required String email}) {
  final usuario = _MockUser();
  when(() => usuario.uid).thenReturn(uid);
  when(() => usuario.email).thenReturn(email);
  when(() => usuario.emailVerified).thenReturn(true);
  return usuario;
}

ProgresoConfiguracion _progreso({required String slug}) {
  return ProgresoConfiguracion(
    catalogo: CatalogoNegocio(
      rubro: '',
      categorias: const [],
      unidadesMedida: const [],
    ),
    slug: slug,
    plantilla: null,
    plantillaProvieneDeCampoOficial: false,
    rubroCompleto: false,
    negocioCompleto: false,
    productosCompletos: false,
    setupCompletePersistido: false,
    productosConfirmadosPersistidos: false,
  );
}
