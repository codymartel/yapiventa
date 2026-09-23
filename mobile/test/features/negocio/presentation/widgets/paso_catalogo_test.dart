import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_catalogo.dart';
import 'package:provider/provider.dart';

void main() {
  Future<ConfiguracionNegocioProvider> mostrarPaso(
    WidgetTester tester, {
    String rubro = 'Bodega',
    Size size = const Size(900, 2400),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ConfiguracionNegocioProvider(
      rubro: rubro,
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const Scaffold(body: PasoCatalogo()),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  testWidgets('muestra cantidades comerciales sin decimales técnicos', (
    tester,
  ) async {
    await mostrarPaso(tester);

    expect(find.textContaining('Media docena'), findsOneWidget);
    expect(find.textContaining('250 g'), findsOneWidget);
    expect(find.textContaining('1½ kg'), findsOneWidget);
    expect(find.textContaining('500 ml'), findsOneWidget);
    expect(find.textContaining('1½ L'), findsOneWidget);
    expect(find.text('0.25'), findsNothing);
    expect(find.text('0.5'), findsNothing);
    expect(find.text('1.5'), findsNothing);
  });

  testWidgets('permite desactivar y reactivar un preset del sistema', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    final tarjeta = find.byKey(const Key('unidad-predefinida-Botella'));
    final switchFinder = find.descendant(
      of: tarjeta,
      matching: find.byType(Switch),
    );

    expect(provider.unidadPredefinidaActiva('Botella'), isTrue);
    await tester.tap(switchFinder);
    await tester.pump();
    expect(provider.unidadPredefinidaActiva('Botella'), isFalse);
    expect(tarjeta, findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pump();
    expect(provider.unidadPredefinidaActiva('Botella'), isTrue);
  });

  for (final ancho in [320.0, 360.0, 768.0, 1050.0, 1440.0]) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets('sin overflow a ${ancho}px con texto $escala', (
        tester,
      ) async {
        await mostrarPaso(
          tester,
          size: Size(ancho, 900),
          textScaler: TextScaler.linear(escala),
        );

        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
