import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
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

  Future<void> irAUnidades(WidgetTester tester) async {
    await tester.tap(find.text('Unidades de venta'));
    await tester.pumpAndSettle();
  }

  Finder editor() => find.byKey(const Key('editor-presentacion'));

  // ── 1. Sección en Bodega ───────────────────────────────────────────────
  testWidgets('Bodega muestra obligatorias sin opciones ni nueva', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await irAUnidades(tester);

    expect(find.text('Unidad o presentación'), findsOneWidget);
    expect(find.text('Obligatorias'), findsOneWidget);
    expect(find.text('Más opciones'), findsNothing);
    expect(find.text('Presentaciones personalizadas'), findsNothing);
    expect(find.byKey(const Key('boton-nueva-presentacion')), findsNothing);
    expect(find.text('6 activas'), findsOneWidget);
    expect(find.byKey(const Key('presentacion-card-unidad')), findsOneWidget);
    expect(find.byKey(const Key('presentacion-card-botella')), findsOneWidget);
    expect(find.byKey(const Key('presentacion-card-par')), findsNothing);
  });

  // ── 2. Sección en Otros ────────────────────────────────────────────────
  testWidgets('Otros muestra Más opciones y permite crear presentaciones', (
    tester,
  ) async {
    await mostrarPaso(tester, rubro: 'Otros');
    await irAUnidades(tester);

    expect(find.text('Más opciones'), findsOneWidget);
    expect(find.text('Obligatorias'), findsOneWidget);
    expect(find.byKey(const Key('presentacion-card-par')), findsOneWidget);
    expect(find.byKey(const Key('boton-nueva-presentacion')), findsOneWidget);
  });

  // ── 3. Editor: nombre fijo y switch bloqueado en obligatoria ───────────
  testWidgets('editar una presentación del catálogo bloquea nombre y switch', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();

    expect(editor(), findsOneWidget);
    expect(find.text('Editar Botella'), findsOneWidget);
    expect(find.text('Nombre del catálogo'), findsOneWidget);
    expect(find.text('Los nombres del catálogo son fijos.'), findsOneWidget);
    final campoNombre = tester.widget<TextField>(
      find.byKey(const Key('campo-nombre-presentacion')),
    );
    expect(campoNombre.enabled, isFalse);

    final switchObligatoria = tester.widget<SwitchListTile>(
      find.byKey(const Key('switch-activa-presentacion')),
    );
    expect(switchObligatoria.value, isTrue);
    expect(switchObligatoria.onChanged, isNull);
    expect(find.text('Obligatoria (siempre activa)'), findsOneWidget);

    expect(find.byKey(const Key('campo-familia-formato')), findsNothing);

    expect(find.text('Cómo lo verá el cliente'), findsOneWidget);
    expect(find.text('Botella 3 L'), findsOneWidget);
    expect(find.text('Se vende completa.'), findsOneWidget);
    expect(find.text('El contenido no se descontará en ml.'), findsOneWidget);
    expect(provider.presentaciones.length, 6);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 4. Agregar formato permitido ───────────────────────────────────────
  testWidgets('agregar un formato lo refleja en lista, preview y guardado', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campo-valor-formato')), '750');
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(find.text('750 ml'), findsOneWidget);
    expect(find.text('Botella 750 ml'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campo-valor-formato')))
          .controller!
          .text,
      isEmpty,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(editor(), findsNothing);
    final botella = provider.presentacionPorId('botella')!;
    expect(botella.formatos.any((f) => f.valorBase == 750), isTrue);
    expect(botella.formatos.length, 10);
  });

  // ── 4b. Ejemplo literal del prompt: Botella 650 ml ─────────────────────
  testWidgets('la previsualización muestra el literal "Botella 650 ml"', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    expect(editor(), findsOneWidget);
    expect(find.text('Botella 3 L'), findsOneWidget);

    for (final etiqueta in ['3 L', '2 1/2 L', '2 L', '1 1/2 L', '1 L']) {
      await tester.tap(find.byKey(Key('eliminar-formato-$etiqueta')));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('formato-existente-650 ml')), findsOneWidget);
    expect(find.byKey(const Key('formato-existente-1 L')), findsNothing);
    expect(find.text('Botella 650 ml'), findsOneWidget);
    expect(find.text('Se vende completa.'), findsOneWidget);
    expect(find.text('El contenido no se descontará en ml.'), findsOneWidget);
    expect(provider.presentacionPorId('botella')!.formatos.length, 9);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 5-7. Validaciones del valor ────────────────────────────────────────
  testWidgets('bloquea agregar formato con valor vacío', (tester) async {
    await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe el valor del formato como número entero.'),
      findsOneWidget,
    );
    expect(editor(), findsOneWidget);
  });

  testWidgets('bloquea valor cero', (tester) async {
    await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor-formato')), '0');
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(find.text('El valor debe ser un entero positivo.'), findsOneWidget);
    expect(editor(), findsOneWidget);
  });

  testWidgets('bloquea valor negativo', (tester) async {
    await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor-formato')), '-5');
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(find.text('El valor debe ser un entero positivo.'), findsOneWidget);
    expect(editor(), findsOneWidget);
  });

  // ── 8-9. Duplicados normalizados ───────────────────────────────────────
  testWidgets('bloquea un formato duplicado normalizado (625 ml)', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor-formato')), '625');
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(find.text('625 ml ya es un formato de Botella.'), findsOneWidget);
    expect(provider.presentacionPorId('botella')!.formatos.length, 9);
    expect(editor(), findsOneWidget);
  });

  testWidgets('bloquea 1000 ml como duplicado de 1 L', (tester) async {
    final provider = await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-valor-formato')),
      '1000',
    );
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(find.text('1000 ml ya es un formato de Botella.'), findsOneWidget);
    expect(provider.presentacionPorId('botella')!.formatos.length, 9);
    expect(editor(), findsOneWidget);
  });

  // ── 10. Cancelar conserva la pestaña y el catálogo ─────────────────────
  testWidgets('cancelar cierra el editor sin cambios y conserva la pestaña', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    expect(editor(), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(editor(), findsNothing);
    expect(
      tester.widget<Material>(find.byKey(const Key('pestana-unidades'))).color,
      AppColors.blue,
    );
    expect(provider.presentacionPorId('botella')!.formatos.length, 9);
    expect(find.text('Botella'), findsOneWidget);
  });

  // ── 11. Guardar no cierra Configuración ────────────────────────────────
  testWidgets('guardar un editor no cierra Configuración', (tester) async {
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

    await tester.tap(find.text('Unidades de venta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('editar-presentacion-botella')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
    await tester.pumpAndSettle();
    expect(editor(), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
    expect(provider.pasoActual, 1);
    expect(editor(), findsNothing);
    expect(find.byKey(const Key('presentacion-card-botella')), findsOneWidget);
  });

  // ── 12. Crear presentación personalizada ───────────────────────────────
  testWidgets('crear y renombrar una presentación personalizada', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester, rubro: 'Otros');
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('boton-nueva-presentacion')));
    await tester.pumpAndSettle();
    expect(editor(), findsOneWidget);
    expect(find.text('Nueva presentación'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-nombre-presentacion')),
      'Canasto',
    );
    await tester.enterText(find.byKey(const Key('campo-valor-formato')), '10');
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();

    expect(find.text('10 unidad'), findsOneWidget);
    expect(find.text('Canasto 10 unidad'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    final creada = provider.presentacionPorId('personalizada-1')!;
    expect(creada.personalizada, isTrue);
    expect(creada.nombre, 'Canasto');
    expect(creada.activa, isTrue);
    expect(creada.formatos.single.valorBase, 10);
    expect(
      find.byKey(const Key('presentacion-card-personalizada-1')),
      findsOneWidget,
    );
    expect(find.text('Presentaciones personalizadas'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('editar-presentacion-personalizada-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-presentacion')),
      'Canasto grande',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      provider.presentacionPorId('personalizada-1')!.nombre,
      'Canasto grande',
    );
    expect(find.text('Canasto grande'), findsOneWidget);
  });

  // ── 13. Nombre duplicado y V vacío al crear ────────────────────────────
  testWidgets('bloquea crear con nombre vacío o nombre duplicado', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester, rubro: 'Otros');
    provider.agregarPresentacionPersonalizada(
      nombre: 'Canasto',
      formatos: [
        FormatoPresentacion(
          valorBase: 10,
          familia: FamiliaUnidad.conteo,
          unidadVisible: RegistroUnidades.unidad,
        ),
      ],
    );
    await tester.pump();
    await irAUnidades(tester);

    await tester.tap(find.byKey(const Key('boton-nueva-presentacion')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-valor-formato')), '5');
    await tester.tap(find.byKey(const Key('boton-agregar-formato')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El nombre de la presentación no puede estar vacío.'),
      findsOneWidget,
    );
    expect(editor(), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-nombre-presentacion')),
      'canasto ',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe una presentación con ese nombre.'),
      findsOneWidget,
    );
    expect(editor(), findsOneWidget);
    expect(provider.presentaciones.length, 7);
  });

  // ── 14. Activar/desactivar una opcional ────────────────────────────────
  testWidgets('activar y desactivar una presentación opcional', (tester) async {
    final provider = await mostrarPaso(tester, rubro: 'Otros');
    await irAUnidades(tester);

    expect(provider.presentacionActiva('par'), isFalse);

    await tester.tap(find.byKey(const Key('editar-presentacion-par')));
    await tester.pumpAndSettle();

    var switchPar = tester.widget<SwitchListTile>(
      find.byKey(const Key('switch-activa-presentacion')),
    );
    expect(switchPar.value, isFalse);
    expect(
      find.descendant(of: editor(), matching: find.text('Inactiva')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('switch-activa-presentacion')));
    await tester.pump();
    switchPar = tester.widget<SwitchListTile>(
      find.byKey(const Key('switch-activa-presentacion')),
    );
    expect(switchPar.value, isTrue);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(provider.presentacionActiva('par'), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('presentacion-card-par')),
        matching: find.text('Activa'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('editar-presentacion-par')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-activa-presentacion')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(provider.presentacionActiva('par'), isFalse);
    expect(
      find.descendant(
        of: find.byKey(const Key('presentacion-card-par')),
        matching: find.text('Inactiva'),
      ),
      findsOneWidget,
    );
  });

  // ── 15. Editor responsive: sin overflow ────────────────────────────────
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
      testWidgets('editor sin overflow a ${ancho}px con texto $escala', (
        tester,
      ) async {
        await mostrarPaso(
          tester,
          size: Size(ancho, 850),
          textScaler: TextScaler.linear(escala),
        );
        await irAUnidades(tester);

        await tester.ensureVisible(
          find.byKey(const Key('editar-presentacion-botella')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('editar-presentacion-botella')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(AlertDialog), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
