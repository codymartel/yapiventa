import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_negocio_screen.dart';

void main() {
  Future<void> mostrarPantalla(
    WidgetTester tester, {
    String rubroInicial = '',
    required Future<bool> Function(String rubro) guardar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('abrir-rubro'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (rutaContext) => SeleccionNegocioScreen(
                        rubroInicial: rubroInicial,
                        onTipoSeleccionado: guardar,
                        onVolverDashboard: () =>
                            Navigator.of(rutaContext).pop(),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir Rubro'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('abrir-rubro')));
    await tester.pumpAndSettle();
  }

  Future<void> seleccionar(WidgetTester tester, String rubro) async {
    await tester.ensureVisible(find.byKey(Key('rubro-card-$rubro')));
    await tester.pump();
    await tester.tap(find.byKey(Key('rubro-card-$rubro')));
    await tester.pump();
  }

  Future<void> mostrarConfirmacion(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dos clics guardan una vez y el resultado false reactiva la interfaz',
    (tester) async {
      final semantica = tester.ensureSemantics();
      final respuesta = Completer<bool>();
      var guardados = 0;
      await mostrarPantalla(
        tester,
        guardar: (_) {
          guardados++;
          return respuesta.future;
        },
      );
      await seleccionar(tester, 'Bodega');
      await mostrarConfirmacion(tester);

      final confirmar = find.byKey(const Key('confirmar-rubro'));
      await tester.tap(confirmar);
      await tester.tap(confirmar);
      await tester.pump();

      expect(guardados, 1);
      expect(tester.widget<ElevatedButton>(confirmar).onPressed, isNull);
      expect(find.text('Guardando...'), findsOneWidget);

      await seleccionar(tester, 'Restaurante');
      expect(
        tester
            .getSemantics(find.byKey(const Key('rubro-card-Bodega')))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('rubro-card-Restaurante')))
            .flagsCollection
            .isSelected,
        ui.Tristate.isFalse,
      );

      respuesta.complete(false);
      await tester.pumpAndSettle();
      await mostrarConfirmacion(tester);

      expect(tester.widget<ElevatedButton>(confirmar).onPressed, isNotNull);
      expect(
        find.text('No se pudo guardar el rubro. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('rubro-card-Bodega')))
            .flagsCollection
            .isEnabled,
        ui.Tristate.isTrue,
      );
      semantica.dispose();
    },
  );

  testWidgets('una excepción reactiva tarjetas y botón y muestra error', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await mostrarPantalla(
      tester,
      guardar: (_) async => throw StateError('sin conexión'),
    );
    await seleccionar(tester, 'Bodega');
    await mostrarConfirmacion(tester);

    await tester.tap(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();
    await mostrarConfirmacion(tester);

    expect(
      find.text('No se pudo guardar el rubro. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('confirmar-rubro')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('rubro-card-Bodega')))
          .flagsCollection
          .isEnabled,
      ui.Tristate.isTrue,
    );
    semantica.dispose();
  });

  testWidgets('bloquea Atrás durante el guardado y lo reactiva tras error', (
    tester,
  ) async {
    final respuesta = Completer<bool>();
    await mostrarPantalla(tester, guardar: (_) => respuesta.future);
    await seleccionar(tester, 'Bodega');
    await mostrarConfirmacion(tester);

    await tester.tap(find.byKey(const Key('confirmar-rubro')));
    await tester.pump();

    final volver = find.widgetWithIcon(IconButton, Icons.arrow_back);
    expect(tester.widget<IconButton>(volver).onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('¿A qué se dedica\ntu negocio?'), findsOneWidget);
    expect(find.text('Abrir Rubro'), findsNothing);

    respuesta.complete(false);
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(volver).onPressed, isNotNull);
    await tester.tap(volver);
    await tester.pumpAndSettle();
    expect(find.text('Abrir Rubro'), findsOneWidget);
    expect(find.text('¿A qué se dedica\ntu negocio?'), findsNothing);
  });

  testWidgets('cancelar el diálogo no escribe ni cambia la selección', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    var guardados = 0;
    await mostrarPantalla(
      tester,
      rubroInicial: 'Bodega',
      guardar: (_) async {
        guardados++;
        return true;
      },
    );
    await seleccionar(tester, 'Restaurante');
    await mostrarConfirmacion(tester);

    await tester.tap(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(guardados, 0);
    expect(
      tester
          .getSemantics(find.byKey(const Key('rubro-card-Restaurante')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('rubro-card-Bodega')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isFalse,
    );
    semantica.dispose();
  });
}
