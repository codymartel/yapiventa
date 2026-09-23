import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_plantilla_content.dart';

void main() {
  Future<void> mostrarContenido(
    WidgetTester tester, {
    Size size = const Size(360, 700),
    TextScaler textScaler = TextScaler.noScaling,
    String rubro = 'Bodega',
    PlantillaWeb? seleccionada,
    PlantillaWeb? plantillaGuardada,
    bool cargando = false,
    bool cargado = true,
    bool guardando = false,
    bool cambiosPendientes = false,
    bool progresoRecargado = true,
    String? error,
    ValueChanged<PlantillaWeb>? onSeleccionar,
    VoidCallback? onGuardar,
    VoidCallback? onFinalizar,
    VoidCallback? onVerTienda,
    VoidCallback? onIrDashboard,
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
          color: SeleccionPlantillaContent.fondo,
          child: SeleccionPlantillaContent(
            rubro: rubro,
            plantillaSeleccionada: seleccionada,
            plantillaGuardada: plantillaGuardada,
            cargando: cargando,
            cargado: cargado,
            guardando: guardando,
            cambiosPendientes: cambiosPendientes,
            progresoRecargado: progresoRecargado,
            error: error,
            onSeleccionarPlantilla: onSeleccionar ?? (_) {},
            onGuardar: onGuardar ?? () {},
            onFinalizar: onFinalizar ?? () {},
            onVerTienda: onVerTienda ?? () {},
            onIrDashboard: onIrDashboard ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('conserva selección y dispara los callbacks', (tester) async {
    final semantica = tester.ensureSemantics();
    final selecciones = <PlantillaWeb>[];
    var guardados = 0;
    var finalizaciones = 0;
    var visitas = 0;
    var dashboards = 0;
    await mostrarContenido(
      tester,
      seleccionada: PlantillaWeb.neon,
      plantillaGuardada: PlantillaWeb.neon,
      onSeleccionar: selecciones.add,
      onGuardar: () => guardados++,
      onFinalizar: () => finalizaciones++,
      onVerTienda: () => visitas++,
      onIrDashboard: () => dashboards++,
    );

    expect(
      tester
          .getSemantics(find.byKey(const Key('plantilla-card-neon')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-cristal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-cristal')));

    await tester.ensureVisible(find.byKey(const Key('guardar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar-plantilla')));

    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finalizar-plantilla')));

    await tester.ensureVisible(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ver-tienda-plantilla')));

    await tester.ensureVisible(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-dashboard-plantilla')));

    expect(selecciones, [PlantillaWeb.cristal]);
    expect(guardados, 1);
    expect(finalizaciones, 1);
    expect(visitas, 1);
    expect(dashboards, 1);
    expect(
      find.descendant(
        of: find.byType(SeleccionPlantillaContent),
        matching: find.byType(Scaffold),
      ),
      findsNothing,
    );
    semantica.dispose();
    expect(
      find.descendant(
        of: find.byType(SeleccionPlantillaContent),
        matching: find.byType(Navigator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SeleccionPlantillaContent),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

  testWidgets('muestra las 4 plantillas y su selección visual', (tester) async {
    await mostrarContenido(tester, seleccionada: PlantillaWeb.cristal);

    expect(find.byKey(const Key('plantillas-wrap')), findsOneWidget);
    for (final plantilla in ['Neon', 'Cristal', 'Sabroso', 'Galería']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('plantillas-wrap')),
          matching: find.text(plantilla),
        ),
        findsOneWidget,
      );
    }

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-cristal')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('plantilla-card-cristal')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('plantilla-card-neon')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
    );
  });

  testWidgets('activa una tarjeta con teclado', (tester) async {
    final selecciones = <PlantillaWeb>[];
    await mostrarContenido(tester, onSeleccionar: selecciones.add);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(selecciones, [PlantillaWeb.neon]);
  });

  testWidgets('usa una columna en 360 px', (tester) async {
    await mostrarContenido(tester);

    final primera = tester.getRect(
      find.byKey(const Key('plantilla-card-neon')),
    );
    final segunda = tester.getRect(
      find.byKey(const Key('plantilla-card-cristal')),
    );
    expect(primera.left, 24);
    expect(segunda.left, primera.left);
    expect(segunda.top, greaterThan(primera.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('usa dos columnas en 768 px', (tester) async {
    await mostrarContenido(tester, size: const Size(768, 800));

    final primera = tester.getRect(
      find.byKey(const Key('plantilla-card-neon')),
    );
    final segunda = tester.getRect(
      find.byKey(const Key('plantilla-card-cristal')),
    );
    final tercera = tester.getRect(
      find.byKey(const Key('plantilla-card-sabroso')),
    );
    expect(segunda.top, primera.top);
    expect(segunda.left, greaterThan(primera.right));
    expect(tercera.top, greaterThan(primera.bottom));
  });

  testWidgets('usa cuatro columnas desde 1050 px', (tester) async {
    await mostrarContenido(tester, size: const Size(1050, 900));

    final primera = tester.getRect(
      find.byKey(const Key('plantilla-card-neon')),
    );
    final segunda = tester.getRect(
      find.byKey(const Key('plantilla-card-cristal')),
    );
    final tercera = tester.getRect(
      find.byKey(const Key('plantilla-card-sabroso')),
    );
    final cuarta = tester.getRect(
      find.byKey(const Key('plantilla-card-galeria')),
    );
    expect(segunda.top, primera.top);
    expect(tercera.top, primera.top);
    expect(cuarta.top, primera.top);
    expect(primera.left, 59.0);
    expect(primera.right, lessThan(980));
  });

  testWidgets('estado de carga muestra el indicador y oculta la grilla', (
    tester,
  ) async {
    await mostrarContenido(tester, cargando: true, cargado: false);

    expect(find.byKey(const Key('plantilla-cargando')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('plantillas-wrap')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra el error de guardado', (tester) async {
    await mostrarContenido(tester, error: 'Fallo al guardar la plantilla.');

    expect(find.text('Fallo al guardar la plantilla.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deshabilita los botones según el estado de guardado', (
    tester,
  ) async {
    await mostrarContenido(
      tester,
      guardando: true,
      seleccionada: PlantillaWeb.neon,
      plantillaGuardada: PlantillaWeb.neon,
      cambiosPendientes: true,
      progresoRecargado: false,
    );

    await tester.ensureVisible(find.byKey(const Key('guardar-plantilla')));
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('guardar-plantilla')))
          .onPressed,
      isNull,
    );
    expect(find.text('Guardando...'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('ver-tienda-plantilla')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('finalizar-plantilla')))
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('ir-dashboard-plantilla')),
          )
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionPlantillaContent(
            rubro: 'Bodega',
            plantillaSeleccionada: PlantillaWeb.galeria,
            plantillaGuardada: PlantillaWeb.galeria,
            cargando: false,
            cargado: true,
            guardando: false,
            cambiosPendientes: false,
            progresoRecargado: true,
            error: null,
            onSeleccionarPlantilla: (_) {},
            onGuardar: () {},
            onFinalizar: () {},
            onVerTienda: () {},
            onIrDashboard: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guardar-plantilla')));
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('guardar-plantilla')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('ver-tienda-plantilla')))
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('finalizar-plantilla')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('ir-dashboard-plantilla')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Ver tienda se deshabilita sin plantilla guardada', (
    tester,
  ) async {
    await mostrarContenido(
      tester,
      seleccionada: PlantillaWeb.cristal,
      plantillaGuardada: null,
    );

    await tester.ensureVisible(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('ver-tienda-plantilla')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Finalizar exige plantilla guardada, sin cambios y recarga lista',
    (tester) async {
      ElevatedButton finalizar(WidgetTester t) => t.widget<ElevatedButton>(
        find.byKey(const Key('finalizar-plantilla')),
      );

      await mostrarContenido(
        tester,
        seleccionada: PlantillaWeb.cristal,
        plantillaGuardada: null,
      );
      final botonSinGuardada = finalizar(tester);
      expect(botonSinGuardada.onPressed, isNull);

      await mostrarContenido(
        tester,
        seleccionada: PlantillaWeb.cristal,
        plantillaGuardada: PlantillaWeb.cristal,
        cambiosPendientes: true,
      );
      expect(finalizar(tester).onPressed, isNull);

      await mostrarContenido(
        tester,
        seleccionada: PlantillaWeb.cristal,
        plantillaGuardada: PlantillaWeb.cristal,
        progresoRecargado: false,
      );
      expect(finalizar(tester).onPressed, isNull);

      await mostrarContenido(
        tester,
        seleccionada: PlantillaWeb.cristal,
        plantillaGuardada: PlantillaWeb.cristal,
      );
      expect(finalizar(tester).onPressed, isNotNull);
    },
  );

  for (final ancho in [320, 360, 500, 768, 1050, 1440]) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets('no desborda en $ancho px con texto x$escala', (
        tester,
      ) async {
        await mostrarContenido(
          tester,
          size: Size(ancho.toDouble(), 700),
          textScaler: TextScaler.linear(escala),
          seleccionada: PlantillaWeb.cristal,
          plantillaGuardada: PlantillaWeb.cristal,
        );

        for (final key in const [
          'guardar-plantilla',
          'finalizar-plantilla',
          'ver-tienda-plantilla',
          'ir-dashboard-plantilla',
        ]) {
          await tester.ensureVisible(find.byKey(Key(key)));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
