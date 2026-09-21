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
      () => userRepository.asegurarPerfilYPlan(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        limiteProductos: any(named: 'limiteProductos'),
        minimoProductos: any(named: 'minimoProductos'),
        crearPerfilSiNoExiste: any(named: 'crearPerfilSiNoExiste'),
      ),
    ).thenAnswer((_) async => (existiaPerfil: true, negocioId: null));
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
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-1',
          negocioId: any(named: 'negocioId'),
        ),
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
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-1',
          negocioId: any(named: 'negocioId'),
        ),
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
      () => progresoRepository.obtenerProgresoConfiguracion(
        'usuario-anterior',
        negocioId: any(named: 'negocioId'),
      ),
    ).thenAnswer((_) => respuestaAnterior.future);
    when(
      () => progresoRepository.obtenerProgresoConfiguracion(
        'usuario-actual',
        negocioId: any(named: 'negocioId'),
      ),
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
        negocioId: any(named: 'negocioId'),
      ),
    );
  });

  test('aprovisiona una sesión de correo verificada sin perfil', () async {
    final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
    final proveedor = _MockUserInfo();
    when(() => proveedor.providerId).thenReturn(EmailAuthProvider.PROVIDER_ID);
    when(() => usuario.providerData).thenReturn([proveedor]);
    when(
      () => progresoRepository.obtenerProgresoConfiguracion(
        'usuario-1',
        negocioId: any(named: 'negocioId'),
      ),
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
        limiteProductos: 20,
        minimoProductos: 1,
        crearPerfilSiNoExiste: true,
      ),
    ).called(1);
  });

  test('no autoriza una cuenta social sin perfil registrado', () async {
    final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
    final proveedor = _MockUserInfo();
    when(() => proveedor.providerId).thenReturn(GoogleAuthProvider.PROVIDER_ID);
    when(() => usuario.providerData).thenReturn([proveedor]);
    when(
      () => userRepository.asegurarPerfilYPlan(
        uid: any(named: 'uid'),
        email: any(named: 'email'),
        limiteProductos: any(named: 'limiteProductos'),
        minimoProductos: any(named: 'minimoProductos'),
        crearPerfilSiNoExiste: any(named: 'crearPerfilSiNoExiste'),
      ),
    ).thenAnswer((_) async => (existiaPerfil: false, negocioId: null));
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
    verifyNever(
      () => progresoRepository.obtenerProgresoConfiguracion(
        any(),
        negocioId: any(named: 'negocioId'),
      ),
    );
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
      () => progresoRepository.obtenerProgresoConfiguracion(
        'usuario-1',
        negocioId: any(named: 'negocioId'),
      ),
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

    final login = authProviderReal.iniciarSesion('ana@example.com', 'secreto');
    cambiosDeAuth.add(usuario);
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.cargandoSesion);
    verifyNever(
      () => progresoRepository.obtenerProgresoConfiguracion(
        any(),
        negocioId: any(named: 'negocioId'),
      ),
    );

    respuestaLogin.complete(usuario);
    await login;
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.listo);
    verify(
      () => progresoRepository.obtenerProgresoConfiguracion(
        'usuario-1',
        negocioId: any(named: 'negocioId'),
      ),
    ).called(1);
    provider!.dispose();
    provider = null;
    authProviderReal.dispose();
  });

  test(
    'dos guardados concurrentes de Rubro comparten una sola operación',
    () async {
      final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
      final guardado = Completer<void>();
      final progresoTrasGuardar = Completer<ProgresoConfiguracion>();
      var lecturasProgreso = 0;
      var escriturasRubro = 0;
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      when(
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-1',
          negocioId: any(named: 'negocioId'),
        ),
      ).thenAnswer((_) async {
        lecturasProgreso++;
        if (lecturasProgreso == 1) return _progreso(slug: '');
        return progresoTrasGuardar.future;
      });
      when(
        () => progresoRepository.guardarRubro('usuario-1', 'Bodega'),
      ).thenAnswer((_) {
        escriturasRubro++;
        return guardado.future;
      });
      provider = AccesoProvider(
        authRepository: authRepository,
        authProvider: authProvider,
        userRepository: userRepository,
        progresoRepository: progresoRepository,
      );
      cambiosDeAuth.add(usuario);
      await pumpEventQueue();

      final primero = provider!.guardarRubro('Bodega');
      final segundo = provider!.guardarRubro('Bodega');
      expect(escriturasRubro, 1);
      guardado.complete();
      await pumpEventQueue();
      expect(provider!.estado, EstadoAcceso.cargandoProgreso);
      final tercero = provider!.guardarRubro(' Bodega ');
      expect(escriturasRubro, 1);
      progresoTrasGuardar.complete(_progreso(slug: '', rubroCompleto: true));

      expect(await primero, isTrue);
      expect(await segundo, isTrue);
      expect(await tercero, isTrue);
      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.progreso!.rubroCompleto, isTrue);
      expect(provider!.progreso!.siguiente, EtapaConfiguracion.negocio);
    },
  );

  test('la carga inicial queda pendiente sin marcar refrescando', () async {
    final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
    final respuesta = Completer<ProgresoConfiguracion>();
    when(
      () => progresoRepository.obtenerProgresoConfiguracion(
        'usuario-1',
        negocioId: any(named: 'negocioId'),
      ),
    ).thenAnswer((_) => respuesta.future);
    provider = AccesoProvider(
      authRepository: authRepository,
      authProvider: authProvider,
      userRepository: userRepository,
      progresoRepository: progresoRepository,
    );

    cambiosDeAuth.add(usuario);
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.cargandoProgreso);
    expect(provider!.refrescando, isFalse);
    expect(provider!.progreso, isNull);

    respuesta.complete(_progreso(slug: 'bodega-ana'));
    await pumpEventQueue();

    expect(provider!.estado, EstadoAcceso.listo);
    expect(provider!.refrescando, isFalse);
    expect(provider!.progreso!.slug, 'bodega-ana');
  });

  test(
    'recargar conserva el progreso del mismo usuario mientras refresca',
    () async {
      final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
      final primera = Completer<ProgresoConfiguracion>();
      final segunda = Completer<ProgresoConfiguracion>();
      var lectura = 0;
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      when(
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-1',
          negocioId: any(named: 'negocioId'),
        ),
      ).thenAnswer((_) {
        lectura++;
        return lectura == 1 ? primera.future : segunda.future;
      });
      provider = AccesoProvider(
        authRepository: authRepository,
        authProvider: authProvider,
        userRepository: userRepository,
        progresoRepository: progresoRepository,
      );

      cambiosDeAuth.add(usuario);
      await pumpEventQueue();
      primera.complete(_progreso(slug: 'bodega-ana'));
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.progreso!.slug, 'bodega-ana');

      final recarga = provider!.recargar();
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.cargandoProgreso);
      expect(provider!.refrescando, isTrue);
      expect(provider!.progreso, isNotNull);
      expect(provider!.progreso!.slug, 'bodega-ana');

      segunda.complete(_progreso(slug: 'bodega-renovada', rubroCompleto: true));
      await recarga;
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.refrescando, isFalse);
      expect(provider!.progreso!.slug, 'bodega-renovada');
      expect(lectura, 2);
    },
  );

  test(
    'cambiar de usuario descarta el progreso anterior de inmediato',
    () async {
      final usuarioA = _usuario(uid: 'usuario-a', email: 'a@example.com');
      final usuarioB = _usuario(uid: 'usuario-b', email: 'b@example.com');
      final respuestaB = Completer<ProgresoConfiguracion>();
      when(
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-a',
          negocioId: any(named: 'negocioId'),
        ),
      ).thenAnswer((_) async => _progreso(slug: 'tienda-a'));
      when(
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-b',
          negocioId: any(named: 'negocioId'),
        ),
      ).thenAnswer((_) => respuestaB.future);
      provider = AccesoProvider(
        authRepository: authRepository,
        authProvider: authProvider,
        userRepository: userRepository,
        progresoRepository: progresoRepository,
      );

      cambiosDeAuth.add(usuarioA);
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.progreso!.slug, 'tienda-a');

      cambiosDeAuth.add(usuarioB);
      await pumpEventQueue();

      expect(provider!.uid, 'usuario-b');
      expect(provider!.refrescando, isFalse);
      expect(provider!.progreso, isNull);
      expect(provider!.estado, EstadoAcceso.cargandoProgreso);

      respuestaB.complete(_progreso(slug: 'tienda-b'));
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.progreso!.slug, 'tienda-b');
    },
  );

  test(
    'un error durante la recarga descarta el progreso y no deja datos ajenos',
    () async {
      final usuario = _usuario(uid: 'usuario-1', email: 'ana@example.com');
      var lectura = 0;
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      when(
        () => progresoRepository.obtenerProgresoConfiguracion(
          'usuario-1',
          negocioId: any(named: 'negocioId'),
        ),
      ).thenAnswer((_) async {
        lectura++;
        if (lectura == 1) return _progreso(slug: 'tienda-ana');
        throw Exception('Firestore no disponible');
      });
      provider = AccesoProvider(
        authRepository: authRepository,
        authProvider: authProvider,
        userRepository: userRepository,
        progresoRepository: progresoRepository,
      );

      cambiosDeAuth.add(usuario);
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.listo);
      expect(provider!.progreso!.slug, 'tienda-ana');

      await provider!.recargar();
      await pumpEventQueue();

      expect(provider!.estado, EstadoAcceso.error);
      expect(provider!.refrescando, isFalse);
      expect(provider!.progreso, isNull);
      expect(provider!.errorMessage, contains('No se pudo consultar'));
    },
  );
}

User _usuario({required String uid, required String email}) {
  final usuario = _MockUser();
  when(() => usuario.uid).thenReturn(uid);
  when(() => usuario.email).thenReturn(email);
  when(() => usuario.emailVerified).thenReturn(true);
  when(() => usuario.providerData).thenReturn(const []);
  return usuario;
}

ProgresoConfiguracion _progreso({
  required String slug,
  bool rubroCompleto = false,
}) {
  return ProgresoConfiguracion(
    catalogo: CatalogoNegocio(
      rubro: rubroCompleto ? 'Bodega' : '',
      categorias: const [],
      unidadesMedida: const [],
    ),
    slug: slug,
    plantilla: null,
    plantillaProvieneDeCampoOficial: false,
    rubroCompleto: rubroCompleto,
    negocioCompleto: false,
    productosCompletos: false,
    setupCompletePersistido: false,
    productosConfirmadosPersistidos: false,
  );
}
