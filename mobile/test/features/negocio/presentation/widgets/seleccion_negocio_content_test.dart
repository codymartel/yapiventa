import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_negocio_screen.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_negocio_content.dart';

void main() {
  Future<void> mostrarContenido(
    WidgetTester tester, {
    Size size = const Size(360, 700),
    TextScaler textScaler = TextScaler.noScaling,
    String? seleccionado,
    bool guardando = false,
    String? error,
    ValueChanged<String>? onSeleccionar,
    VoidCallback? onConfirmar,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Material(
          color: SeleccionNegocioContent.fondo,
          child: SeleccionNegocioContent(
            rubroSeleccionado: seleccionado,
            guardando: guardando,
            error: error,
            onRubroSeleccionado: onSeleccionar ?? (_) {},
            onConfirmar: onConfirmar ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('conserva selección y dispara ambos callbacks', (tester) async {
    final semantica = tester.ensureSemantics();
    final selecciones = <String>[];
    var confirmaciones = 0;
    await mostrarContenido(
      tester,
      seleccionado: 'Bodega',
      onSeleccionar: selecciones.add,
      onConfirmar: () => confirmaciones++,
    );

    expect(
      tester
          .getSemantics(find.byKey(const Key('rubro-card-Bodega')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    await tester.tap(find.byKey(const Key('rubro-card-Restaurante')));
    await tester.ensureVisible(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-rubro')));

    expect(selecciones, ['Restaurante']);
    expect(confirmaciones, 1);
    expect(
      find.descendant(
        of: find.byType(SeleccionNegocioContent),
        matching: find.byType(Scaffold),
      ),
      findsNothing,
    );
    semantica.dispose();
    expect(
      find.descendant(
        of: find.byType(SeleccionNegocioContent),
        matching: find.byType(Navigator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SeleccionNegocioContent),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

  testWidgets('activa una tarjeta con teclado', (tester) async {
    final selecciones = <String>[];
    await mostrarContenido(tester, onSeleccionar: selecciones.add);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(selecciones, ['Bodega']);
  });

  testWidgets('usa una columna y padding 16 en 360 px', (tester) async {
    await mostrarContenido(tester);

    final primera = tester.getRect(find.byKey(const Key('rubro-card-Bodega')));
    final segunda = tester.getRect(
      find.byKey(const Key('rubro-card-Restaurante')),
    );
    expect(primera.left, 16);
    expect(segunda.left, primera.left);
    expect(segunda.top, greaterThan(primera.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('funciona sin overflow en el centro futuro de 478 px', (
    tester,
  ) async {
    await mostrarContenido(tester, size: const Size(478, 700));

    expect(find.byKey(const Key('rubros-wrap')), findsOneWidget);
    expect(find.byKey(const Key('confirmar-rubro')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distribuye dos columnas en 768 px', (tester) async {
    await mostrarContenido(tester, size: const Size(768, 800));

    final primera = tester.getRect(find.byKey(const Key('rubro-card-Bodega')));
    final segunda = tester.getRect(
      find.byKey(const Key('rubro-card-Restaurante')),
    );
    final tercera = tester.getRect(find.byKey(const Key('rubro-card-Ropa')));
    expect(segunda.top, primera.top);
    expect(segunda.left, greaterThan(primera.right));
    expect(tercera.top, greaterThan(primera.bottom));
  });

  testWidgets('distribuye hasta tres columnas en 868 px', (tester) async {
    await mostrarContenido(tester, size: const Size(868, 800));

    final primera = tester.getRect(find.byKey(const Key('rubro-card-Bodega')));
    final segunda = tester.getRect(
      find.byKey(const Key('rubro-card-Restaurante')),
    );
    final tercera = tester.getRect(find.byKey(const Key('rubro-card-Ropa')));
    final cuarta = tester.getRect(find.byKey(const Key('rubro-card-Farmacia')));
    expect(segunda.top, primera.top);
    expect(tercera.top, primera.top);
    expect(cuarta.top, greaterThan(primera.bottom));
  });

  testWidgets('mantiene el CTA alcanzable mediante el único scroll', (
    tester,
  ) async {
    var confirmaciones = 0;
    await mostrarContenido(
      tester,
      size: const Size(360, 420),
      seleccionado: 'Bodega',
      onConfirmar: () => confirmaciones++,
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-rubro')));

    expect(confirmaciones, 1);
    expect(tester.takeException(), isNull);
  });

  for (final escala in [1.3, 2.0]) {
    testWidgets('no desborda en 360 px con texto $escala', (tester) async {
      await mostrarContenido(
        tester,
        textScaler: TextScaler.linear(escala),
        seleccionado: 'Bodega',
      );

      await tester.ensureVisible(
        find.text('Configuración de inventario inteligente'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('deshabilita tarjetas y CTA mientras guarda', (tester) async {
    final semantica = tester.ensureSemantics();
    final selecciones = <String>[];
    var confirmaciones = 0;
    await mostrarContenido(
      tester,
      seleccionado: 'Bodega',
      guardando: true,
      onSeleccionar: selecciones.add,
      onConfirmar: () => confirmaciones++,
    );

    await tester.tap(find.byKey(const Key('rubro-card-Restaurante')));

    expect(selecciones, isEmpty);
    expect(confirmaciones, 0);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('confirmar-rubro')))
          .onPressed,
      isNull,
    );
    expect(find.text('Guardando...'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('rubro-card-Bodega')))
          .flagsCollection
          .isEnabled,
      ui.Tristate.isFalse,
    );
    semantica.dispose();
  });

  testWidgets('el wrapper conserva volver, diálogo y error de guardado', (
    tester,
  ) async {
    var vueltas = 0;
    final guardados = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SeleccionNegocioScreen(
          rubroInicial: 'Bodega',
          onVolverDashboard: () => vueltas++,
          onTipoSeleccionado: (rubro) async {
            guardados.add(rubro);
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver al dashboard'));
    await tester.tap(find.byKey(const Key('rubro-card-Restaurante')));
    await tester.ensureVisible(find.byKey(const Key('confirmar-rubro')));
    await tester.tap(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();

    expect(vueltas, 1);
    expect(find.text('Cambiar rubro'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(guardados, isEmpty);

    await tester.tap(find.byKey(const Key('confirmar-rubro')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar y revisar'));
    await tester.pumpAndSettle();

    expect(guardados, ['Restaurante']);
    expect(
      find.text('No se pudo guardar el rubro. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
