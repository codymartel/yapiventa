import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/boton_volver_al_producto.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_content.dart';
import 'package:provider/provider.dart';

void main() {
  ConfiguracionNegocioProvider crearProvider() => ConfiguracionNegocioProvider(
    rubro: 'Bodega',
    repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
  );

  Future<void> montar(
    WidgetTester tester,
    Widget hijo, {
    required ConfiguracionNegocioProvider provider,
  }) async {
    tester.view.physicalSize = const Size(500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
            value: provider,
            child: hijo,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('guarda el catálogo y vuelve al producto', (tester) async {
    final provider = crearProvider();
    var volvio = 0;
    await montar(
      tester,
      BotonVolverAlProducto(
        uid: 'usuario-1',
        onVolverAlProducto: () => volvio++,
      ),
      provider: provider,
    );

    await tester.tap(find.byKey(const Key('guardar-y-volver-al-producto')));
    await tester.pumpAndSettle();

    expect(volvio, 1);
  });

  group('en la pantalla de Configuración', () {
    Widget contenido(VoidCallback? alProducto) => ConfiguracionNegocioContent(
      uid: 'usuario-1',
      rubro: 'Bodega',
      onVolver: () {},
      onFinalizar: () {},
      onVolverAlProducto: alProducto,
    );

    testWidgets('el botón solo aparece en el paso Catálogo', (tester) async {
      final provider = crearProvider();
      await montar(tester, contenido(() {}), provider: provider);

      const boton = Key('guardar-y-volver-al-producto');
      expect(find.byKey(boton), findsNothing);

      provider.irAPaso(1);
      await tester.pump();
      expect(find.byKey(boton), findsOneWidget);

      provider.irAPaso(2);
      await tester.pump();
      expect(find.byKey(boton), findsNothing);
    });

    testWidgets('sin venir de un producto no se muestra', (tester) async {
      final provider = crearProvider();
      await montar(tester, contenido(null), provider: provider);

      provider.irAPaso(1);
      await tester.pump();

      expect(
        find.byKey(const Key('guardar-y-volver-al-producto')),
        findsNothing,
      );
    });
  });
}
