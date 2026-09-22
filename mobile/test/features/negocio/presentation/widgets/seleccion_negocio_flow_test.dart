import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_negocio_screen.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_negocio_flow.dart';

void main() {
  Future<void> seleccionar(WidgetTester tester, String rubro) async {
    await tester.pump();
    await tester.tap(find.byKey(Key('rubro-card-$rubro')));
    await tester.pump();
  }

  Future<void> confirmar(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('confirmar-rubro')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmar-rubro')));
  }

  testWidgets(
    'SeleccionNegocioScreen conserva un solo Scaffold y monta el flujo',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SeleccionNegocioScreen(
            onTipoSeleccionado: (_) async => true,
            onVolverDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
      expect(find.byKey(const Key('seleccion-negocio-scroll')), findsOneWidget);
    },
  );

  testWidgets('el coordinador se monta sin Scaffold propio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionNegocioFlow(
            onTipoSeleccionado: (_) async => true,
            onCompletado: () {},
            onVolver: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsNothing);
    expect(find.byKey(const Key('seleccion-negocio-scroll')), findsOneWidget);
    expect(find.text('Confirmar rubro'), findsOneWidget);
  });

  testWidgets('guardar correctamente ejecuta onCompletado', (tester) async {
    final obtenidos = <String>[];
    var completados = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionNegocioFlow(
            onTipoSeleccionado: (rubro) async {
              obtenidos.add(rubro);
              return true;
            },
            onCompletado: () => completados++,
            onVolver: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await seleccionar(tester, 'Bodega');
    await confirmar(tester);
    await tester.pumpAndSettle();

    expect(obtenidos, ['Bodega']);
    expect(completados, 1);
  });

  testWidgets('volver ejecuta onVolver', (tester) async {
    var vueltas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionNegocioFlow(
            onTipoSeleccionado: (_) async => true,
            onCompletado: () {},
            onVolver: () => vueltas++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver al dashboard'));

    expect(vueltas, 1);
  });

  testWidgets('un error mantiene al usuario en Rubro y no completa', (
    tester,
  ) async {
    var completados = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionNegocioFlow(
            onTipoSeleccionado: (_) async => false,
            onCompletado: () => completados++,
            onVolver: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await seleccionar(tester, 'Bodega');
    await confirmar(tester);
    await tester.pumpAndSettle();

    expect(completados, 0);
    expect(
      find.text('No se pudo guardar el rubro. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('seleccion-negocio-scroll')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('confirmar-rubro')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('una excepción también mantiene al usuario en Rubro', (
    tester,
  ) async {
    var completados = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionNegocioFlow(
            onTipoSeleccionado: (_) async => throw StateError('sin red'),
            onCompletado: () => completados++,
            onVolver: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await seleccionar(tester, 'Bodega');
    await confirmar(tester);
    await tester.pumpAndSettle();

    expect(completados, 0);
    expect(
      find.text('No se pudo guardar el rubro. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byType(Scaffold), findsNothing);
  });
}
