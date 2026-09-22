import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/presentation/providers/catalogo_negocio_provider.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/widgets/producto_card.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_content.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _ProductosProviderMock extends Mock implements ProductosProvider {}

class _CatalogoNegocioProviderMock extends Mock
    implements CatalogoNegocioProvider {}

void main() {
  late _ProductosProviderMock productosProvider;
  late _CatalogoNegocioProviderMock catalogoProvider;
  late Producto producto;

  setUp(() {
    productosProvider = _ProductosProviderMock();
    catalogoProvider = _CatalogoNegocioProviderMock();

    producto = Producto(
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
    when(() => productosProvider.totalProductos).thenReturn(1);
    when(() => productosProvider.cargando).thenReturn(false);
    when(() => productosProvider.refrescando).thenReturn(false);
    when(() => productosProvider.cargandoMas).thenReturn(false);
    when(() => productosProvider.creandoProducto).thenReturn(false);
    when(() => productosProvider.editandoProducto).thenReturn(false);
    when(() => productosProvider.hayMas).thenReturn(true);
    when(() => productosProvider.errorMessage).thenReturn(null);
    when(() => productosProvider.cargarMasProductos()).thenAnswer((_) async {});
    when(() => catalogoProvider.reintentar()).thenAnswer((_) async {});
    when(
      () => productosProvider.cambiandoDisponibilidad(any()),
    ).thenReturn(false);
    when(() => catalogoProvider.catalogo).thenReturn(catalogo);
    when(() => catalogoProvider.disponible).thenReturn(true);
    when(() => catalogoProvider.errorMessage).thenReturn(null);
  });

  Future<void> cargarVista(
    WidgetTester tester, {
    required Size tamano,
    double escalaTexto = 1.0,
    VoidCallback? onAgregar,
    ValueChanged<Producto>? onEditar,
    ValueChanged<String>? onEliminar,
    VoidCallback? onElegirPlantilla,
  }) async {
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Scaffold(
            body: ProductosContent(
              onAgregar: onAgregar,
              onEditar: onEditar,
              onEliminar: onEliminar,
              onElegirPlantilla: onElegirPlantilla,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no crea Scaffold, AppBar ni SafeArea dentro del contenido', (
    tester,
  ) async {
    await cargarVista(tester, tamano: const Size(1440, 900));

    expect(find.byType(ProductosContent), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ProductosContent),
        matching: find.byType(Scaffold),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ProductosContent),
        matching: find.byType(AppBar),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ProductosContent),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

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
    expect(find.byKey(const Key('productos-page-scroll')), findsOneWidget);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(
      tester.widget<GridView>(find.byKey(const Key('productos-grid'))).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(find.text('1. Rubro'), findsOneWidget);
    expect(find.text('2. Configuración del negocio'), findsOneWidget);
    expect(find.text('3. Agregado de productos'), findsOneWidget);
    expect(
      tester.widget<ProductoCard>(find.byType(ProductoCard)).esCuadricula,
      isTrue,
    );
    expect(
      (tester
                  .widget<GridView>(find.byKey(const Key('productos-grid')))
                  .gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    expect(
      (tester
                  .widget<GridView>(find.byKey(const Key('productos-grid')))
                  .gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );

    tester.view.physicalSize = const Size(1600, 900);
    await tester.pump();
    expect(
      (tester
                  .widget<GridView>(find.byKey(const Key('productos-grid')))
                  .gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      4,
    );
  });

  testWidgets('mantiene la paginación manual en móvil', (tester) async {
    await cargarVista(tester, tamano: const Size(430, 900));

    expect(find.text('Ver más'), findsOneWidget);

    await tester.tap(find.text('Ver más'));
    verify(() => productosProvider.cargarMasProductos()).called(1);
  });

  testWidgets('muestra el estado de carga con un indicador', (tester) async {
    when(() => productosProvider.cargando).thenReturn(true);
    when(() => productosProvider.productosFiltrados).thenReturn(<Producto>[]);
    when(() => productosProvider.hayMas).thenReturn(false);

    await cargarVista(tester, tamano: const Size(430, 900));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Todavía no tienes productos.'), findsNothing);
  });

  testWidgets('muestra el estado vacío sin productos', (tester) async {
    when(() => productosProvider.cargando).thenReturn(false);
    when(() => productosProvider.productosFiltrados).thenReturn(<Producto>[]);
    when(() => productosProvider.hayMas).thenReturn(false);
    when(() => productosProvider.totalProductos).thenReturn(0);

    await cargarVista(tester, tamano: const Size(430, 900));

    expect(find.text('Todavía no tienes productos.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('muestra el error de productos y lo puede cerrar', (
    tester,
  ) async {
    when(() => productosProvider.errorMessage).thenReturn('Error al cargar');

    await cargarVista(tester, tamano: const Size(430, 900));

    expect(find.text('Error al cargar'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar mensaje'));
    verify(() => productosProvider.limpiarError()).called(1);
  });

  testWidgets('muestra el error del catálogo y permite reintentar', (
    tester,
  ) async {
    when(
      () => catalogoProvider.errorMessage,
    ).thenReturn('No se pudo cargar el catálogo del negocio: boom');

    await cargarVista(tester, tamano: const Size(430, 900));

    expect(
      find.textContaining('No se pudo cargar el catálogo del negocio'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Reintentar carga del catálogo'));
    verify(() => catalogoProvider.reintentar()).called(1);
  });

  testWidgets('despacha las acciones mediante callbacks', (tester) async {
    var agregarLlamado = false;
    Producto? editado;
    String? eliminadoId;
    var elegirPlantillaLlamado = false;

    await cargarVista(
      tester,
      tamano: const Size(1440, 900),
      onAgregar: () => agregarLlamado = true,
      onEditar: (producto) => editado = producto,
      onEliminar: (productoId) => eliminadoId = productoId,
      onElegirPlantilla: () => elegirPlantillaLlamado = true,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Agregar producto'));
    expect(agregarLlamado, isTrue);

    await tester.tap(find.byTooltip('Editar producto'));
    expect(editado?.id, producto.id);

    await tester.tap(find.byTooltip('Eliminar producto'));
    expect(eliminadoId, producto.id);

    await tester.tap(find.text('Siguiente paso: elegir plantilla'));
    expect(elegirPlantillaLlamado, isTrue);
  });

  group('sin desbordamiento por ancho y escala de texto', () {
    const tamanos = <double>[360, 500, 768, 1050, 1440];
    const escalas = <double>[1.0, 1.3];

    for (final tamano in tamanos) {
      for (final escala in escalas) {
        testWidgets('a ${tamano.toStringAsFixed(0)}px con texto $escala', (
          tester,
        ) async {
          await cargarVista(
            tester,
            tamano: Size(tamano, 900),
            escalaTexto: escala,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
