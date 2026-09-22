import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_negocio.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_catalogo.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_logistica.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_pagos.dart';
import 'package:provider/provider.dart';

void main() {
  Future<ConfiguracionNegocioProvider> montarContenido(
    WidgetTester tester, {
    String rubro = 'Bodega',
    VoidCallback? onVolver,
    VoidCallback? onFinalizar,
  }) async {
    final provider = ConfiguracionNegocioProvider(
      rubro: rubro,
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );
    tester.view.physicalSize = const Size(500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
        home: Material(
          color: AppColors.fondo,
          child: ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
            value: provider,
            child: ConfiguracionNegocioContent(
              rubro: rubro,
              onVolver: onVolver ?? () {},
              onFinalizar: onFinalizar ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  Finder indexedStackDelContenido() => find
      .descendant(
        of: find.byType(ConfiguracionNegocioContent),
        matching: find.byType(IndexedStack),
      )
      .first;

  Future<ConfiguracionNegocioProvider> completarPaso0(
    WidgetTester tester, {
    VoidCallback? onVolver,
    VoidCallback? onFinalizar,
  }) async {
    final provider = await montarContenido(
      tester,
      onVolver: onVolver,
      onFinalizar: onFinalizar,
    );
    provider.nombreNegocio = 'Bodega Ana';
    provider.telefono = '999999999';
    provider.direccion = 'Av. Lima 123';
    provider.referencia = 'Frente al parque';
    await tester.pump();
    return provider;
  }

  testWidgets('no contiene Scaffold ni AppBar', (tester) async {
    await montarContenido(tester);

    expect(
      find.descendant(
        of: find.byType(ConfiguracionNegocioContent),
        matching: find.byType(Scaffold),
      ),
      findsNothing,
    );
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('monta los cuatro pasos mediante IndexedStack', (tester) async {
    await montarContenido(tester);

    final stack = tester.widget<IndexedStack>(indexedStackDelContenido());
    expect(stack.index, 0);
    expect(stack.children, hasLength(4));
    expect(find.byType(PasoNegocio, skipOffstage: false), findsOneWidget);
    expect(find.byType(PasoCatalogo, skipOffstage: false), findsOneWidget);
    expect(find.byType(PasoLogistica, skipOffstage: false), findsOneWidget);
    expect(find.byType(PasoPagos, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Atrás, Siguiente y Finalizar ejecutan los callbacks correctos', (
    tester,
  ) async {
    var volveres = 0;
    var finalizadas = 0;
    final provider = await completarPaso0(
      tester,
      onVolver: () => volveres++,
      onFinalizar: () => finalizadas++,
    );

    expect(find.text('Atrás'), findsNothing);
    expect(find.text('Cambiar rubro'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);

    await tester.tap(find.text('Cambiar rubro'));
    await tester.pump();
    expect(volveres, 1);

    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    expect(provider.pasoActual, 1);
    expect(find.text('Atrás'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pump();
    expect(provider.pasoActual, 0);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
    }
    expect(provider.pasoActual, 3);
    expect(find.text('Finalizar'), findsOneWidget);

    await tester.tap(find.text('Finalizar'));
    await tester.pump();
    expect(finalizadas, 1);
  });

  testWidgets('conserva el paso actual y los campos al avanzar y retroceder', (
    tester,
  ) async {
    final provider = await completarPaso0(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del negocio *'),
      'Mi Tienda',
    );
    await tester.pump();

    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    expect(provider.pasoActual, 1);
    expect(tester.widget<IndexedStack>(indexedStackDelContenido()).index, 1);

    await tester.tap(find.text('Atrás'));
    await tester.pump();
    expect(provider.pasoActual, 0);
    expect(tester.widget<IndexedStack>(indexedStackDelContenido()).index, 0);
    expect(provider.nombreNegocio, 'Mi Tienda');
    expect(find.widgetWithText(TextField, 'Mi Tienda'), findsOneWidget);
  });
}
