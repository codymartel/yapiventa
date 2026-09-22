import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/catalogo_negocio_dependencies.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/presentation/providers/catalogo_negocio_provider.dart';
import 'package:mobile/features/productos/application/use_cases/cambiar_disponibilidad_producto.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/eliminar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/obtener_pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/screens/productos_screen.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario_producto.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_content.dart';
import 'package:mobile/features/productos/productos_dependencies.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _ProductosDependenciesMock extends Mock
    implements ProductosDependencies {}

class _CatalogoNegocioDependenciesMock extends Mock
    implements CatalogoNegocioDependencies {}

class _ObtenerCatalogoNegocioMock extends Mock
    implements ObtenerCatalogoNegocio {}

class _ObtenerPaginaProductosMock extends Mock
    implements ObtenerPaginaProductos {}

class _CambiarDisponibilidadMock extends Mock
    implements CambiarDisponibilidadProducto {}

class _CrearProductoMock extends Mock implements CrearProducto {}

class _EditarProductoMock extends Mock implements EditarProducto {}

class _EliminarProductoMock extends Mock implements EliminarProducto {}

void main() {
  late _ProductosDependenciesMock productosDependencies;
  late _CatalogoNegocioDependenciesMock catalogoDependencies;
  late _ObtenerCatalogoNegocioMock obtenerCatalogo;
  late _ObtenerPaginaProductosMock obtenerPagina;

  setUp(() {
    productosDependencies = _ProductosDependenciesMock();
    catalogoDependencies = _CatalogoNegocioDependenciesMock();
    obtenerCatalogo = _ObtenerCatalogoNegocioMock();
    obtenerPagina = _ObtenerPaginaProductosMock();

    final catalogo = CatalogoNegocio(
      rubro: 'Cafetería',
      categorias: const ['Bebidas'],
      unidadesMedida: const [
        UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      ],
    );
    final producto = Producto(
      id: 'producto-1',
      negocioId: 'usuario-1',
      nombre: 'Café molido',
      precio: 18.5,
      stock: 12,
      categoria: 'Bebidas',
      unidadMedidaNombre: 'Unidad',
    );

    when(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).thenAnswer(
      (_) async => PaginaProductos(
        productos: [producto],
        ultimoCursor: null,
        hayMas: true,
      ),
    );
    when(() => obtenerCatalogo(any())).thenAnswer((_) async => catalogo);

    when(
      () => productosDependencies.obtenerPaginaProductos,
    ).thenReturn(obtenerPagina);
    when(
      () => productosDependencies.cambiarDisponibilidadProducto,
    ).thenReturn(_CambiarDisponibilidadMock());
    when(
      () => productosDependencies.crearProducto,
    ).thenReturn(_CrearProductoMock());
    when(
      () => productosDependencies.editarProducto,
    ).thenReturn(_EditarProductoMock());
    when(
      () => productosDependencies.eliminarProducto,
    ).thenReturn(_EliminarProductoMock());
    when(
      () => catalogoDependencies.obtenerCatalogoNegocio,
    ).thenReturn(obtenerCatalogo);
  });

  CatalogoNegocio crearCatalogo() => CatalogoNegocio(
    rubro: 'Cafetería',
    categorias: const ['Bebidas'],
    unidadesMedida: const [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
    ],
  );

  Future<void> cargarPantalla(
    WidgetTester tester, {
    required Size tamano,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProductosScreen(
          uid: 'usuario-1',
          negocioId: 'usuario-1',
          catalogoInicial: crearCatalogo(),
          productosDependencies: productosDependencies,
          catalogoDependencies: catalogoDependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('mantiene un único Scaffold y AppBar propios en la pantalla', (
    tester,
  ) async {
    await cargarPantalla(tester, tamano: const Size(1440, 900));

    expect(find.byType(ProductosScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(ProductosContent), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    tester.view.physicalSize = const Size(430, 900);
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(ProductosContent), findsOneWidget);
  });

  testWidgets('no recrea los providers al reconstruir el árbol', (
    tester,
  ) async {
    await cargarPantalla(tester, tamano: const Size(800, 900));

    verify(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).called(1);

    final ctxAntes = tester.element(find.byType(ProductosContent));
    final productosAntes = ctxAntes.read<ProductosProvider>();
    final catalogoAntes = ctxAntes.read<CatalogoNegocioProvider>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProductosScreen(
          uid: 'usuario-1',
          negocioId: 'usuario-1',
          catalogoInicial: crearCatalogo(),
          productosDependencies: productosDependencies,
          catalogoDependencies: catalogoDependencies,
        ),
      ),
    );
    await tester.pump();

    final ctxDespues = tester.element(find.byType(ProductosContent));
    expect(
      identical(ctxDespues.read<ProductosProvider>(), productosAntes),
      isTrue,
    );
    expect(
      identical(ctxDespues.read<CatalogoNegocioProvider>(), catalogoAntes),
      isTrue,
    );
  });

  testWidgets('abre el formulario de producto al tocar Agregar (móvil)', (
    tester,
  ) async {
    await cargarPantalla(tester, tamano: const Size(430, 900));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(FormularioProducto), findsOneWidget);
  });
}
