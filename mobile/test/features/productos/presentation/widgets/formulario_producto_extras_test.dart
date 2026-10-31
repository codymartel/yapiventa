import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  Future<void> abrirEditor(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('linea-extras')));
    await tester.tap(find.byKey(const Key('linea-extras')));
    await tester.pumpAndSettle();
  }

  /// El «Sí» del editor de extras (el formulario tiene otro «Sí»: variables).
  Future<void> tocarSiDeExtras(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('segmento-extras')),
        matching: find.text('Sí'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('línea de extras', () {
    testWidgets('aparece en «Lo cuento» y dice que es opcional', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Restaurante'));

      expect(find.byKey(const Key('linea-extras')), findsOneWidget);
      expect(find.text('opcional ›'), findsOneWidget);
    });

    testWidgets('no aparece con «Lo peso»', (tester) async {
      await montar(tester, formulario(catalogoVenta: catalogoConMedida()));

      expect(find.byKey(const Key('linea-extras')), findsOneWidget);
      await tester.tap(find.text('Lo peso'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('linea-extras')), findsNothing);
    });
  });

  group('editor de extras', () {
    testWidgets('en PC es un diálogo centrado', (tester) async {
      await montar(tester, formulario(rubro: 'Restaurante'));

      await abrirEditor(tester);

      // El formulario ya es un diálogo: con el editor hay dos.
      expect(find.byType(Dialog), findsNWidgets(2));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('segmento-extras')), findsOneWidget);
      expect(find.text('Sin extras: se vende tal cual.'), findsOneWidget);
    });

    testWidgets('en celular es una hoja que sube desde abajo', (tester) async {
      await montar(tester, formulario(rubro: 'Restaurante'));
      tester.view.physicalSize = const Size(500, 2400);
      await tester.pumpAndSettle();

      await abrirEditor(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('listo-extras')), findsOneWidget);
    });

    testWidgets('«Sí» + un extra sugerido + «Listo» actualiza la línea', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Restaurante'));
      await abrirEditor(tester);

      await tocarSiDeExtras(tester);
      await tester.tap(find.byKey(const Key('sugerido-Papas')));
      await tester.pumpAndSettle();
      expect(find.text('+ Agregar otro extra · 1 de 10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('listo-extras')));
      await tester.pumpAndSettle();

      expect(find.text('1 extra ›'), findsOneWidget);
    });

    testWidgets('«Cancelar» deja los extras como estaban al abrir', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Restaurante'));
      await abrirEditor(tester);

      await tocarSiDeExtras(tester);
      await tester.tap(find.byKey(const Key('sugerido-Papas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelar-extras')));
      await tester.pumpAndSettle();

      expect(find.text('opcional ›'), findsOneWidget);
    });

    testWidgets('un precio sin nombre avisa y bloquea el guardado', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Restaurante'));
      await abrirEditor(tester);

      await tocarSiDeExtras(tester);
      await tester.tap(find.byKey(const Key('agregar-extra')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.key as ValueKey?)?.value.toString().startsWith(
                    'extra-precio-',
                  ) ==
                  true,
        ),
        '5',
      );
      await tester.pumpAndSettle();

      expect(find.text('Falta: nombre del extra'), findsOneWidget);
    });
  });

  testWidgets('guarda el producto con sus extras en céntimos', (tester) async {
    final provider = ProductosProviderMock();
    when(
      () => provider.crearProducto(
        any(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
      ),
    ).thenAnswer((_) async => true);
    await montar(tester, formulario(provider: provider, rubro: 'Restaurante'));
    await ponerFotoDelProducto(tester);

    await tester.enterText(campo('Nombre del producto *'), 'Pollo a la brasa');
    await tester.enterText(campo('Precio S/ *'), '18');
    await tester.enterText(campo('Stock *'), '10');
    await abrirEditor(tester);
    await tocarSiDeExtras(tester);
    await tester.tap(find.byKey(const Key('sugerido-Con ají')));
    await tester.tap(find.byKey(const Key('sugerido-Papas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listo-extras')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
    await tester.pump();

    final producto = capturarProductoCreado(provider);
    expect(producto.precioCentavos, 1800);
    expect(producto.extras.map((e) => e.nombre), ['Con ají', 'Papas']);
    expect(producto.extras.map((e) => e.precioCentavos), [0, 600]);
  });
}
