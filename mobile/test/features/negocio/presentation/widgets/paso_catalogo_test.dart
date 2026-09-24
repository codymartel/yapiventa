import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/paso_catalogo.dart';
import 'package:provider/provider.dart';

void main() {
  Future<ConfiguracionNegocioProvider> mostrarPaso(
    WidgetTester tester, {
    String rubro = 'Bodega',
    String? negocioId,
    FakeFirebaseFirestore? firestore,
    Map<String, dynamic>? configuracionInicial,
    Size size = const Size(900, 2400),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = firestore ?? FakeFirebaseFirestore();
    final provider = ConfiguracionNegocioProvider(
      rubro: rubro,
      negocioId: negocioId,
      configuracionInicial: configuracionInicial,
      repository: NegocioRepository(firestore: db),
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

  Future<void> irACategorias(WidgetTester tester) async {
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
  }

  Future<void> expulsarSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Future<void> subirAlInicio(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, 10000));
    await tester.pumpAndSettle();
  }

  Finder accionTarjeta(String etiqueta, String tarjeta) => find.descendant(
    of: find.byKey(Key('categoria-card-$tarjeta')),
    matching: find.text(etiqueta),
  );

  Finder finderDialogo() => find.byType(AlertDialog);

  // ── 1. Render de las dos pestañas ──────────────────────────────────────
  testWidgets('renderiza las dos pestañas: Categorías y Unidades de venta', (
    tester,
  ) async {
    await mostrarPaso(tester);

    expect(find.byKey(const Key('pestana-categorias')), findsOneWidget);
    expect(find.byKey(const Key('pestana-unidades')), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Unidades de venta'), findsOneWidget);
  });

  // ── 2. Categorías activa inicialmente ──────────────────────────────────
  testWidgets('Categorías está activa al entrar al paso', (tester) async {
    await mostrarPaso(tester);

    expect(
      tester
          .widget<Material>(find.byKey(const Key('pestana-categorias')))
          .color,
      AppColors.blue,
    );
    expect(
      tester.widget<Material>(find.byKey(const Key('pestana-unidades'))).color,
      Colors.transparent,
    );
    expect(find.text('Categorías de productos'), findsOneWidget);
    expect(find.text('Unidades de medida'), findsNothing);
  });

  // ── 3. Cambio a Unidades conserva estado ───────────────────────────────
  testWidgets('cambiar a Unidades y volver conserva las categorías', (
    tester,
  ) async {
    final provider = await mostrarPaso(tester);
    provider.agregarCategoria('Ofertas');
    await tester.pump();

    await irAUnidades(tester);
    expect(find.text('Unidades de medida'), findsOneWidget);
    expect(find.text('Categorías de productos'), findsNothing);

    await irACategorias(tester);
    expect(find.text('Categorías de productos'), findsOneWidget);
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsOneWidget);
    expect(provider.categorias, contains('Ofertas'));
  });

  // ── 4. Grid de dos columnas en escritorio ──────────────────────────────
  testWidgets('grid de dos columnas en escritorio', (tester) async {
    await mostrarPaso(tester, size: const Size(900, 2400));

    final izquierda = tester.getTopLeft(
      find.byKey(const Key('categoria-card-Abarrotes')),
    );
    final derecha = tester.getTopLeft(
      find.byKey(const Key('categoria-card-Bebidas')),
    );

    expect(izquierda.dy, derecha.dy);
    expect(derecha.dx, greaterThan(izquierda.dx));
    final anchoIzq = tester
        .getSize(find.byKey(const Key('categoria-card-Abarrotes')))
        .width;
    final anchoDer = tester
        .getSize(find.byKey(const Key('categoria-card-Bebidas')))
        .width;
    expect(anchoIzq, closeTo(424, 1));
    expect(anchoDer, closeTo(424, 1));
  });

  // ── 5. Una columna en móvil ────────────────────────────────────────────
  testWidgets('una sola columna en móvil', (tester) async {
    await mostrarPaso(tester, size: const Size(360, 900));

    final abarrotes = tester.getTopLeft(
      find.byKey(const Key('categoria-card-Abarrotes')),
    );
    final bebidas = tester.getTopLeft(
      find.byKey(const Key('categoria-card-Bebidas')),
    );

    expect(abarrotes.dx, bebidas.dx);
    expect(
      tester.getSize(find.byKey(const Key('categoria-card-Abarrotes'))).width,
      closeTo(320, 1),
    );
  });

  // ── 6. Crear categoría ─────────────────────────────────────────────────
  testWidgets('crear una categoría personalizada', (tester) async {
    final provider = await mostrarPaso(tester);

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva categoría'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      'Ofertas',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsNothing);
    expect(provider.categorias, contains('Ofertas'));
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsOneWidget);
  });

  // ── 7. Cancelar sin crear ──────────────────────────────────────────────
  testWidgets('cancelar cierra el diálogo sin crear', (tester) async {
    final provider = await mostrarPaso(tester);

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      'Temporal',
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsNothing);
    expect(provider.categorias, isNot(contains('Temporal')));
    expect(find.byKey(const Key('categoria-card-Temporal')), findsNothing);
  });

  // ── 8. Bloquear duplicado normalizado ──────────────────────────────────
  testWidgets('bloquea nombres duplicados normalizados y conserva el texto', (
    tester,
  ) async {
    await mostrarPaso(tester);

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      'Bébidas ',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsOneWidget);
    expect(
      find.text('Ya existe una categoría con ese nombre.'),
      findsOneWidget,
    );
    expect(find.textContaining('Bébidas'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 9. Editar personalizada ────────────────────────────────────────────
  testWidgets('editar una categoría personalizada', (tester) async {
    final provider = await mostrarPaso(tester);
    provider.agregarCategoria('Ofertas');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('categoria-card-Ofertas')));
    await tester.tap(accionTarjeta('Editar', 'Ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoría'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      'Promociones',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(provider.categorias, contains('Promociones'));
    expect(provider.categorias, isNot(contains('Ofertas')));
    expect(find.byKey(const Key('categoria-card-Promociones')), findsOneWidget);
  });

  // ── 10. Eliminar personalizada con confirmación ────────────────────────
  testWidgets('eliminar personalizada exige confirmación', (tester) async {
    final provider = await mostrarPaso(tester);
    provider.agregarCategoria('Ofertas');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('categoria-card-Ofertas')));
    await tester.tap(accionTarjeta('Eliminar', 'Ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Ofertas?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(provider.categorias, contains('Ofertas'));

    await tester.tap(accionTarjeta('Eliminar', 'Ofertas'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: finderDialogo(), matching: find.text('Eliminar')),
    );
    await tester.pumpAndSettle();

    expect(provider.categorias, isNot(contains('Ofertas')));
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsNothing);
  });

  // ── 11. Preset sin Editar/Eliminar ─────────────────────────────────────
  testWidgets('una categoría sugerida no ofrece Editar ni Eliminar', (
    tester,
  ) async {
    await mostrarPaso(tester);

    final tarjeta = find.byKey(const Key('categoria-card-Abarrotes'));
    expect(find.text('Sugerida para Bodega'), findsNWidgets(6));
    expect(accionTarjeta('Desactivar', 'Abarrotes'), findsOneWidget);
    expect(find.text('Activa'), findsNWidgets(6));
    expect(
      find.descendant(of: tarjeta, matching: find.text('Editar')),
      findsNothing,
    );
    expect(
      find.descendant(of: tarjeta, matching: find.text('Eliminar')),
      findsNothing,
    );
  });

  // ── 12. Bloquear última categoría ──────────────────────────────────────
  testWidgets('no permite desactivar la última categoría activa', (
    tester,
  ) async {
    final provider = await mostrarPaso(
      tester,
      configuracionInicial: {
        'categorias': ['Abarrotes'],
      },
    );

    await tester.tap(accionTarjeta('Desactivar', 'Abarrotes'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No puedes desactivar todas las categorías. Mantén al menos una activa.',
      ),
      findsOneWidget,
    );
    expect(provider.categorias, ['Abarrotes']);
    expect(provider.categoriaActiva('Abarrotes'), isTrue);

    await expulsarSnackBar(tester);
  });

  // ── 13. Bloquear categoría usada por productos ─────────────────────────
  testWidgets('bloquea eliminar y editar una categoría usada por productos', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('negocios')
        .doc('negocio-1')
        .collection('productos')
        .doc('producto-1')
        .set({'categoria': 'Ofertas'});
    final provider = await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      firestore: firestore,
    );
    provider.agregarCategoria('Ofertas');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('categoria-card-Ofertas')));
    await tester.tap(accionTarjeta('Eliminar', 'Ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Ofertas?'), findsNothing);
    expect(
      find.text(
        'Esta categoría está siendo usada por productos. '
        'Cambia primero esos productos a otra categoría.',
      ),
      findsOneWidget,
    );
    expect(provider.categorias, contains('Ofertas'));
    await expulsarSnackBar(tester);

    await tester.tap(accionTarjeta('Editar', 'Ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoría'), findsNothing);
    expect(
      find.text(
        'Esta categoría está siendo usada por productos. '
        'Cambia primero esos productos a otra categoría.',
      ),
      findsOneWidget,
    );
    expect(provider.categorias, contains('Ofertas'));
    await expulsarSnackBar(tester);
  });

  // ── 14. Guardar diálogo no cierra Configuración ────────────────────────
  testWidgets('guardar categoría no cierra Configuración', (tester) async {
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

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      'Frutos secos',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
    expect(provider.pasoActual, 1);
    expect(provider.categorias, contains('Frutos secos'));
  });

  // ── 15. Cero escrituras Firestore al cambiar pestañas ──────────────────
  testWidgets('cambiar de pestaña no escribe en Firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final provider = await mostrarPaso(tester, firestore: firestore);
    final categoriasIniciales = provider.categorias;

    await irAUnidades(tester);
    await irACategorias(tester);
    await irAUnidades(tester);
    await irACategorias(tester);

    final negocios = await firestore.collection('negocios').get();
    final usuarios = await firestore.collection('users').get();
    expect(negocios.docs, isEmpty);
    expect(usuarios.docs, isEmpty);
    expect(provider.categorias, categoriasIniciales);
  });

  // ── Contenido anterior de Unidades ─────────────────────────────────────
  testWidgets('muestra cantidades comerciales sin decimales técnicos', (
    tester,
  ) async {
    await mostrarPaso(tester);
    await irAUnidades(tester);

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
    await irAUnidades(tester);

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

  // ── Validaciones extra del diálogo ─────────────────────────────────────
  testWidgets('rechaza nombres de menos de 2 caracteres', (tester) async {
    await mostrarPaso(tester);

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      'a',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsOneWidget);
    expect(
      find.text('El nombre debe tener al menos 2 caracteres.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('rechaza nombres formados solo por símbolos', (tester) async {
    await mostrarPaso(tester);

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      '@@@',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsOneWidget);
    expect(
      find.text('El nombre debe incluir letras o números.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── Matriz responsive: sin overflow, botón visible, tabs conservan ─────
  for (final ancho in [360.0, 500.0, 768.0, 1050.0, 1440.0]) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets('sin overflow a ${ancho}px con texto $escala', (
        tester,
      ) async {
        await mostrarPaso(
          tester,
          size: Size(ancho, 900),
          textScaler: TextScaler.linear(escala),
        );

        expect(find.text('+ Nueva categoría'), findsOneWidget);
        expect(find.text('Categorías'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await subirAlInicio(tester);
        await irAUnidades(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await subirAlInicio(tester);
        await irACategorias(tester);
        expect(
          find.byKey(const Key('categoria-card-Abarrotes')),
          findsOneWidget,
        );
        expect(find.text('+ Nueva categoría'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
