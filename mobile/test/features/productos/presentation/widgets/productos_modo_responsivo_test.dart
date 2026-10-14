import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/catalogo_negocio_dependencies.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/productos/application/use_cases/cambiar_disponibilidad_producto.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/eliminar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/obtener_pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_flow.dart';
import 'package:mobile/features/productos/productos_dependencies.dart';
import 'package:mocktail/mocktail.dart';

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
    final cambiarDisponibilidad = _CambiarDisponibilidadMock();
    final eliminarProducto = _EliminarProductoMock();

    when(
      () => obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).thenAnswer(
      (_) async => PaginaProductos(
        productos: [
          Producto(
            id: 'producto-1',
            negocioId: 'usuario-1',
            nombre: 'Café molido',
            precio: 18.5,
            stock: 12,
            categoria: 'Bebidas',
            unidadMedidaNombre: 'Unidad',
          ),
        ],
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
      () => catalogoDependencies.obtenerCatalogoVenta,
    ).thenReturn(null);
  });

  CatalogoNegocio crearCatalogo() => CatalogoNegocio(
    rubro: 'Cafetería',
    categorias: const ['Bebidas'],
    unidadesMedida: const [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
    ],
  );

  Future<void> montar(
    WidgetTester tester, {
    required Size viewport,
    double? anchoColumna,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Widget flujo = ProductosFlow(
      uid: 'usuario-1',
      negocioId: 'usuario-1',
      catalogoInicial: crearCatalogo(),
      productosDependencies: productosDependencies,
      catalogoDependencies: catalogoDependencies,
    );
    if (anchoColumna != null) {
      flujo = Center(
        child: SizedBox(width: anchoColumna, height: 800, child: flujo),
      );
    }
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: flujo),
    );
    await tester.pumpAndSettle();
  }

  /// Encabezado (FilledButton) + FAB = exactamente un botón de agregar.
  int contarAgregar(WidgetTester tester) {
    final encabezado = find.widgetWithText(
      FilledButton,
      'Agregar producto',
    );
    final fabs = find.byType(FloatingActionButton);
    return encabezado.evaluate().length + fabs.evaluate().length;
  }

  testWidgets(
    'columna de 1000px con ventana 1920x1080: exactamente un agregar',
    (tester) async {
      await montar(
        tester,
        viewport: const Size(1920, 1080),
        anchoColumna: 1000,
      );

      expect(contarAgregar(tester), 1);
    },
  );

  testWidgets('viewport 1366x768: exactamente un agregar', (tester) async {
    await montar(tester, viewport: const Size(1366, 768));

    expect(contarAgregar(tester), 1);
  });

  testWidgets('viewport 1536x864: exactamente un agregar', (tester) async {
    await montar(tester, viewport: const Size(1536, 864));

    expect(contarAgregar(tester), 1);
  });
}
