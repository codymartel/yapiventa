import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';
import '../helpers/banco_hoja_producto.dart';

void main() {
  final banco = BancoHoja();
  setUp(banco.reiniciar);

  group('variables', () {
    testWidgets('color, y la talla solo aparece al elegir color', (
      tester,
    ) async {
      await banco.abrir(tester, poloDePrueba());

      expect(find.text('COLOR'), findsOneWidget);
      expect(find.text('Azul'), findsOneWidget);
      expect(find.text('Rojo'), findsOneWidget);
      expect(find.text('TALLA'), findsNothing);
      expect(find.text('Falta elegir: color.'), findsOneWidget);
      expect(banco.habilitado(tester, 'Agregar y cobrar'), isFalse);
    });

    testWidgets(
      'elegido el color salen las tallas con stock y la agotada apagada',
      (tester) async {
        await banco.abrir(tester, poloDePrueba());

        await tester.tap(find.text('Azul'));
        await tester.pump();

        expect(find.text('TALLA'), findsOneWidget);
        expect(find.text('3 disp.'), findsOneWidget);
        expect(find.text('5 disp.'), findsOneWidget);
        expect(find.text('Agotado'), findsOneWidget);

        // La agotada no se puede elegir.
        await tester.tap(find.text('L'));
        await tester.pump();
        expect(banco.habilitado(tester, 'Agregar y cobrar'), isFalse);
      },
    );

    testWidgets('elegido el color, dice que falta la talla', (tester) async {
      await banco.abrir(tester, poloDePrueba());

      await tester.tap(find.text('Azul'));
      await tester.pump();

      expect(find.text('Falta elegir: talla.'), findsOneWidget);
    });

    testWidgets('color + talla + extra: total y resumen', (tester) async {
      await banco.abrir(tester, poloDePrueba());

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
      expect(banco.ultima!.modeloId, 'azul');
      expect(banco.ultima!.filaId, 'm');
      expect(banco.ultima!.extrasIds, {'bord'});
    });

    testWidgets('un extra se puede quitar de nuevo', (tester) async {
      await banco.abrir(tester, poloDePrueba());
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
      await banco.abrir(tester, poloDePrueba());
      await tester.tap(find.text('Azul'));
      await tester.pump();
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(banco.habilitado(tester, 'Agregar y cobrar'), isTrue);

      await tester.tap(find.text('Rojo'));
      await tester.pump();

      // Rojo tiene una sola talla: se elige sola.
      expect(find.text('Agregar y cobrar · S/ 35,00'), findsOneWidget);
      await tester.tap(find.text('Agregar y seguir'));
      await tester.pumpAndSettle();
      expect(banco.ultima!.modeloId, 'rojo');
      expect(banco.ultima!.filaId, 's');
    });

    testWidgets('un solo modelo: no hay color que elegir, directo al tamaño', (
      tester,
    ) async {
      await banco.abrir(tester, polloDePrueba());

      expect(find.text('COLOR'), findsNothing);
      expect(find.text('TAMAÑO'), findsOneWidget);
      expect(find.text('Un cuarto'), findsOneWidget);
      expect(find.text('Medio'), findsOneWidget);
      expect(find.text('Entero'), findsOneWidget);
    });

    testWidgets('stock ilimitado: ninguna fila sale «Agotado» ni «0 disp.»', (
      tester,
    ) async {
      await banco.abrir(tester, polloDePrueba());

      expect(find.text('Agotado'), findsNothing);
      expect(find.textContaining('disp.'), findsNothing);
    });

    testWidgets('plato: Medio + ají extra = S/ 35,00', (tester) async {
      await banco.abrir(tester, polloDePrueba());

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
      await banco.abrir(tester, productoSimple(stock: 5));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('PC (1 100 px o más): diálogo', (tester) async {
      await banco.abrir(
        tester,
        productoSimple(stock: 5),
        ancho: 1100,
        alto: 700,
      );

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('los botones miden 48 px o más y los toques 44 px o más', (
      tester,
    ) async {
      await banco.abrir(tester, productoSimple(stock: 5));

      for (final t in ['Agregar y cobrar', 'Agregar y seguir']) {
        expect(
          tester.getSize(banco.boton(t)).height,
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
      await banco.abrir(tester, poloDePrueba());
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
