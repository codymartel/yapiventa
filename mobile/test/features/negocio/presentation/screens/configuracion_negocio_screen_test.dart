import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/screens/configuracion_negocio_screen.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_flow.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> montarPantalla(
    WidgetTester tester, {
    required ConfiguracionNegocioProvider provider,
    VoidCallback? onVolver,
    VoidCallback? onCompletado,
    Future<void> Function(String uid, String? negocioId)? onRecargarProgreso,
  }) async {
    tester.view.physicalSize = const Size(500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
          value: provider,
          child: ConfiguracionNegocioScreen(
            uid: 'usuario-1',
            negocioId: 'negocio-1',
            onVolver: onVolver ?? () {},
            onCompletado: onCompletado ?? () {},
            onRecargarProgreso: onRecargarProgreso,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ConfiguracionNegocioProvider completarDatos() {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
    );
    provider.nombreNegocio = 'Bodega Ana';
    provider.telefono = '999999999';
    provider.direccion = 'Av. Lima 123';
    provider.referencia = 'Frente al parque';
    return provider;
  }

  testWidgets('conserva un único Scaffold y monta el flujo', (tester) async {
    await montarPantalla(tester, provider: completarDatos());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
    expect(find.text('Configura tu Bodega'), findsOneWidget);
  });

  testWidgets('el botón volver del paso inicial ejecuta onVolver', (
    tester,
  ) async {
    var volveres = 0;
    await montarPantalla(
      tester,
      provider: completarDatos(),
      onVolver: () => volveres++,
    );

    await tester.tap(find.text('Cambiar rubro'));
    await tester.pump();

    expect(volveres, 1);
  });

  testWidgets('finalizar guarda la configuración y luego ejecuta onCompletado', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: firestore),
    );
    provider.nombreNegocio = 'Bodega Ana';
    provider.telefono = '999999999';
    provider.direccion = 'Av. Lima 123';
    provider.referencia = 'Frente al parque';

    var completadas = 0;
    await montarPantalla(
      tester,
      provider: provider,
      onCompletado: () => completadas++,
      onRecargarProgreso: (uid, negocioId) async {},
    );

    provider.irAPaso(3);
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(completadas, 1);
    expect(provider.guardando, isFalse);
    expect(provider.errorValidacion, isNull);
    final negocio = await firestore.collection('negocios').get();
    expect(negocio.docs, hasLength(1));
    expect(negocio.docs.single.data()['nombreNegocio'], 'Bodega Ana');
  });
}