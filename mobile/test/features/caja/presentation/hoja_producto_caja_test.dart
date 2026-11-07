import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/presentation/widgets/mostrar_hoja_producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';
import '../helpers/banco_hoja_producto.dart';

void main() {
  final banco = BancoHoja();
  setUp(banco.reiniciar);

  group('producto que se cuenta', () {
    testWidgets('encabezado con nombre, precio y stock; cantidad 1', (
      tester,
    ) async {
      await banco.abrir(tester, productoSimple(stock: 22, precioCentavos: 450));

      expect(find.text('Gaseosa Inca'), findsOneWidget);
      expect(find.textContaining('S/ 4,50 · hay 22'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 4,50'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
    });

    testWidgets('el stepper cambia la cantidad y el total', (tester) async {
      await banco.abrir(tester, productoSimple(stock: 22, precioCentavos: 450));

      await tester.tap(find.byTooltip('Agregar una unidad'));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 9,00'), findsOneWidget);
    });

    testWidgets('no baja de 1 y no sube de lo que hay', (tester) async {
      await banco.abrir(tester, productoSimple(stock: 2));

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
      await banco.abrir(tester, productoSimple(stock: 22));

      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();

      expect(banco.ultima!.cantidad, 1);
      expect(banco.accionRecibida, AccionHojaProducto.agregarYSeguir);
      expect(banco.cerrada, AccionHojaProducto.agregarYSeguir);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('«Agregar y cobrar» cierra con esa acción', (tester) async {
      await banco.abrir(tester, productoSimple(stock: 22));

      await tester.tap(find.textContaining('Agregar y cobrar'));
      await tester.pumpAndSettle();

      expect(banco.cerrada, AccionHojaProducto.agregarYCobrar);
    });

    testWidgets('«Cambiar» cierra sin agregar nada', (tester) async {
      await banco.abrir(tester, productoSimple(stock: 22));

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(banco.cerrada, AccionHojaProducto.cambiar);
      expect(banco.ultima, isNull);
    });

    testWidgets(
      'si no se pudo agregar (tope de productos) lo dice y NO cierra',
      (tester) async {
        banco.errorDeAgregar = 'Una venta admite hasta 30 productos distintos.';
        await banco.abrir(tester, productoSimple(stock: 22));

        await tester.tap(find.text('Agregar y seguir'));
        await tester.pumpAndSettle();

        expect(find.textContaining('hasta 30 productos'), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(banco.cerrados, 0);
      },
    );

    testWidgets('sin stock: avisa y los dos botones quedan apagados', (
      tester,
    ) async {
      await banco.abrir(tester, productoSimple(stock: 0));

      expect(find.text('No hay stock de esto.'), findsOneWidget);
      expect(banco.habilitado(tester, 'Agregar y cobrar'), isFalse);
      expect(banco.habilitado(tester, 'Agregar y seguir'), isFalse);
    });

    testWidgets('un combo muestra su precio y cantidad, sin extras ni stock', (
      tester,
    ) async {
      await banco.abrir(tester, comboGaseosaYPapas());

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
        await banco.abrir(tester, quesoPorMedida(stockBase: 3200));

        expect(find.text('¿CUÁNTO SE LLEVA?'), findsOneWidget);
        for (final c in ['1 kg', '½ kg', '¼ kg', '100 g', 'Otra cantidad']) {
          expect(find.text(c), findsOneWidget, reason: c);
        }
        expect(find.text('Elige cuánto se lleva.'), findsOneWidget);
        expect(banco.habilitado(tester, 'Agregar y cobrar'), isFalse);
      },
    );

    testWidgets('un cuarto de kilo: S/ 6,00', (tester) async {
      await banco.abrir(tester, quesoPorMedida(stockBase: 3200));

      await tester.tap(find.text('¼ kg'));
      await tester.pump();

      expect(find.text('Agregar y cobrar · S/ 6,00'), findsOneWidget);
      expect(find.text('¼ kg salen'), findsOneWidget);
    });

    testWidgets('«Otra cantidad»: 350 g salen S/ 8,40', (tester) async {
      await banco.abrir(tester, quesoPorMedida(stockBase: 3200));

      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '350');
      await tester.pump();

      expect(find.text('350 g salen'), findsOneWidget);
      expect(find.text('Agregar y cobrar · S/ 8,40'), findsOneWidget);

      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();
      expect(banco.ultima!.cantidad, 350);
    });

    testWidgets('las cantidades que pasan del stock quedan apagadas', (
      tester,
    ) async {
      await banco.abrir(tester, quesoPorMedida(stockBase: 800));

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
      await banco.abrir(tester, quesoPorMedida(stockBase: 800));

      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '900');
      await tester.pump();

      expect(find.text('Pides más de lo que hay.'), findsOneWidget);
      expect(banco.habilitado(tester, 'Agregar y cobrar'), isFalse);
    });

    testWidgets('«otra cantidad» vacía o en cero no se puede agregar', (
      tester,
    ) async {
      await banco.abrir(tester, quesoPorMedida(stockBase: 3200));
      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(banco.habilitado(tester, 'Agregar y cobrar'), isFalse);
    });

    testWidgets('el campo solo acepta dígitos (nada de letras ni signos)', (
      tester,
    ) async {
      await banco.abrir(tester, quesoPorMedida(stockBase: 3200));
      await tester.tap(find.text('Otra cantidad'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '3a5-0');
      await tester.pump();

      expect(find.text('350 g salen'), findsOneWidget);
    });
  });
}
