import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_negocio.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> mostrarPasoNegocio(
    WidgetTester tester, {
    required Size size,
    required TextScaler textScaler,
  }) async {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );
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
        home: ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
          value: provider,
          child: const Scaffold(body: PasoNegocio()),
        ),
      ),
    );
    await tester.pump();
  }

  const anchos = <double>[360, 500, 768, 1050];

  for (final ancho in anchos) {
    testWidgets('no desborda paso_negocio a $ancho px', (tester) async {
      await mostrarPasoNegocio(
        tester,
        size: Size(ancho, 900),
        textScaler: TextScaler.noScaling,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no desborda paso_negocio a $ancho px con texto 1.3', (
      tester,
    ) async {
      await mostrarPasoNegocio(
        tester,
        size: Size(ancho, 900),
        textScaler: TextScaler.linear(1.3),
      );
      expect(tester.takeException(), isNull);
    });
  }
}