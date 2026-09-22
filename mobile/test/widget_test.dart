import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/auth/presentation/providers/acceso_provider.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/catalogo_negocio_dependencies.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/presentation/screens/configuracion_negocio_screen.dart';
import 'package:mobile/features/productos/application/use_cases/cambiar_disponibilidad_producto.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/eliminar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/obtener_pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/presentation/screens/productos_screen.dart';
import 'package:mobile/features/productos/productos_dependencies.dart';
import 'package:mobile/main.dart';
import 'package:provider/provider.dart';

class _AuthRepositoryFake extends Mock implements AuthRepository {}

class _UserFake extends Mock implements User {}

class _NegocioRepositoryConRecargas extends NegocioRepository {
  _NegocioRepositoryConRecargas({
    required super.firestore,
    required this.enLectura,
  });

  final Future<ProgresoConfiguracion> Function() enLectura;

  @override
  Future<ProgresoConfiguracion> obtenerProgresoConfiguracion(
    String uid, {
    String? negocioId,
  }) {
    return enLectura();
  }
}

class _ProductosDependenciesFake extends Mock
    implements ProductosDependencies {}

class _CatalogoNegocioDependenciesFake extends Mock
    implements CatalogoNegocioDependencies {}

class _ObtenerPaginaProductosFake extends Mock
    implements ObtenerPaginaProductos {}

class _ObtenerCatalogoNegocioFake extends Mock
    implements ObtenerCatalogoNegocio {}

class _CambiarDisponibilidadFake extends Mock
    implements CambiarDisponibilidadProducto {}

class _CrearProductoFake extends Mock implements CrearProducto {}

class _EditarProductoFake extends Mock implements EditarProducto {}

class _EliminarProductoFake extends Mock implements EliminarProducto {}

({ProductosDependencies productos, CatalogoNegocioDependencies catalogo})
_crearDependenciasProductosVacias() {
  final obtenerPagina = _ObtenerPaginaProductosFake();
  final productos = _ProductosDependenciesFake();
  final catalogo = _CatalogoNegocioDependenciesFake();

  when(
    () => obtenerPagina(
      negocioId: any(named: 'negocioId'),
      despuesDe: any(named: 'despuesDe'),
      limite: any(named: 'limite'),
    ),
  ).thenAnswer(
    (_) async =>
        PaginaProductos(productos: const [], ultimoCursor: null, hayMas: false),
  );
  when(() => productos.obtenerPaginaProductos).thenReturn(obtenerPagina);
  when(
    () => productos.cambiarDisponibilidadProducto,
  ).thenReturn(_CambiarDisponibilidadFake());
  when(() => productos.crearProducto).thenReturn(_CrearProductoFake());
  when(() => productos.editarProducto).thenReturn(_EditarProductoFake());
  when(() => productos.eliminarProducto).thenReturn(_EliminarProductoFake());
  when(
    () => catalogo.obtenerCatalogoNegocio,
  ).thenReturn(_ObtenerCatalogoNegocioFake());

  return (productos: productos, catalogo: catalogo);
}

