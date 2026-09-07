import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/presentation/providers/catalogo_negocio_provider.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/screens/productos_screen.dart';
import 'package:mobile/features/productos/presentation/widgets/producto_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _ProductosProviderMock extends Mock implements ProductosProvider {}

class _CatalogoNegocioProviderMock extends Mock
    implements CatalogoNegocioProvider {}

void main() {
  late _ProductosProviderMock productosProvider;
  late _CatalogoNegocioProviderMock catalogoProvider;

  setUp(() {
    productosProvider = _ProductosProviderMock();
    catalogoProvider = _CatalogoNegocioProviderMock();

    final producto = Producto(
      id: 'producto-1',
      negocioId: 'usuario-1',
      nombre: 'Café molido',
      precio: 18.5,
      stock: 12,
      categoria: 'Bebidas',
      unidadMedidaNombre: 'Unidad',
    );
    final catalogo = CatalogoNegocio(
      rubro: 'Cafetería',
      categorias: const ['Bebidas'],
      unidadesMedida: const [
        UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      ],
    );

    when(() => productosProvider.productosFiltrados).thenReturn([producto]);
    when(() => productosProvider.cargando).thenReturn(false);
    when(() => productosProvider.refrescando).thenReturn(false);
    when(() => productosProvider.cargandoMas).thenReturn(false);
    when(() => productosProvider.creandoProducto).thenReturn(false);
    when(() => productosProvider.editandoProducto).thenReturn(false);
    when(() => productosProvider.hayMas).thenReturn(true);
    when(() => productosProvider.errorMessage).thenReturn(null);
    when(() => productosProvider.cargarMasProductos()).thenAnswer((_) async {});
    when(
      () => productosProvider.cambiandoDisponibilidad(any()),
    ).thenReturn(false);
    when(() => catalogoProvider.catalogo).thenReturn(catalogo);
    when(() => catalogoProvider.disponible).thenReturn(true);
    when(() => catalogoProvider.errorMessage).thenReturn(null);
  });

  Future<void> cargarVista(WidgetTester tester, {required Size tamano}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductosProvider>.value(
            value: productosProvider,
          ),
          ChangeNotifierProvider<CatalogoNegocioProvider>.value(
            value: catalogoProvider,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const ContenidoProductos(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mantiene el diseño móvil sin paneles laterales', (tester) async {
    await cargarVista(tester, tamano: const Size(1099, 900));

    expect(find.byKey(const Key('fases-negocio-panel')), findsNothing);
    expect(find.byKey(const Key('ayuda-productos-panel')), findsNothing);
    expect(find.byKey(const Key('productos-grid')), findsNothing);
    expect(
      tester.widget<ProductoCard>(find.byType(ProductoCard)).esCuadricula,
      isFalse,
    );
  });

  testWidgets('muestra izquierda, catálogo y ayuda en escritorio', (
    tester,
  ) async {
    await cargarVista(tester, tamano: const Size(1100, 900));

    expect(find.byKey(const Key('fases-negocio-panel')), findsOneWidget);
    expect(find.byKey(const Key('productos-grid')), findsOneWidget);
    expect(find.byKey(const Key('ayuda-productos-panel')), findsOneWidget);
    expect(find.text('1. Rubro'), findsOneWidget);
    expect(find.text('2. Configuración del negocio'), findsOneWidget);
    expect(find.text('3. Agregado de productos'), findsOneWidget);
    expect(
      tester.widget<ProductoCard>(find.byType(ProductoCard)).esCuadricula,
      isTrue,
    );
    expect(
      (tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    expect(
      (tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      4,
    );
  });

  testWidgets('muestra Agregar producto y la paginación manual', (
    tester,
  ) async {
    await cargarVista(tester, tamano: const Size(430, 900));

    expect(find.text('Agregar producto'), findsOneWidget);
    expect(find.text('Ver más'), findsOneWidget);

    await tester.tap(find.text('Ver más'));
    verify(() => productosProvider.cargarMasProductos()).called(1);
  });
}
