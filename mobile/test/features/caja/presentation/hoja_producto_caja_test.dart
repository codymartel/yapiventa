import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/calculo_hoja_producto.dart';
import 'package:mobile/features/caja/presentation/widgets/hoja_producto_caja.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

Producto _polo() => Producto(
  id: 'polo',
  negocioId: 'n1',
  nombre: 'Polo básico',
  stock: 8,
  precioCentavos: 3500,
  tituloModelos: 'Color',
  tituloFilas: 'Talla',
  modelos: const [
    ModeloProducto(
      id: 'azul',
      nombre: 'Azul',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 3),
        FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 5),
        FilaVenta(id: 'l', etiqueta: 'L', precioCentavos: 3500, stock: 0),
      ],
    ),
    ModeloProducto(
      id: 'rojo',
      nombre: 'Rojo',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 2),
      ],
    ),
  ],
  extras: const [
    ExtraProducto(id: 'bord', nombre: 'Bordado', precioCentavos: 800),
    ExtraProducto(id: 'bolsa', nombre: 'Bolsa regalo', precioCentavos: 200),
  ],
);

/// Un plato con UN solo modelo y 3 tamaños (no hay color que elegir).
Producto _pollo() => Producto(
  id: 'pollo',
  negocioId: 'n1',
  nombre: 'Pollo a la brasa',
  esStockInfinito: true,
  precioCentavos: 1800,
  tituloFilas: 'Tamaño',
  modelos: const [
    ModeloProducto(
      id: 'pollo',
      nombre: 'Pollo',
      filas: [
        FilaVenta(id: 'c', etiqueta: 'Un cuarto', precioCentavos: 1800),
        FilaVenta(id: 'm', etiqueta: 'Medio', precioCentavos: 3400),
        FilaVenta(id: 'e', etiqueta: 'Entero', precioCentavos: 6200),
      ],
    ),
  ],
  extras: const [
    ExtraProducto(id: 'aji', nombre: 'Ají extra', precioCentavos: 100),
  ],
);

