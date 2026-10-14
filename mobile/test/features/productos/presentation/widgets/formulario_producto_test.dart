import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario_producto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _ProductosProviderMock extends Mock implements ProductosProvider {}

class _ProductoFake extends Fake implements Producto {}

void main() {
  setUpAll(() => registerFallbackValue(_ProductoFake()));

  OpcionPresentacion presentacion(
    String id, {
    List<FormatoPresentacion>? formatos,
    bool activa = true,
  }) {
    return OpcionPresentacion(
      id: id,
      nombre: id == 'unidad' ? 'Unidad' : 'Botella',
      formatos:
          formatos ??
          [
            FormatoPresentacion(
              valorBase: 1,
              familia: FamiliaUnidad.conteo,
              unidadVisible: RegistroUnidades.unidad,
            ),
          ],
      activa: activa,
    );
  }

  CatalogoVentaPersistido catalogoConPresentaciones() => CatalogoVentaPersistido(
    presentaciones: [
      presentacion('unidad'),
      presentacion(
        'botella',
        formatos: [
          FormatoPresentacion(
            valorBase: 625,
            familia: FamiliaUnidad.volumen,
            unidadVisible: RegistroUnidades.ml,
          ),
          FormatoPresentacion(
            valorBase: 1000,
            familia: FamiliaUnidad.volumen,
            unidadVisible: RegistroUnidades.L,
          ),
        ],
      ),
    ],
    medidas: const [],
  );

  CatalogoVentaPersistido catalogoConMedida() => CatalogoVentaPersistido(
    presentaciones: [presentacion('unidad')],
    medidas: [
      MedidaVentaPersistida(
        id: 'peso',
        nombre: 'Peso',
        familia: FamiliaUnidad.peso,
        unidadBase: RegistroUnidades.g,
        unidadVisual: RegistroUnidades.kg,
        minimoBase: 100,
        incrementoBase: 50,
        permiteCantidad: true,
        permiteMonto: false,
        activa: true,
      ),
    ],
  );

  Widget formulario({
    Producto? producto,
    CatalogoVentaPersistido? catalogoVenta,
    bool sinCatalogo = false,
    bool cargandoVenta = false,
    String? ventaErrorMessage,
    Future<void> Function()? onReintentarVenta,
    ProductosProvider? provider,
    List<String> categorias = const ['Bebidas'],
  }) {
    final contenido = Scaffold(
      body: FormularioProducto(
        producto: producto,
        categoriasDisponibles: categorias,
        catalogoVenta: sinCatalogo ? null : (catalogoVenta ?? catalogoConPresentaciones()),
        cargandoVenta: cargandoVenta,
        ventaErrorMessage: ventaErrorMessage,
        onReintentarVenta: onReintentarVenta,
        onCancelar: () {},
      ),
    );
    return MaterialApp(
      home: provider == null
          ? contenido
          : ChangeNotifierProvider<ProductosProvider>.value(
              value: provider,
              child: contenido,
            ),
    );
  }

  /// Monta el formulario con un viewport grande: el diálogo es scrollable y
  /// en 800x600 los campos quedan fuera del área visible.
  Future<void> montar(WidgetTester tester, Widget widget) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 2600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  Finder campo(String etiqueta) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
  );

  Future<void> elegirEnDropdown(
    WidgetTester tester,
    String etiqueta,
    String opcion,
  ) async {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField &&
            widget.decoration.labelText == etiqueta,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcion).last);
    await tester.pumpAndSettle();
  }

  Producto capturarProductoGuardado(_ProductosProviderMock provider) {
    return verify(
      () => provider.guardarProducto(
        captureAny(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
      ),
    ).captured.single as Producto;
  }

  Producto capturarProductoCreado(_ProductosProviderMock provider) {
    return verify(
      () => provider.crearProducto(
        captureAny(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
      ),
    ).captured.single as Producto;
  }

  group('selector de modo', () {
    testWidgets('solo ofrece los modos activos del catálogo', (tester) async {
      await montar(tester, formulario());

      expect(find.text('Por presentación'), findsOneWidget);
      expect(find.text('Por medida'), findsNothing);
    });

    testWidgets('ofrece medida cuando el catálogo la tiene activa', (
      tester,
    ) async {
      await montar(tester, formulario(catalogoVenta: catalogoConMedida()));

      expect(find.text('Por presentación'), findsOneWidget);
      expect(find.text('Por medida'), findsOneWidget);
    });
  });

  group('estados del catálogo de venta', () {
    testWidgets('mientras carga muestra el progreso', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 2600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      // El progreso es infinito: no se puede usar pumpAndSettle.
      await tester.pumpWidget(formulario(cargandoVenta: true));
      await tester.pump();

      expect(
        find.textContaining('Cargando el catálogo de venta'),
        findsOneWidget,
      );
      expect(find.text('Guardar producto'), findsOneWidget);
    });

    testWidgets('con error muestra el motivo y permite reintentar', (
      tester,
    ) async {
      var reintentos = 0;
      await montar(tester, formulario(
          ventaErrorMessage: 'sin conexión',
          onReintentarVenta: () async => reintentos++,
        ),
      );

      expect(find.textContaining('No se pudo cargar el catálogo de venta'), findsOneWidget);
      expect(find.textContaining('sin conexión'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pump();
      expect(reintentos, 1);
    });

    testWidgets('sin catálogo disponible propone reintentar', (tester) async {
      var reintentos = 0;
      await montar(tester, formulario(
          sinCatalogo: true,
          onReintentarVenta: () async => reintentos++,
        ),
      );

      expect(
        find.textContaining('Todavía no sabemos cómo se vende'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pump();
      expect(reintentos, 1);
    });
  });

  group('modo presentación', () {
    testWidgets('guarda presentación, formato y precio en céntimos', (
      tester,
    ) async {
      final provider = _ProductosProviderMock();
      when(
        () => provider.crearProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);
      await montar(tester, formulario(provider: provider));

      await tester.enterText(campo('Nombre del producto *'), 'Cerveza');
      await tester.enterText(campo('Precio por presentación S/ *'), '8,50');
      await tester.enterText(campo('Cantidad en stock *'), '12');

      // Presentación con varios formatos: hay que elegir uno.
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);

      await elegirEnDropdown(tester, 'Presentación *', 'Botella');
      await elegirEnDropdown(tester, 'Formato *', '625 ml');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.modoVenta, ModoVenta.presentacion);
      expect(producto.presentacionId, 'botella');
      expect(producto.formatoValorBase, 625);
      expect(producto.formatoFamilia, FamiliaUnidad.volumen);
      expect(producto.formatoUnidad, 'ml');
      expect(producto.precioCentavos, 850);
      expect(producto.stock, 12);
    });

    testWidgets('un solo formato se autoselecciona', (tester) async {
      await montar(tester, formulario());

      await elegirEnDropdown(tester, 'Presentación *', 'Unidad');

      expect(find.text('Formato: 1 unidad'), findsOneWidget);
    });
  });

  group('modo medida', () {
    testWidgets('convierte kg con decimales a gramos enteros', (tester) async {
      final provider = _ProductosProviderMock();
      when(
        () => provider.crearProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);
      await montar(tester, formulario(provider: provider, catalogoVenta: catalogoConMedida()));

      await tester.tap(find.text('Por medida'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nombre del producto *'), 'Arroz');
      await elegirEnDropdown(tester, 'Qué mides *', 'Peso');

      await tester.enterText(campo('Precio S/ *'), '10');
      await tester.enterText(campo('¿Desde cuánto? (en kg) *'), '1');
      await tester.enterText(campo('Cantidad en stock (en kg) *'), '1,5');
      await tester.pump();

      // El mínimo (100 g) y el incremento (50 g) NUNCA bloquean.
      final botonGuardar = find.widgetWithText(ElevatedButton, 'Guardar producto');
      await tester.tap(botonGuardar);
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.modoVenta, ModoVenta.medida);
      expect(producto.medidaFamilia, FamiliaUnidad.peso);
      expect(producto.medidaUnidad, 'kg');
      expect(producto.cantidadReferenciaBase, 1000);
      expect(producto.precioCentavos, 1000);
      expect(producto.stockBase, 1500);

      // La vista legacy que ve la web queda coherente: 1 kg, S/ 10.
      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['stock'], 1);
      expect(datos['precio'], 10.0);
      expect(datos['unidadMedidaNombre'], 'kg');
    });

    testWidgets('el stock por debajo del mínimo igual guarda', (tester) async {
      final provider = _ProductosProviderMock();
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);

      final producto = Producto(
        id: 'producto-1',
        negocioId: 'negocio-1',
        nombre: 'Arroz',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1000,
        stockBase: 1500,
      );
      await montar(tester, formulario(
          producto: producto,
          provider: provider,
          catalogoVenta: catalogoConMedida(),
        ),
      );

      // 0,05 kg = 50 g: menos del mínimo (100 g) y no alineado al
      // incremento (50 g desde 100 g). Se guarda igual.
      await tester.enterText(campo('Cantidad en stock (en kg) *'), '0,05');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final guardado = capturarProductoGuardado(provider);
      expect(guardado.stockBase, 50);
    });

    testWidgets('una cantidad que truncada da cero se rechaza con mensaje', (
      tester,
    ) async {
      final provider = _ProductosProviderMock();
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);

      final producto = Producto(
        id: 'producto-1',
        negocioId: 'negocio-1',
        nombre: 'Arroz',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1000,
        stockBase: 1500,
      );
      await montar(tester, formulario(
          producto: producto,
          provider: provider,
          catalogoVenta: catalogoConMedida(),
        ),
      );

      // 0,000 kg: el campo admite 3 decimales y truncado da 0 gramos.
      await tester.enterText(campo('Cantidad en stock (en kg) *'), '0,000');
      await tester.pump();

      expect(
        find.text('La cantidad es más pequeña que 1 g.'),
        findsOneWidget,
      );
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  group('productos legacy', () {
    Producto legacyKg() => Producto(
      id: 'producto-1',
      negocioId: 'negocio-1',
      nombre: 'Arroz',
      precio: 3.5,
      precioCentavos: 350,
      stock: 7,
      unidadMedidaNombre: 'kg',
      fraccionesSeleccionadas: const ['1/2'],
      etiquetaUnidad: 'kg',
      categoria: 'Abarrotes',
    );

    testWidgets('sugiere modo medida sin migrar los datos', (tester) async {
      await montar(tester, formulario(producto: legacyKg(), categorias: const ['Abarrotes']),
      );

      expect(find.text('Precio S/ *'), findsOneWidget);
      expect(find.textContaining('«kg»'), findsOneWidget);
      // Sin familia elegida: los campos de medida quedan vacíos.
      expect(campo('¿Desde cuánto? (en kg) *'), findsOneWidget);
    });

    testWidgets('editar solo el precio guarda sin elegir presentación', (
      tester,
    ) async {
      final provider = _ProductosProviderMock();
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);

      await montar(tester, formulario(
          producto: legacyKg(),
          provider: provider,
          categorias: const ['Abarrotes'],
        ),
      );

      await tester.enterText(campo('Precio S/ *'), '4,00');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final guardado = capturarProductoGuardado(provider);
      expect(guardado.modoVenta, ModoVenta.presentacion);
      expect(guardado.presentacionId, '');
      expect(guardado.etiquetaUnidad, 'kg');
      expect(guardado.precioCentavos, 400);

      // Lo que persiste el mapper no pierde nada de lo que lee la web.
      final datos = ProductoFirestoreMapper.paraFirestore(guardado);
      expect(datos['unidadMedidaNombre'], 'kg');
      expect(datos['precio'], 4.0);
      expect(datos['stock'], 7);
      expect(datos['fraccionesSeleccionadas'], ['1/2']);
    });
  });
}
