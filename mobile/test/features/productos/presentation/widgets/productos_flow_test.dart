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
import 'package:mobile/features/productos/presentation/widgets/formulario_producto.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_content.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_flow.dart';
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

class _Cursor implements CursorProductos {}

void main() {
  late _ProductosDependenciesMock productosDependencies;
  late _CatalogoNegocioDependenciesMock catalogoDependencies;
  late _ObtenerCatalogoNegocioMock obtenerCatalogo;
  late _ObtenerPaginaProductosMock obtenerPagina;
  late _CambiarDisponibilidadMock cambiarDisponibilidad;
  late _EliminarProductoMock eliminarProducto;

  setUp(() {
    productosDependencies = _ProductosDependenciesMock();
    catalogoDependencies = _CatalogoNegocioDependenciesMock();
    obtenerCatalogo = _ObtenerCatalogoNegocioMock();
    obtenerPagina = _ObtenerPaginaProductosMock();
    cambiarDisponibilidad = _CambiarDisponibilidadMock();
    eliminarProducto = _EliminarProductoMock();

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
        hayMas: false,
      ),
    );
    when(() => obtenerCatalogo(any())).thenAnswer(
      (_) async => CatalogoNegocio(
        rubro: 'Cafetería',
        categorias: const ['Bebidas'],
        unidadesMedida: const [
          UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
        ],
      ),
    );

    when(
      () => productosDependencies.obtenerPaginaProductos,
    ).thenReturn(obtenerPagina);
    when(
      () => productosDependencies.cambiarDisponibilidadProducto,
    ).thenReturn(cambiarDisponibilidad);
    when(
      () => productosDependencies.crearProducto,
    ).thenReturn(_CrearProductoMock());
    when(
      () => productosDependencies.editarProducto,
    ).thenReturn(_EditarProductoMock());
    when(
      () => productosDependencies.eliminarProducto,
    ).thenReturn(eliminarProducto);
    when(
      () => catalogoDependencies.obtenerCatalogoNegocio,
    ).thenReturn(obtenerCatalogo);
    when(
      () => cambiarDisponibilidad(
        negocioId: any(named: 'negocioId'),
        productoId: any(named: 'productoId'),
        disponible: any(named: 'disponible'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => eliminarProducto(
        negocioId: any(named: 'negocioId'),
        productoId: any(named: 'productoId'),
      ),
    ).thenAnswer((_) async {});
  });

  CatalogoNegocio crearCatalogo() => CatalogoNegocio(
    rubro: 'Cafetería',
    categorias: const ['Bebidas'],
    unidadesMedida: const [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
    ],
  );

  Future<void> cargarFlujo(
    WidgetTester tester, {
    required Size tamano,
    VoidCallback? onVolver,
    ValueChanged<String>? onElegirPlantilla,
    VoidCallback? onProgressChanged,
    bool conNegocio = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProductosFlow(
          uid: 'usuario-1',
          negocioId: conNegocio ? 'usuario-1' : null,
          catalogoInicial: crearCatalogo(),
          onVolver: onVolver,
          onElegirPlantilla: onElegirPlantilla,
          onProgressChanged: onProgressChanged,
          productosDependencies: productosDependencies,
          catalogoDependencies: catalogoDependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('no crea Scaffold, AppBar ni SafeArea dentro del flujo', (
    tester,
  ) async {
    await cargarFlujo(tester, tamano: const Size(1440, 900));

    expect(find.byType(ProductosFlow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ProductosFlow),
        matching: find.byType(Scaffold),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ProductosFlow),
        matching: find.byType(AppBar),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ProductosFlow),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('crea los providers una sola vez y los libera al desmontar', (
    tester,
  ) async {
    await cargarFlujo(tester, tamano: const Size(800, 900));

    final ctxAntes = tester.element(find.byType(ProductosContent));
    final productosAntes = ctxAntes.read<ProductosProvider>();
    final catalogoAntes = ctxAntes.read<CatalogoNegocioProvider>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProductosFlow(
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('carga los productos una sola vez al montar', (tester) async {
    await cargarFlujo(tester, tamano: const Size(430, 900));

    verify(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).called(1);
  });

  testWidgets('abre el formulario de producto al tocar Agregar (móvil)', (
    tester,
  ) async {
    await cargarFlujo(tester, tamano: const Size(430, 900));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(FormularioProducto), findsOneWidget);
  });

  testWidgets('propaga el rubro al elegir plantilla', (tester) async {
    final rubros = <String>[];
    await cargarFlujo(
      tester,
      tamano: const Size(430, 900),
      onElegirPlantilla: rubros.add,
    );

    await tester.tap(find.text('Siguiente paso: elegir plantilla'));
    await tester.pump();

    expect(rubros, ['Cafetería']);
  });

  testWidgets('editar abre el formulario con el producto', (tester) async {
    await cargarFlujo(tester, tamano: const Size(430, 900));

    await tester.tap(find.byTooltip('Editar producto'));
    await tester.pump();

    expect(find.byType(FormularioProducto), findsOneWidget);
  });

  testWidgets('eliminar confirma y notifica el progreso', (tester) async {
    var progreso = 0;
    await cargarFlujo(
      tester,
      tamano: const Size(430, 900),
      onProgressChanged: () => progreso++,
    );

    await tester.tap(find.byTooltip('Eliminar producto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    verify(
      () => eliminarProducto(negocioId: 'usuario-1', productoId: 'producto-1'),
    ).called(1);
    expect(progreso, 1);
    expect(find.text('Café molido'), findsNothing);
  });

  testWidgets('cambiar disponibilidad llega al caso de uso', (tester) async {
    await cargarFlujo(tester, tamano: const Size(430, 900));

    await tester.tap(find.byTooltip('Marcar como no disponible'));
    await tester.pump();

    verify(
      () => cambiarDisponibilidad(
        negocioId: 'usuario-1',
        productoId: 'producto-1',
        disponible: false,
      ),
    ).called(1);
  });

  testWidgets('mantiene filtros y paginación al reconstruir', (tester) async {
    when(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).thenAnswer((invocacion) async {
      final despuesDe =
          invocacion.namedArguments[Symbol('despuesDe')] as CursorProductos?;
      if (despuesDe == null) {
        return PaginaProductos(
          productos: [
            Producto(
              id: 'producto-1',
              negocioId: 'usuario-1',
              nombre: 'Café',
              precio: 10,
              stock: 5,
              categoria: 'Bebidas',
              unidadMedidaNombre: 'Unidad',
            ),
          ],
          ultimoCursor: _Cursor(),
          hayMas: true,
        );
      }
      return PaginaProductos(
        productos: [
          Producto(
            id: 'producto-2',
            negocioId: 'usuario-1',
            nombre: 'Té',
            precio: 8,
            stock: 3,
            categoria: 'Bebidas',
            unidadMedidaNombre: 'Unidad',
          ),
        ],
        ultimoCursor: null,
        hayMas: false,
      );
    });

    await cargarFlujo(tester, tamano: const Size(430, 900));
    final provider = tester
        .element(find.byType(ProductosContent))
        .read<ProductosProvider>();
    provider.actualizarBusqueda('café');
    provider.actualizarFiltroDisponibilidad(
      FiltroDisponibilidadProducto.disponible,
    );
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProductosFlow(
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

    final providerDespues = tester
        .element(find.byType(ProductosContent))
        .read<ProductosProvider>();
    expect(identical(providerDespues, provider), isTrue);
    expect(providerDespues.busqueda, 'café');
    expect(
      providerDespues.filtroDisponibilidad,
      FiltroDisponibilidadProducto.disponible,
    );

    await tester.tap(find.text('Ver más'));
    await tester.pump();
    await tester.pump();

    verify(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).called(2);
    expect(providerDespues.totalProductos, 2);
    expect(find.text('Té'), findsNothing);
    expect(providerDespues.busqueda, 'café');
    expect(
      providerDespues.filtroDisponibilidad,
      FiltroDisponibilidadProducto.disponible,
    );
  });

  testWidgets('sin negocio no crea el provider de productos', (tester) async {
    await cargarFlujo(tester, tamano: const Size(430, 900), conNegocio: false);

    expect(find.text('Inicia sesion para ver tus productos.'), findsOneWidget);
    verifyNever(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    );
  });
}