void main() {
  SeleccionProductoCaja? ultima;
  AccionHojaProducto? accionRecibida;
  AccionHojaProducto? cerrada;
  var cerrados = 0;
  String? errorDeAgregar;

  Future<void> abrir(
    WidgetTester tester,
    Producto producto, {
    double ancho = 390,
    double alto = 780,
  }) async {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  cerrada = await mostrarHojaProducto(
                    context,
                    producto: producto,
                    onConfirmar: (sel, accion) {
                      ultima = sel;
                      accionRecibida = accion;
                      return errorDeAgregar;
                    },
                  );
                  cerrados++;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    ultima = null;
    accionRecibida = null;
    cerrada = null;
    cerrados = 0;
    errorDeAgregar = null;
  });

  Finder boton(String texto) => find.ancestor(
    of: find.textContaining(texto),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  bool habilitado(WidgetTester t, String texto) =>
      t.widget<ButtonStyleButton>(boton(texto)).onPressed != null;

  group('producto que se cuenta', () {
    testWidgets('encabezado con nombre, precio y stock; cantidad 1', (
      tester,
    ) async {
      await abrir(tester, productoSimple(stock: 22, precioCentavos: 450));

      expect(find.text('Gaseosa Inca'), findsOneWidget);
      expect(find.textContaining('S/ 4,50 · hay 22'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 4,50'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
    });

    testWidgets('el stepper cambia la cantidad y el total', (tester) async {
      await abrir(tester, productoSimple(stock: 22, precioCentavos: 450));

      await tester.tap(find.byTooltip('Agregar una unidad'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 9,00'), findsOneWidget);
    });

    testWidgets('no baja de 1 y no sube de lo que hay', (tester) async {
      await abrir(tester, productoSimple(stock: 2));

      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
            .onPressed,
        isNull,
        reason: 'ya está en 1',
      );
      await tester.tap(find.byTooltip('Agregar una unidad'));
      await tester.pump();

      expect(find.text('Es todo lo que hay'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
            .onPressed,
        isNull,
      );
    });

    testWidgets('«Agregar y seguir» agrega y cierra con esa acción', (
      tester,
    ) async {
      await abrir(tester, productoSimple(stock: 22));

      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();

      expect(ultima!.cantidad, 1);
      expect(accionRecibida, AccionHojaProducto.agregarYSeguir);
      expect(cerrada, AccionHojaProducto.agregarYSeguir);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('«Agregar y cobrar» cierra con esa acción', (tester) async {
      await abrir(tester, productoSimple(stock: 22));

      await tester.tap(find.textContaining('Agregar y cobrar'));
      await tester.pumpAndSettle();

      expect(cerrada, AccionHojaProducto.agregarYCobrar);
    });

    testWidgets('«Cambiar» cierra sin agregar nada', (tester) async {
      await abrir(tester, productoSimple(stock: 22));

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(cerrada, AccionHojaProducto.cambiar);
      expect(ultima, isNull);
    });

    testWidgets(
      'si no se pudo agregar (tope de productos) lo dice y NO cierra',
      (tester) async {
        errorDeAgregar = 'Una venta admite hasta 30 productos distintos.';
        await abrir(tester, productoSimple(stock: 22));

        await tester.tap(find.text('Agregar y seguir'));
        await tester.pumpAndSettle();

        expect(find.textContaining('hasta 30 productos'), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(cerrados, 0);
      },
    );

    testWidgets('sin stock: avisa y los dos botones quedan apagados', (
      tester,
    ) async {
      await abrir(tester, productoSimple(stock: 0));

      expect(find.text('No hay stock de esto.'), findsOneWidget);
      expect(habilitado(tester, 'Agregar y cobrar'), isFalse);
      expect(habilitado(tester, 'Agregar y seguir'), isFalse);
    });

    testWidgets('un combo muestra su precio y cantidad, sin extras ni stock', (
      tester,
    ) async {
      await abrir(tester, comboGaseosaYPapas());

      expect(find.text('Combo personal'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 15,00'), findsOneWidget);
      expect(find.text('EXTRAS (OPCIONAL)'), findsNothing);
      expect(find.textContaining('hay'), findsNothing);
    });
  });

  group('por peso', () {
    testWidgets(
      'al abrir hay que elegir cuánto: botones apagados y el motivo',
      (tester) async {
        await abrir(tester, quesoPorMedida(stockBase: 3200));

        expect(find.text('¿CUÁNTO SE LLEVA?'), findsOneWidget);
        for (final c in ['1 kg', '½ kg', '¼ kg', '100 g', 'Otra cantidad']) {
          expect(find.text(c), findsOneWidget, reason: c);
        }
        expect(find.text('Elige cuánto se lleva.'), findsOneWidget);
        expect(habilitado(tester, 'Agregar y cobrar'), isFalse);
      },
    );

    testWidgets('un cuarto de kilo: S/ 6,00', (tester) async {
      await abrir(tester, quesoPorMedida(stockBase: 3200));

      await tester.tap(find.text('¼ kg'));
      await tester.pump();

      expect(find.text('Agregar y cobrar · S/ 6,00'), findsOneWidget);
      expect(find.text('¼ kg salen'), findsOneWidget);
    });

    testWidgets('«Otra cantidad»: 350 g salen S/ 8,40', (tester) async {
      await abrir(tester, quesoPorMedida(stockBase: 3200));

      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '350');
      await tester.pump();

      expect(find.text('350 g salen'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 8,40'), findsOneWidget);

      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();
      expect(ultima!.cantidad, 350);
    });

    testWidgets('las cantidades que pasan del stock quedan apagadas', (
      tester,
    ) async {
      await abrir(tester, quesoPorMedida(stockBase: 800));

      await tester.tap(find.text('1 kg'));
      await tester.pump();
      expect(find.text('Elige cuánto se lleva.'), findsOneWidget);

      await tester.tap(find.text('½ kg'));
      await tester.pump();
      expect(find.text('Agregar y cobrar · S/ 12,00'), findsOneWidget);
    });

    testWidgets('«otra cantidad» mayor que el stock no se puede agregar', (
      tester,
    ) async {
      await abrir(tester, quesoPorMedida(stockBase: 800));

      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '900');
      await tester.pump();

      expect(find.text('Pides más de lo que hay.'), findsOneWidget);
      expect(habilitado(tester, 'Agregar y cobrar'), isFalse);
    });

    testWidgets('«otra cantidad» vacía o en cero no se puede agregar', (
      tester,
    ) async {
      await abrir(tester, quesoPorMedida(stockBase: 3200));
      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(habilitado(tester, 'Agregar y cobrar'), isFalse);
    });

    testWidgets('el campo solo acepta dígitos (nada de letras ni signos)', (
      tester,
    ) async {
      await abrir(tester, quesoPorMedida(stockBase: 3200));
      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '3a5-0');
      await tester.pump();

      expect(find.text('350 g salen'), findsOneWidget);
    });
  });

  group('variables', () {
    testWidgets('color, y la talla solo aparece al elegir color', (
      tester,
    ) async {
      await abrir(tester, _polo());

      expect(find.text('COLOR'), findsOneWidget);
      expect(find.text('Azul'), findsOneWidget);
      expect(find.text('Rojo'), findsOneWidget);
      expect(find.text('TALLA'), findsNothing);
      expect(find.text('Falta elegir: color.'), findsOneWidget);
      expect(habilitado(tester, 'Agregar y cobrar'), isFalse);
    });

    testWidgets(
      'elegido el color salen las tallas con stock y la agotada apagada',
      (tester) async {
        await abrir(tester, _polo());

        await tester.tap(find.text('Azul'));
        await tester.pump();

        expect(find.text('TALLA'), findsOneWidget);
        expect(find.text('3 disp.'), findsOneWidget);
        expect(find.text('5 disp.'), findsOneWidget);
        expect(find.text('Agotado'), findsOneWidget);

        // La agotada no se puede elegir.
        await tester.tap(find.text('L'));
        await tester.pump();
        expect(habilitado(tester, 'Agregar y cobrar'), isFalse);
      },
    );

    testWidgets('elegido el color, dice que falta la talla', (tester) async {
      await abrir(tester, _polo());

      await tester.tap(find.text('Azul'));
      await tester.pump();

      expect(find.text('Falta elegir: talla.'), findsOneWidget);
    });

    testWidgets('color + talla + extra: total y resumen', (tester) async {
      await abrir(tester, _polo());

      await tester.tap(find.text('Azul'));
      await tester.pump();
      await tester.tap(find.text('M'));
      await tester.pump();
      await tester.tap(find.text('Bordado + S/ 8,00'));
      await tester.pump();

      expect(find.text('Azul · M · bordado'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 43,00'), findsOneWidget);

      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();
      expect(ultima!.modeloId, 'azul');
      expect(ultima!.filaId, 'm');
      expect(ultima!.extrasIds, {'bord'});
    });

    testWidgets('un extra se puede quitar de nuevo', (tester) async {
      await abrir(tester, _polo());
      await tester.tap(find.text('Azul'));
      await tester.pump();
      await tester.tap(find.text('M'));
      await tester.pump();

      await tester.tap(find.text('Bordado + S/ 8,00'));
      await tester.pump();
      await tester.tap(find.text('Bordado + S/ 8,00'));
      await tester.pump();

      expect(find.text('Agregar y cobrar · S/ 35,00'), findsOneWidget);
    });

    testWidgets('cambiar de color borra la talla elegida', (tester) async {
      await abrir(tester, _polo());
      await tester.tap(find.text('Azul'));
      await tester.pump();
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(habilitado(tester, 'Agregar y cobrar'), isTrue);

      await tester.tap(find.text('Rojo'));
      await tester.pump();

      // Rojo tiene una sola talla: se elige sola.
      expect(find.text('Agregar y cobrar · S/ 35,00'), findsOneWidget);
      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();
      expect(ultima!.modeloId, 'rojo');
      expect(ultima!.filaId, 's');
    });

    testWidgets('un solo modelo: no hay color que elegir, directo al tamaño', (
      tester,
    ) async {
      await abrir(tester, _pollo());

      expect(find.text('COLOR'), findsNothing);
      expect(find.text('TAMAÑO'), findsOneWidget);
      expect(find.text('Un cuarto'), findsOneWidget);
      expect(find.text('Medio'), findsOneWidget);
      expect(find.text('Entero'), findsOneWidget);
    });

    testWidgets('stock ilimitado: ninguna fila sale «Agotado» ni «0 disp.»', (
      tester,
    ) async {
      await abrir(tester, _pollo());

      expect(find.text('Agotado'), findsNothing);
      expect(find.textContaining('disp.'), findsNothing);
    });

    testWidgets('plato: Medio + ají extra = S/ 35,00', (tester) async {
      await abrir(tester, _pollo());

      await tester.tap(find.text('Medio'));
      await tester.pump();
      await tester.tap(find.text('Ají extra + S/ 1,00'));
      await tester.pump();

      expect(find.text('Agregar y cobrar · S/ 35,00'), findsOneWidget);
      expect(find.text('Medio · ají extra'), findsOneWidget);
    });
  });

  group('tamaños y accesibilidad', () {
    testWidgets('celular: hoja desde abajo', (tester) async {
      await abrir(tester, productoSimple(stock: 5));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('PC (900 px o más): diálogo', (tester) async {
      await abrir(tester, productoSimple(stock: 5), ancho: 1000, alto: 700);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('los botones miden 48 px o más y los toques 44 px o más', (
      tester,
    ) async {
      await abrir(tester, productoSimple(stock: 5));

      for (final t in ['Agregar y cobrar', 'Agregar y seguir']) {
        expect(
          tester.getSize(boton(t)).height,
          greaterThanOrEqualTo(48),
          reason: t,
        );
      }
      expect(
        tester.getSize(find.byTooltip('Agregar una unidad')).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Cambiar')).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('las opciones de color y las tallas miden 44 px o más', (
      tester,
    ) async {
      await abrir(tester, _polo());
      await tester.tap(find.text('Azul'));
      await tester.pump();

      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Azul'),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(of: find.text('M'), matching: find.byType(InkWell))
                  .first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    });
  });
}
