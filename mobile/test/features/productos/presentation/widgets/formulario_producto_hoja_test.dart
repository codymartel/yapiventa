import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  Future<void> montarEnHoja(WidgetTester tester, Widget widget) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('la hoja no es un AlertDialog y muestra el título', (
    tester,
  ) async {
    await montarEnHoja(tester, formulario(enHoja: true));

    expect(find.byKey(const Key('formulario-en-hoja')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Agregar producto'), findsOneWidget);
  });

  testWidgets('los botones y el aviso «Falta» quedan fijos al pie', (
    tester,
  ) async {
    await montarEnHoja(tester, formulario(enHoja: true));

    expect(find.text('Falta: foto del producto'), findsOneWidget);
    expect(find.byKey(const Key('cancelar-formulario')), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Guardar producto'),
    );
    expect(boton.onPressed, isNull);
    // Los botones están abajo de la pantalla, no al final del formulario.
    final y = tester.getTopLeft(find.text('Guardar producto')).dy;
    expect(y, greaterThan(900 * 0.8));
  });

  testWidgets('«Cancelar» cierra la hoja', (tester) async {
    var cerrada = 0;
    await montarEnHoja(
      tester,
      formulario(enHoja: true, onCancelar: () => cerrada++),
    );

    await tester.tap(find.byKey(const Key('cancelar-formulario')));
    await tester.pump();

    expect(cerrada, 1);
  });

  testWidgets('se puede llenar y guardar igual que en el diálogo', (
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
    await montarEnHoja(tester, formulario(enHoja: true, provider: provider));

    await tester.enterText(campo('Nombre del producto *'), 'Cerveza');
    await tester.enterText(campo('Precio S/ *'), '8');
    await tester.enterText(campo('Stock *'), '12');
    await ponerFotoDelProducto(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
    await tester.pump();

    final producto = capturarProductoCreado(provider);
    expect(producto.nombre, 'Cerveza');
    expect(producto.precioCentavos, 800);
    expect(producto.stock, 12);
  });
}