ProgresoConfiguracion _progresoPendiente() => ProgresoConfiguracion(
  catalogo: CatalogoNegocio(
    rubro: '',
    categorias: const [],
    unidadesMedida: const [],
  ),
  slug: '',
  plantilla: null,
  plantillaProvieneDeCampoOficial: false,
  rubroCompleto: false,
  negocioCompleto: false,
  productosCompletos: false,
  setupCompletePersistido: false,
  productosConfirmadosPersistidos: false,
);

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
    when(() => usuario.providerData).thenReturn(const []);
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

  testWidgets('una recarga en segundo plano conserva el shell autenticado', (
    tester,
  ) async {
    final authRepository = _AuthRepositoryFake();
    final usuario = _UserFake();
    final firestore = FakeFirebaseFirestore();
    when(() => usuario.uid).thenReturn('usuario-1');
    when(() => usuario.email).thenReturn('ana@example.com');
    when(() => usuario.emailVerified).thenReturn(true);
    when(() => usuario.providerData).thenReturn(const []);
    when(
      () => authRepository.cambiosDeAuth,
    ).thenAnswer((_) => Stream.value(usuario));
    when(() => authRepository.usuarioActual).thenReturn(usuario);
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
    });

    final recargaCongelada = Completer<ProgresoConfiguracion>();
    var lecturas = 0;
    final negocioRepository = _NegocioRepositoryConRecargas(
      firestore: firestore,
      enLectura: () async {
        lecturas++;
        if (lecturas == 1) return _progresoPendiente();
        return recargaCongelada.future;
      },
    );

    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: negocioRepository,
        initialRoute: '/home',
      ),
    );
    await tester.pumpAndSettle();

    expect(lecturas, 1);
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.text('Continuar configuración'), findsOneWidget);

    final contexto = tester.element(
      find.byKey(const Key('authenticated-shell')),
    );
    final acceso = contexto.read<AccesoProvider>();
    final recarga = acceso.recargar();

    await tester.pump();

    expect(acceso.estado, EstadoAcceso.cargandoProgreso);
    expect(acceso.refrescando, isTrue);
    expect(acceso.progreso, isNotNull);
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.text('Continuar configuración'), findsOneWidget);

    recargaCongelada.complete(_progresoPendiente());
    await recarga;
    await tester.pumpAndSettle();

    expect(lecturas, 2);
    expect(acceso.estado, EstadoAcceso.listo);
    expect(acceso.refrescando, isFalse);
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.text('Continuar configuración'), findsOneWidget);
  });

  testWidgets('la ruta raíz /configurar-negocio sigue funcionando directa', (
    tester,
  ) async {
    final authRepository = _AuthRepositoryFake();
    final usuario = _UserFake();
    final firestore = FakeFirebaseFirestore();
    when(() => usuario.uid).thenReturn('usuario-1');
    when(() => usuario.email).thenReturn('ana@example.com');
    when(() => usuario.emailVerified).thenReturn(true);
    when(() => usuario.providerData).thenReturn(const []);
    when(
      () => authRepository.cambiosDeAuth,
    ).thenAnswer((_) => Stream.value(usuario));
    when(() => authRepository.usuarioActual).thenReturn(usuario);
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    await firestore.collection('negocios').doc('negocio-1').set({
      'rubro': 'Bodega',
    });

    await tester.pumpWidget(
      MyApp(
        authRepository: authRepository,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
        initialRoute: '/configurar-negocio',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConfiguracionNegocioScreen), findsOneWidget);
    expect(find.text('Configura tu Bodega'), findsOneWidget);
  });

  testWidgets(
    'la ruta raíz /productos sigue funcionando como pantalla directa',
    (tester) async {
      final authRepository = _AuthRepositoryFake();
      final usuario = _UserFake();
      final firestore = FakeFirebaseFirestore();
      when(() => usuario.uid).thenReturn('usuario-1');
      when(() => usuario.email).thenReturn('ana@example.com');
      when(() => usuario.emailVerified).thenReturn(true);
      when(() => usuario.providerData).thenReturn(const []);
      when(
        () => authRepository.cambiosDeAuth,
      ).thenAnswer((_) => Stream.value(usuario));
      when(() => authRepository.usuarioActual).thenReturn(usuario);
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'negocioId': 'negocio-1',
      });
      await firestore.collection('negocios').doc('negocio-1').set({
        'rubro': 'Bodega',
        'nombreNegocio': 'Bodega Ana',
        'telefono': '999999999',
        'direccion': 'Av Lima 123',
        'categorias': ['Bebidas'],
        'unidadesMedida': [
          {
            'nombre': 'Unidad',
            'tipo': 'entera',
            'fraccionesPermitidas': <String>[],
            'esOpcional': false,
          },
        ],
        'onboardingBusinessRubro': 'Bodega',
        'slug': '',
      });
      final dependencias = _crearDependenciasProductosVacias();

      await tester.pumpWidget(
        MyApp(
          authRepository: authRepository,
          userRepository: UserRepository(firestore: firestore),
          negocioRepository: NegocioRepository(firestore: firestore),
          productosDependencies: dependencias.productos,
          catalogoDependencies: dependencias.catalogo,
          initialRoute: '/productos',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductosScreen), findsOneWidget);
      expect(find.text('Todavía no tienes productos.'), findsOneWidget);
      expect(find.text('Inicia sesion para ver tus productos.'), findsNothing);
    },
  );
}
