import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  group('selector de modo', () {
    testWidgets(
      'sin medidas activas muestra Por medida apagado y dice dónde activarla',
      (tester) async {
        await montar(tester, formulario());

        expect(find.text('Por presentación'), findsOneWidget);
        expect(find.text('Por medida'), findsOneWidget);
        expect(find.byKey(const Key('aviso-medida-inactiva')), findsOneWidget);

        // Tocar el segmento apagado no cambia de modo.
        await tester.tap(find.text('Por medida'));
        await tester.pumpAndSettle();
        expect(find.text('Qué mides *'), findsNothing);
      },
    );

    testWidgets('ofrece medida cuando el catálogo la tiene activa', (
      tester,
    ) async {
      await montar(tester, formulario(catalogoVenta: catalogoConMedida()));

      expect(find.text('Por presentación'), findsOneWidget);
      expect(find.text('Por medida'), findsOneWidget);
      expect(find.byKey(const Key('aviso-medida-inactiva')), findsNothing);
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
      await montar(
        tester,
        formulario(
          ventaErrorMessage: 'sin conexión',
          onReintentarVenta: () async => reintentos++,
        ),
      );

      expect(
        find.textContaining('No se pudo cargar el catálogo de venta'),
        findsOneWidget,
      );
      expect(find.textContaining('sin conexión'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
      await tester.pump();
      expect(reintentos, 1);
    });

    testWidgets('sin catálogo disponible propone reintentar', (tester) async {
      var reintentos = 0;
      await montar(
        tester,
        formulario(
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
      final provider = ProductosProviderMock();
      when(
        () => provider.crearProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);
      await montar(tester, formulario(provider: provider));

      await tester.enterText(campo('Nombre del producto *'), 'Cerveza');
      await tester.enterText(campo('Precio S/ *'), '8,50');
      await tester.enterText(campo('Stock *'), '12');

      // Presentación con varios formatos: al cambiar a Botella hay que
      // elegir uno (la sugerida, Unidad, ya estaba completa).
      await elegirEnDropdown(tester, 'Presentación *', 'Botella');
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);

      await elegirEnDropdown(tester, 'Formato *', '625 ml');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.modoVenta, ModoVenta.presentacion);
      expect(producto.presentacionId, 'botella');
      expect(producto.presentacionNombre, 'Botella');
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
      await montar(
        tester,
        formulario(producto: legacyKg(), categorias: const ['Abarrotes']),
      );

      expect(find.text('Precio S/ *'), findsOneWidget);
      expect(find.textContaining('«kg»'), findsOneWidget);
      // Sin familia elegida: los campos de medida quedan vacíos y «Por» espera
      // a que se elija qué se mide (nada se migra a la fuerza).
      expect(find.text('Elige qué mides'), findsOneWidget);
      expect(campo('Precio S/ *'), findsOneWidget);
    });

    testWidgets('editar solo el precio guarda sin elegir presentación', (
      tester,
    ) async {
      final provider = ProductosProviderMock();
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);

      await montar(
        tester,
        formulario(
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
