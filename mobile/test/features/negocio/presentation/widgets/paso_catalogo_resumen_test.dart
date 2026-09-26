import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_catalogo.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:provider/provider.dart';

void main() {
  Future<ConfiguracionNegocioProvider> mostrarPaso(
    WidgetTester tester, {
    String rubro = 'Bodega',
    Size size = const Size(900, 2400),
    TextScaler textScaler = TextScaler.noScaling,
    Map<String, dynamic>? configuracionInicial,
    FakeFirebaseFirestore? firestore,
    String? negocioId,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ConfiguracionNegocioProvider(
      rubro: rubro,
      negocioId: negocioId,
      configuracionInicial: configuracionInicial,
      repository: NegocioRepository(
        firestore: firestore ?? FakeFirebaseFirestore(),
      ),
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

  Future<void> verResumen(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const Key('seccion-resumen-catalogo')),
    );
    await tester.pumpAndSettle();
  }

  FormatoPresentacion volumen(int ml) => FormatoPresentacion(
    valorBase: ml,
    familia: FamiliaUnidad.volumen,
    unidadVisible: RegistroUnidades.ml,
  );

  // ── 1. Cantidades del resumen ─────────────────────────────────────────
  testWidgets('el resumen muestra las cantidades del catálogo del rubro', (
    tester,
  ) async {
    await mostrarPaso(tester, rubro: 'Bodega');
    await verResumen(tester);

    expect(find.text('Resumen del catálogo'), findsOneWidget);
    final catalogo = CatalogoVentaPersistido.desdePreset(
      PresetsVenta.obtener('Bodega'),
    );

    Finder enFila(String fila, String texto) =>
        find.descendant(of: find.byKey(Key(fila)), matching: find.text(texto));

    expect(
      enFila(
        'resumen-categorias',
        '${PresetsVenta.obtener('Bodega').categorias.length}',
      ),
      findsOneWidget,
    );
    expect(
      enFila(
        'resumen-presentaciones',
        '${catalogo.presentaciones.where((p) => p.activa).length}',
      ),
      findsOneWidget,
    );
    expect(
      enFila(
        'resumen-medidas',
        '${catalogo.medidas.where((m) => m.activa).length}',
      ),
      findsOneWidget,
    );
    expect(
      enFila(
        'resumen-formatos',
        '${catalogo.presentaciones.fold(0, (n, p) => n + p.formatos.length)}',
      ),
      findsOneWidget,
    );
    expect(
      enFila(
        'resumen-cantidades-rapidas',
        '${catalogo.medidas.fold(0, (n, m) => n + m.cantidadesRapidasBase.length)}',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('resumen-errores')),
        matching: find.text('Ninguno'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('las cantidades coinciden con las del borrador en memoria', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await verResumen(tester);

    expect(
      provider.categoriasActivas,
      PresetsVenta.obtener('Bodega').categorias.length,
    );
    expect(
      provider.presentacionesActivas,
      provider.catalogoVenta.presentaciones.where((p) => p.activa).length,
    );
    expect(
      provider.medidasActivas,
      provider.catalogoVenta.medidas.where((m) => m.activa).length,
    );
    expect(provider.totalCantidadesRapidas, 8);
    expect(provider.medidasPendientesRevision, isEmpty);
  });

  // ── 2. Reactividad del resumen ───────────────────────────────────────
  testWidgets('el resumen reacciona a los cambios del borrador', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester, negocioId: 'negocio-1');
    await verResumen(tester);

    final categoriasIniciales = provider.categoriasActivas;
    final formatosIniciales = provider.totalFormatos;

    // El contador sigue a las categorías EFECTIVAS, no al borrador legacy: una
    // personalizada activa suma y una desactivada ya no cuenta.
    await provider.agregarCategoriaPersonalizada('usuario-1', 'Ofertas');
    provider.agregarFormato('botella', volumen(100));
    await tester.pump();

    final nuevosCategorias = find.descendant(
      of: find.byKey(const Key('resumen-categorias')),
      matching: find.text('${categoriasIniciales + 1}'),
    );
    final nuevosFormatos = find.descendant(
      of: find.byKey(const Key('resumen-formatos')),
      matching: find.text('${formatosIniciales + 1}'),
    );
    expect(nuevosCategorias, findsOneWidget);
    expect(nuevosFormatos, findsOneWidget);
    expect(provider.totalFormatos, formatosIniciales + 1);

    await provider.desactivarCategoriaPersonalizada('usuario-1', 'ofertas');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('resumen-categorias')),
        matching: find.text('$categoriasIniciales'),
      ),
      findsOneWidget,
    );
  });

  // ── 3. Errores pendientes ────────────────────────────────────────────
  testWidgets('errores pendientes muestra las medidas por revisar', (
    tester,
  ) async {
    await mostrarPaso(
      tester,
      configuracionInicial: {
        'nombreNegocio': 'Bodega Ana',
        'catalogoVenta': {
          'versionEsquema': 1,
          'presentaciones': <Map<String, dynamic>>[],
          'medidas': [
            {
              'id': 'docena',
              'nombre': 'Docena',
              'minimoBase': 0,
              'incrementoBase': 0,
              'cantidadesRapidasBase': <int>[],
              'permiteCantidad': true,
              'permiteMonto': false,
              'activa': false,
              'obligatoria': false,
              'requiereRevision': true,
            },
          ],
        },
        'delivery': false,
      },
    );
    await verResumen(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('resumen-errores')),
        matching: find.textContaining(
          'Medidas pendientes de revisión: Docena.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('resumen-errores')),
        matching: find.text('Ninguno'),
      ),
      findsNothing,
    );
  });

  // ── 4. Legacy: unidad legacy ya no genera revisión ────────────────
  testWidgets(
    'una unidad legacy sin mapeo seguro no aparece como error',
    (tester) async {
      final provider = await mostrarPaso(
        tester,
        configuracionInicial: {
          'unidadesMedida': [
            {
              'nombre': 'Docena',
              'tipo': 'fraccionaria',
              'fraccionesPermitidas': <String>[],
              'esOpcional': true,
            },
          ],
        },
      );
      await verResumen(tester);

      // Con la corrección, el catálogo se mantiene desde el preset.
      // Las unidades legacy no generan medidas pendientes de revisión.
      expect(provider.medidasPendientesRevision, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(const Key('resumen-errores')),
          matching: find.text('Ninguno'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ── 5. Siguiente: legacy no bloquea el avance ───────────────
  testWidgets(
    'Siguiente habilitado con unidades legacy sin catalogoVenta',
    (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ElevatedButton botonSiguiente() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Siguiente'),
      );

      // Escenario: hay categoría y unidad legacy, pero el catálogo
      // proviene del preset (sin medidas pendientes de revisión).
      final provider = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        configuracionInicial: {
          'categorias': ['Bebidas'],
          'unidadesMedida': [
            {
              'nombre': 'Docena',
              'tipo': 'fraccionaria',
              'fraccionesPermitidas': <String>[],
              'esOpcional': true,
            },
          ],
        },
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Material(
              color: AppColors.fondo,
              child: ConfiguracionNegocioContent(
                uid: 'usuario-1',
                rubro: 'Bodega',
                onVolver: () {},
                onFinalizar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      provider.irAPaso(1);
      await tester.pumpAndSettle();

      expect(provider.categorias, isNotEmpty);
      expect(provider.unidadesMedida, isNotEmpty);
      expect(provider.medidasPendientesRevision, isEmpty);
      expect(botonSiguiente().onPressed, isNotNull);

      provider.cambiarCatalogoPestana(2);
      await tester.pumpAndSettle();
      expect(botonSiguiente().onPressed, isNotNull);

      // Escenario limpio: preset nuevo sin cambios.
      final providerLimpio = ConfiguracionNegocioProvider(
        rubro: 'Bodega',
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
      );
      addTearDown(providerLimpio.dispose);
      providerLimpio.agregarCategoria('Snacks');
      expect(providerLimpio.medidasPendientesRevision, isEmpty);

      await tester.pumpWidget(
        ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
          value: providerLimpio,
          child: MaterialApp(
            home: Material(
              color: AppColors.fondo,
              child: ConfiguracionNegocioContent(
                uid: 'usuario-1',
                rubro: 'Bodega',
                onVolver: () {},
                onFinalizar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      providerLimpio.irAPaso(1);
      await tester.pumpAndSettle();

      expect(providerLimpio.medidasPendientesRevision, isEmpty);
      expect(botonSiguiente().onPressed, isNotNull);
    },
  );

  // ── 6. Seis rubros: resumen consistente con cada preset ──────────────
  const seisRubros = [
    'Bodega',
    'Restaurante',
    'Ropa',
    'Accesorios y regalos',
    'Belleza y cuidado personal',
    'Otros',
  ];

  for (final rubro in seisRubros) {
    testWidgets('$rubro arma un resumen consistente con su preset', (
      tester,
    ) async {
      final provider = await mostrarPaso(tester, rubro: rubro);
      await verResumen(tester);

      expect(tester.takeException(), isNull);
      final catalogo = CatalogoVentaPersistido.desdePreset(
        PresetsVenta.obtener(rubro),
      );
      expect(
        provider.presentacionesActivas,
        catalogo.presentaciones.where((p) => p.activa).length,
      );
      expect(
        provider.medidasActivas,
        catalogo.medidas.where((m) => m.activa).length,
      );
      expect(
        provider.totalFormatos,
        catalogo.presentaciones.fold(0, (n, p) => n + p.formatos.length),
      );
      expect(
        provider.totalCantidadesRapidas,
        catalogo.medidas.fold(0, (n, m) => n + m.cantidadesRapidasBase.length),
      );
      expect(provider.medidasPendientesRevision, isEmpty);
      expect(provider.puedeAvanzarPaso1, isTrue);

      final formatosEsperados = catalogo.presentaciones.fold(
        0,
        (n, p) => n + p.formatos.length,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('resumen-formatos')),
          matching: find.text('$formatosEsperados'),
        ),
        findsOneWidget,
      );
    });
  }

  // ── 7. Guardado y relectura conservan el resumen ─────────────────────
  testWidgets('guardar y releer conserva el resumen del catálogo', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NegocioRepository(firestore: firestore);
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
      repository: repository,
    );
    addTearDown(provider.dispose);

    provider.nombreNegocio = 'Bodega Ana';
    provider.telefono = '999999999';
    provider.direccion = 'Av. Lima 123';
    provider.referencia = 'Frente al parque';
    provider.agregarCategoria('Ofertas');
    provider.agregarFormato('botella', volumen(100));

    final antes = (
      provider.categoriasActivas,
      provider.presentacionesActivas,
      provider.medidasActivas,
      provider.totalFormatos,
      provider.totalCantidadesRapidas,
    );

    expect(await provider.guardar('usuario-1'), isTrue);

    final doc = await firestore.collection('negocios').doc('negocio-1').get();
    expect(doc.exists, isTrue);
    final datos = doc.data()!;

    final releido = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
      repository: repository,
      configuracionInicial: {
        'categorias': datos['categorias'],
        'unidadesMedida': datos['unidadesMedida'],
        'catalogoVenta': datos['catalogoVenta'],
      },
    );
    addTearDown(releido.dispose);

    expect(releido.categoriasActivas, antes.$1);
    expect(releido.presentacionesActivas, antes.$2);
    expect(releido.medidasActivas, antes.$3);
    expect(releido.totalFormatos, antes.$4);
    expect(releido.totalCantidadesRapidas, antes.$5);
    expect(releido.medidasPendientesRevision, isEmpty);
  });

  // ── 8. Resumen responsive sin overflow ───────────────────────────────
  for (final ancho in [320.0, 360.0, 500.0, 768.0, 1140.0, 1366.0]) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets('resumen sin overflow a ${ancho}px con texto $escala', (
        tester,
      ) async {
        await mostrarPaso(
          tester,
          size: Size(ancho, 700),
          textScaler: TextScaler.linear(escala),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('seccion-resumen-catalogo')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('seccion-resumen-catalogo')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
