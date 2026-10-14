import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_negocio.dart';
import 'package:provider/provider.dart';

void main() {
  Future<ConfiguracionNegocioProvider> mostrarPasoNegocio(
    WidgetTester tester, {
    required Size size,
    required TextScaler textScaler,
    Map<String, dynamic>? configuracionInicial,
  }) async {
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      configuracionInicial: configuracionInicial,
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
    return provider;
  }

  const anchos = <double>[360, 500, 768, 1050, 1440];
  const escalas = <double>[1.0, 1.3, 2.0];

  for (final ancho in anchos) {
    for (final escala in escalas) {
      testWidgets(
        'no desborda paso_negocio a $ancho px con texto ${escala}x',
        (tester) async {
          await mostrarPasoNegocio(
            tester,
            size: Size(ancho, 900),
            textScaler: TextScaler.linear(escala),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // ── Diseño responsive ────────────────────────────────────────────────
  testWidgets('a 360 px los campos quedan en una sola columna', (tester) async {
    await mostrarPasoNegocio(
      tester,
      size: const Size(360, 900),
      textScaler: TextScaler.noScaling,
    );
    final nombre = tester.getRect(find.byKey(const Key('campo_nombre')));
    final whatsapp = tester.getRect(find.byKey(const Key('campo_telefono')));
    final direccion = tester.getRect(find.byKey(const Key('campo_direccion')));
    expect(whatsapp.top, greaterThan(nombre.bottom - 1));
    expect(direccion.top, greaterThan(whatsapp.bottom - 1));
  });

  testWidgets('a 500 px nombre y WhatsApp quedan uno encima del otro', (
    tester,
  ) async {
    await mostrarPasoNegocio(
      tester,
      size: const Size(500, 900),
      textScaler: TextScaler.noScaling,
    );
    final nombre = tester.getRect(find.byKey(const Key('campo_nombre')));
    final whatsapp = tester.getRect(find.byKey(const Key('campo_telefono')));
    expect(whatsapp.top, greaterThan(nombre.bottom - 1));
  });

  testWidgets('a 768 px los campos siguen en una sola columna', (
    tester,
  ) async {
    await mostrarPasoNegocio(
      tester,
      size: const Size(768, 900),
      textScaler: TextScaler.noScaling,
    );
    final nombre = tester.getRect(find.byKey(const Key('campo_nombre')));
    final labelWhatsApp = tester.getRect(find.text('WhatsApp *'));
    final direccion = tester.getRect(find.byKey(const Key('campo_direccion')));
    // El rediseño trabaja en una sola columna a cualquier ancho: cada campo
    // ocupa el ancho útil completo, sin filas a dos columnas.
    expect(labelWhatsApp.top, greaterThan(nombre.bottom - 1));
    expect(direccion.top, greaterThan(labelWhatsApp.bottom - 1));
    expect(direccion.width, closeTo(nombre.width, 1));
  });

  testWidgets('a 1050 px el formulario se distribuye correctamente', (
    tester,
  ) async {
    await mostrarPasoNegocio(
      tester,
      size: const Size(1050, 900),
      textScaler: TextScaler.noScaling,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('campo_nombre')), findsOneWidget);
    expect(find.byKey(const Key('campo_telefono')), findsOneWidget);
    expect(find.byKey(const Key('campo_direccion')), findsOneWidget);
    expect(find.byKey(const Key('campo_referencia')), findsOneWidget);
  });

  testWidgets('a 1440 px el contenido no queda exageradamente estirado', (
    tester,
  ) async {
    await mostrarPasoNegocio(
      tester,
      size: const Size(1440, 900),
      textScaler: TextScaler.noScaling,
    );
    final nombre = tester.getRect(find.byKey(const Key('campo_nombre')));
    final telefono = tester.getRect(find.byKey(const Key('campo_telefono')));
    final anchoContenido = telefono.right - nombre.left;
    // El ancho útil está acotado por diseño (860 px como máximo): ni el campo
    // ni el conjunto pueden estirarse a lo ancho de la ventana.
    expect(nombre.width, lessThanOrEqualTo(860));
    expect(anchoContenido, lessThanOrEqualTo(860));
    expect(tester.takeException(), isNull);
  });

  // ── Estado y prefijo ──────────────────────────────────────────────────
  testWidgets('los valores escritos se conservan al reconstruir', (
    tester,
  ) async {
    final provider = await mostrarPasoNegocio(
      tester,
      size: const Size(1050, 900),
      textScaler: TextScaler.noScaling,
    );
    await tester.enterText(
      find.byKey(const Key('campo_nombre')),
      'Carnes Don José',
    );
    await tester.pump();

    await mostrarPasoNegocio(
      tester,
      size: const Size(1050, 900),
      textScaler: TextScaler.noScaling,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('campo_nombre'))).controller?.text,
      'Carnes Don José',
    );
    expect(provider.nombreNegocio, 'Carnes Don José');
  });

  testWidgets('cambiar el prefijo no cierra el paso', (tester) async {
    final provider = await mostrarPasoNegocio(
      tester,
      size: const Size(1050, 900),
      textScaler: TextScaler.noScaling,
    );
    final prefijoInicial = provider.paisTelefono.prefijo;

    await tester.tap(find.byKey(const Key('selector_pais')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+55 Brasil').last);
    await tester.pumpAndSettle();

    expect(provider.paisTelefono.prefijo, isNot(prefijoInicial));
    expect(find.byType(PasoNegocio), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── Datos antiguos con RUC ────────────────────────────────────────────
  testWidgets('documentos antiguos con RUC cargan sin excepción', (
    tester,
  ) async {
    final provider = await mostrarPasoNegocio(
      tester,
      size: const Size(360, 900),
      textScaler: TextScaler.noScaling,
      configuracionInicial: const {
        'nombreNegocio': 'Bodega Antigua',
        'ruc': '20123456789',
      },
    );
    expect(tester.takeException(), isNull);
    expect(provider.ruc, '20123456789');
    expect(find.textContaining('RUC'), findsNothing);
    expect(find.byKey(const Key('campo_nombre')), findsOneWidget);
  });
}