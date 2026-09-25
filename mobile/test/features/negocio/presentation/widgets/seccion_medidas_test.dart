import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ConfiguracionNegocioProvider(
      rubro: rubro,
      configuracionInicial: configuracionInicial,
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

  Future<void> irAMedidas(WidgetTester tester) async {
    await tester.tap(find.text('Medidas'));
    await tester.pumpAndSettle();
  }

  Future<void> irACategorias(WidgetTester tester) async {
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
  }

  Future<void> abrirEditorPeso(WidgetTester tester) async {
    await irAMedidas(tester);
    await tester.ensureVisible(find.byKey(const Key('editar-medida-peso')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-medida-peso')));
    await tester.pumpAndSettle();
  }

  Finder editor() => find.byKey(const Key('editor-medida'));

  // ── 1. Pestaña Medidas en el selector ──────────────────────────────────
  testWidgets('la pestaña Medidas existe y Categorías está activa al entrar', (
    tester,
  ) async {
    await mostrarPaso(tester);

    expect(find.byKey(const Key('pestana-medidas')), findsOneWidget);
    expect(
      tester
          .widget<Material>(find.byKey(const Key('pestana-categorias')))
          .color,
      AppColors.blue,
    );
    expect(
      tester.widget<Material>(find.byKey(const Key('pestana-medidas'))).color,
      Colors.transparent,
    );
  });

  // ── 2. Sección en Bodega ───────────────────────────────────────────────
  testWidgets('Bodega muestra Venta por medida con Peso y Volumen', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await irAMedidas(tester);

    expect(find.text('Venta por medida'), findsOneWidget);
    expect(find.text('2 activas'), findsOneWidget);
    expect(find.byKey(const Key('medida-card-peso')), findsOneWidget);
    expect(find.byKey(const Key('medida-card-volumen')), findsOneWidget);
    expect(provider.medidas.length, 2);
  });

  testWidgets('la tarjeta Peso detalla familia, unidades, números y pedidos', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await irAMedidas(tester);

    final tarjetaPeso = find.byKey(const Key('medida-card-peso'));
    expect(
      find.descendant(of: tarjetaPeso, matching: find.text('Peso')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tarjetaPeso, matching: find.text('Activa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tarjetaPeso, matching: find.text('Familia: Peso')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tarjetaPeso,
        matching: find.text('Unidad base: g  ·  Unidad habitual: kg'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tarjetaPeso,
        matching: find.text('Mínimo: 100 g  ·  Incremento: 50 g'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tarjetaPeso,
        matching: find.text('Cantidades rápidas: 1/4 kg, 1/2 kg, 3/4 kg, 1 kg'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tarjetaPeso,
        matching: find.text('Por cantidad: Sí  ·  Por soles: Sí'),
      ),
      findsOneWidget,
    );
  });

  // ── 3. Cambio de pestaña conserva estado ───────────────────────────────
  testWidgets('volver a Categorías conserva la pestaña seleccionada', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await irAMedidas(tester);
    await irACategorias(tester);

    expect(
      tester
          .widget<Material>(find.byKey(const Key('pestana-categorias')))
          .color,
      AppColors.blue,
    );
    expect(find.text('Categorías de productos'), findsOneWidget);
    expect(find.text('Venta por medida'), findsNothing);
  });

  // ── 3b. Medida con requiereRevision: se muestra, sin botón Editar ──────
  testWidgets(
    'una medida requiereRevision muestra el chip, guiones y sin Editar',
    (tester) async {
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
      await irAMedidas(tester);

      expect(tester.takeException(), isNull);

      final tarjeta = find.byKey(const Key('medida-card-docena'));
      expect(tarjeta, findsOneWidget);
      expect(
        find.descendant(of: tarjeta, matching: find.text('Requiere revisión')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.text('Familia: —')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.text('Unidad base: —  ·  Unidad habitual: —'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.text('Mínimo: —  ·  Incremento: —'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.text('Cantidades rápidas: —'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('editar-medida-docena')), findsNothing);
      expect(
        find.descendant(of: tarjeta, matching: find.text('Editar')),
        findsNothing,
      );
    },
  );

  // ── 3c. Longitud con cm: sin fracciones de referencia ──────────────────
  testWidgets('la familia Longitud con cm esconde el bloque de fracciones', (
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
              'id': 'longitud',
              'nombre': 'Longitud',
              'familia': 'longitud',
              'unidadBase': 'mm',
              'unidadVisual': 'm',
              'minimoBase': 500,
              'incrementoBase': 500,
              'cantidadesRapidasBase': [500, 1000, 1500, 2000],
              'permiteCantidad': true,
              'permiteMonto': true,
              'activa': true,
              'obligatoria': false,
              'requiereRevision': false,
            },
          ],
        },
        'delivery': false,
      },
    );
    await irAMedidas(tester);

    await tester.ensureVisible(find.byKey(const Key('editar-medida-longitud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-medida-longitud')));
    await tester.pumpAndSettle();

    expect(find.text('Editar Longitud'), findsOneWidget);
    expect(find.text('Rápida de referencia (m):'), findsOneWidget);
    expect(find.byKey(const Key('boton-fraccion-rapida-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('campo-unidad-medida')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cm').last);
    await tester.pumpAndSettle();

    expect(find.text('Rápida de referencia (cm):'), findsNothing);
    expect(find.byKey(const Key('boton-fraccion-rapida-1')), findsNothing);
    expect(find.byKey(const Key('boton-fraccion-rapida-2')), findsNothing);
    expect(find.byKey(const Key('boton-fraccion-rapida-3')), findsNothing);
    expect(find.byKey(const Key('boton-fraccion-rapida-4')), findsNothing);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 4. Editor: campos protegidos y preview ─────────────────────────────
  testWidgets('editar Peso bloquea nombre, familia y unidad base', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    expect(editor(), findsOneWidget);
    expect(find.text('Editar Peso'), findsOneWidget);
    expect(find.text('Medida del catálogo'), findsOneWidget);
    expect(find.text('Los nombres del catálogo son fijos.'), findsOneWidget);

    final campoNombre = tester.widget<TextField>(
      find.byKey(const Key('campo-nombre-medida')),
    );
    expect(campoNombre.enabled, isFalse);

    final campoFamilia = tester.widget<TextField>(
      find.byKey(const Key('campo-familia-medida')),
    );
    expect(campoFamilia.enabled, isFalse);
    expect(campoFamilia.controller!.text, 'Peso');

    final campoBase = tester.widget<TextField>(
      find.byKey(const Key('campo-unidadbase-medida')),
    );
    expect(campoBase.enabled, isFalse);
    expect(campoBase.controller!.text, 'g');

    expect(find.byKey(const Key('campo-unidad-medida')), findsOneWidget);
    expect(find.byKey(const Key('campo-familia-formato')), findsNothing);

    expect(find.text('Cómo lo verá el cliente'), findsOneWidget);
    expect(find.text('Mínimo: 100 g'), findsOneWidget);
    expect(find.text('Incremento: 50 g'), findsOneWidget);
    expect(
      find.text('Secuencia: 100 g, 150 g, 200 g, 250 g...'),
      findsOneWidget,
    );
    expect(
      find.text('Opciones rápidas: 1/4 kg, 1/2 kg, 3/4 kg, 1 kg'),
      findsOneWidget,
    );
    expect(find.text('Por cantidad: Sí'), findsOneWidget);
    expect(find.text('Por soles: Sí'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 5. Unidad habitual filtrada al dropdown de la familia ──────────────
  testWidgets('cambiar la unidad habitual actualiza etiquetas y guardado', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.tap(find.byKey(const Key('campo-unidad-medida')));
    await tester.pumpAndSettle();
    expect(find.text('ml'), findsNothing);

    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Opciones rápidas: 250 g, 500 g, 750 g, 1000 g'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();

    expect(provider.medidaDe(FamiliaUnidad.peso)!.unidadVisual!.nombre, 'g');
    expect(editor(), findsNothing);
  });

  // ── 6. Cantidad rápida custom (600 ml) ─────────────────────────────────
  testWidgets('agregar una cantidad rápida de 600 ml se mantiene en ml', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await irAMedidas(tester);

    await tester.ensureVisible(find.byKey(const Key('editar-medida-volumen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-medida-volumen')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('campo-unidad-rapida')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml').last);
    await tester.pumpAndSettle();

    // 600 ml respeta un incremento de 50 (el preset usa 250).
    await tester.enterText(
      find.byKey(const Key('campo-incremento-medida')),
      '50',
    );
    await tester.enterText(find.byKey(const Key('campo-valor-rapida')), '600');
    await tester.tap(find.byKey(const Key('boton-agregar-rapida')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rapida-existente-600')), findsOneWidget);
    expect(
      find.text('Opciones rápidas: 1/4 L, 1/2 L, 3/4 L, 1 L, 600 ml'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 7. Fracciones de la unidad de referencia ───────────────────────────
  testWidgets('los botones 1/4..1 agregan fracciones de la unidad referente', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await irAMedidas(tester);

    await tester.ensureVisible(find.byKey(const Key('editar-medida-volumen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-medida-volumen')));
    await tester.pumpAndSettle();

    expect(find.text('Rápida de referencia (L):'), findsOneWidget);
    expect(find.byKey(const Key('boton-fraccion-rapida-1')), findsOneWidget);
    expect(find.byKey(const Key('boton-fraccion-rapida-2')), findsOneWidget);
    expect(find.byKey(const Key('boton-fraccion-rapida-3')), findsOneWidget);
    expect(find.byKey(const Key('boton-fraccion-rapida-4')), findsOneWidget);

    await tester.tap(find.byKey(const Key('eliminar-rapida-750')));
    await tester.pump();
    expect(find.byKey(const Key('rapida-existente-750')), findsNothing);

    await tester.tap(find.byKey(const Key('boton-fraccion-rapida-3')));
    await tester.pump();
    expect(find.byKey(const Key('rapida-existente-750')), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 8. Guardar persiste en el proveedor y cierra ───────────────────────
  testWidgets('guardar mínimo 150 persiste en el catálogo', (tester) async {
    final provider = await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.enterText(find.byKey(const Key('campo-minimo-medida')), '150');
    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();

    expect(provider.medidaDe(provider.medidas[0].familia!)!.minimoBase, 150);
    expect(editor(), findsNothing);
    expect(find.byKey(const Key('medida-card-peso')), findsOneWidget);
  });

  // ── 9. Guardar no cierra Configuración ────────────────────────────────
  testWidgets('guardar un editor de medida no cierra Configuración', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
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

    await abrirEditorPeso(tester);
    expect(editor(), findsOneWidget);

    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();

    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
    expect(provider.pasoActual, 1);
    expect(editor(), findsNothing);
    expect(find.byKey(const Key('medida-card-peso')), findsOneWidget);
  });

  // ── 10. Cancelar conserva pestaña, valores y catálogo ──────────────────
  testWidgets('cancelar cierra el editor sin cambios y conserva la pestaña', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.enterText(find.byKey(const Key('campo-minimo-medida')), '150');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(editor(), findsNothing);
    expect(
      tester.widget<Material>(find.byKey(const Key('pestana-medidas'))).color,
      AppColors.blue,
    );
    expect(provider.medidaDe(provider.medidas[0].familia!)!.minimoBase, 100);
    expect(find.byKey(const Key('medida-card-peso')), findsOneWidget);
  });

  // ── 11. Validaciones numéricas ─────────────────────────────────────────
  testWidgets('mínimo vacío o cero bloquea el guardado', (tester) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.enterText(find.byKey(const Key('campo-minimo-medida')), '');
    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();

    expect(find.text('El mínimo debe ser un entero positivo.'), findsOneWidget);
    expect(editor(), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-minimo-medida')), '0');
    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();
    expect(find.text('El mínimo debe ser un entero positivo.'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('incremento menor o igual a cero bloquea el guardado', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.enterText(
      find.byKey(const Key('campo-incremento-medida')),
      '0',
    );
    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();

    expect(
      find.text('El incremento debe ser un entero positivo.'),
      findsOneWidget,
    );
    expect(editor(), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 12. Validación de formas de pedido ─────────────────────────────────
  testWidgets('apagar cantidad y soles bloquea con el mensaje del dominio', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.tap(find.byKey(const Key('switch-permitir-cantidad-medida')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('switch-permitir-monto-medida')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('guardar-editor-medida')));
    await tester.pumpAndSettle();

    expect(
      find.text('Debe permitir venta por cantidad o por monto (o ambas).'),
      findsOneWidget,
    );
    expect(editor(), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 13. Validación de cantidades rápidas ───────────────────────────────
  testWidgets(
    'rápidas menores, fuera del incremento o duplicadas se rechazan',
    (tester) async {
      await mostrarPaso(tester);
      await abrirEditorPeso(tester);

      // Unidad de la cantidad rápida en g para controlar el valor base.
      await tester.tap(find.byKey(const Key('campo-unidad-rapida')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('g').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campo-valor-rapida')), '50');
      await tester.tap(find.byKey(const Key('boton-agregar-rapida')));
      await tester.pump();
      expect(
        find.text('La cantidad rápida 50 es menor al mínimo 100.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('campo-valor-rapida')),
        '125',
      );
      await tester.tap(find.byKey(const Key('boton-agregar-rapida')));
      await tester.pump();
      expect(
        find.text(
          'La cantidad rápida 125 no respeta el incremento 50 a partir '
          'del mínimo.',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('campo-valor-rapida')),
        '250',
      );
      await tester.tap(find.byKey(const Key('boton-agregar-rapida')));
      await tester.pump();
      expect(
        find.text('La cantidad rápida 250 está duplicada.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('una cantidad rápida no entera se rechaza', (tester) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    await tester.enterText(find.byKey(const Key('campo-valor-rapida')), 'abc');
    await tester.tap(find.byKey(const Key('boton-agregar-rapida')));
    await tester.pump();

    expect(
      find.text('La cantidad rápida debe ser un entero positivo.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 14. Teclado numérico ───────────────────────────────────────────────
  testWidgets('los campos numéricos usan teclado numérico', (tester) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    for (final clave in [
      'campo-minimo-medida',
      'campo-incremento-medida',
      'campo-valor-rapida',
    ]) {
      final campo = tester.widget<TextField>(find.byKey(Key(clave)));
      expect(campo.keyboardType, TextInputType.number, reason: clave);
    }

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 15. Semántica accesible ────────────────────────────────────────────
  testWidgets('los conmutadores exponen etiqueta en semántica', (tester) async {
    await mostrarPaso(tester);
    await abrirEditorPeso(tester);

    final semCantidad = tester.getSemantics(
      find.byKey(const Key('switch-permitir-cantidad-medida')),
    );
    expect(semCantidad.label, contains('Permitir pedido por cantidad'));

    final semMonto = tester.getSemantics(
      find.byKey(const Key('switch-permitir-monto-medida')),
    );
    expect(semMonto.label, contains('Permitir pedido por soles'));

    final semActiva = tester.getSemantics(
      find.byKey(const Key('switch-activa-medida')),
    );
    expect(semActiva.label, contains('Activa'));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 16. Sección responsive: sin overflow ───────────────────────────────
  for (final ancho in [320.0, 500.0, 1720.0]) {
    for (final escala in [1.0, 2.0]) {
      testWidgets(
        'sección medidas sin overflow a $ancho px con texto $escala',
        (tester) async {
          await mostrarPaso(
            tester,
            size: Size(ancho, 2400),
            textScaler: TextScaler.linear(escala),
          );
          await irAMedidas(tester);

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('medida-card-peso')), findsOneWidget);
        },
      );
    }
  }

  // ── 17. Editor responsive: sin overflow ────────────────────────────────
  for (final ancho in [
    320.0,
    360.0,
    500.0,
    768.0,
    1050.0,
    1140.0,
    1366.0,
    1720.0,
  ]) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets(
        'editor de medida sin overflow a ${ancho}px con texto $escala',
        (tester) async {
          await mostrarPaso(
            tester,
            size: Size(ancho, 850),
            textScaler: TextScaler.linear(escala),
          );
          await abrirEditorPeso(tester);

          await tester.drag(find.byType(AlertDialog), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
