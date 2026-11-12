import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/planes/presentation/screens/planes_screen.dart';

void main() {
  Future<void> mostrar(WidgetTester tester, Size tamano, {double letra = 1}) {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: tamano,
            textScaler: TextScaler.linear(letra),
          ),
          child: const Scaffold(body: PlanesScreen()),
        ),
      ),
    );
  }

  testWidgets('avisa que habrá planes sin prometer nada', (tester) async {
    await mostrar(tester, const Size(360, 800));

    expect(find.text('Pronto tendremos planes'), findsOneWidget);
    expect(
      find.text('Mientras tanto, disfruta del acceso a todo nuestro catálogo.'),
      findsOneWidget,
    );
    for (final prohibido in ['próximamente', 'S/', 'precio', 'traerán']) {
      expect(find.textContaining(prohibido), findsNothing, reason: prohibido);
    }
  });

  testWidgets('cuenta lo que ya se puede usar hoy', (tester) async {
    await mostrar(tester, const Size(1280, 900));

    for (final (_, titulo, _) in PlanesScreen.loQueTienesHoy) {
      expect(find.text(titulo), findsOneWidget, reason: titulo);
    }
  });

  testWidgets('con letra grande en un celular chico no se desborda', (
    tester,
  ) async {
    await mostrar(tester, const Size(320, 568), letra: 1.6);
    await tester.scrollUntilVisible(
      find.text('El tamaño de la letra de la app.'),
      200,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Configuración'), findsOneWidget);
  });
}
