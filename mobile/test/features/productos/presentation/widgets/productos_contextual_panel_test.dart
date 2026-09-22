import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_contextual_panel.dart';

void main() {
  Future<void> cargarPanel(
    WidgetTester tester, {
    required Size tamano,
    double escalaTexto = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: const SizedBox(
              width: double.infinity,
              child: ProductosContextualPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('muestra el contenido informativo de ayuda', (tester) async {
    await cargarPanel(tester, tamano: const Size(1050, 900));

    expect(find.byKey(const Key('productos-contextual-panel')), findsOneWidget);
    expect(find.text('¿Cómo funciona?'), findsOneWidget);
    expect(find.text('Agregar producto'), findsOneWidget);
    expect(
      find.text('Crea un producto con imagen, precio y stock.'),
      findsOneWidget,
    );
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Modifica sus datos.'), findsOneWidget);
    expect(find.text('Disponibilidad'), findsOneWidget);
    expect(find.text('Activa o desactiva su publicación.'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.text('Quita el producto del catálogo.'), findsOneWidget);
  });

  group('sin desbordamiento por ancho y escala de texto', () {
    const tamanos = <double>[360, 500, 768, 1050, 1440];
    const escalas = <double>[1.0, 1.3, 2.0];

    for (final tamano in tamanos) {
      for (final escala in escalas) {
        testWidgets('a ${tamano.toStringAsFixed(0)}px con texto $escala', (
          tester,
        ) async {
          await cargarPanel(
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
