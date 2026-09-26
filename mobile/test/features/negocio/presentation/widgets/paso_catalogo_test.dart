import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
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

  /// Estado visible de una tarjeta: 'Activa' o 'Inactiva'.
  Finder estadoTarjeta(String tarjeta, String estado) => find.descendant(
    of: find.byKey(Key('categoria-card-$tarjeta')),
    matching: find.text(estado),
  );

  Finder finderDialogo() => find.byType(AlertDialog);

  /// Siembra `categoriasPersonalizadas` por el mismo camino que usa la app al
  /// abrir la configuración, sin esperar escrituras.
  Map<String, dynamic> seedPersonalizadas(
    Map<String, ({bool activa})> porClave,
  ) => {
    'categoriasPersonalizadas': [
      for (final entrada in porClave.entries)
        {
          'clave': entrada.key,
          'nombre': entrada.key[0].toUpperCase() + entrada.key.substring(1),
          'activa': entrada.value.activa,
        },
    ],
  };

  /// Mapa de la colección de una personalizada, para leer lo persistido.
  Future<List<Map<String, dynamic>>> personalizadasGuardadas(
    FakeFirebaseFirestore db,
  ) async {
    final datos = (await db.collection('negocios').doc('negocio-1').get()).data();
    return (datos?['categoriasPersonalizadas'] as List)
        .cast<Map<String, dynamic>>();
  }

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
    final provider = await mostrarPaso(
      tester,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

    await irAUnidades(tester);
    expect(find.text('Unidad o presentación'), findsOneWidget);
    expect(find.text('Categorías de productos'), findsNothing);

    await irACategorias(tester);
    expect(find.text('Categorías de productos'), findsOneWidget);
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsOneWidget);
    expect(
      provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
      contains('ofertas'),
    );
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

  // ── 6. Crear categoría personalizada ────────────────────────────────────
  testWidgets('crear una categoría personalizada la persiste y la muestra activa', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await mostrarPaso(tester, negocioId: 'negocio-1', firestore: db);

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
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsOneWidget);
    expect(estadoTarjeta('Ofertas', 'Activa'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('categoria-card-Ofertas')),
        matching: find.text('Personalizada'),
      ),
      findsOneWidget,
    );
    // La alta va a `categoriasPersonalizadas`, no al borrador legacy: la UI ya
    // no depende de que `_categorias` conozca el nombre.
    expect(
      (await personalizadasGuardadas(db)).map((c) => c['clave']),
      contains('ofertas'),
    );
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
    expect(provider.categoriasPersonalizadas, isEmpty);
    expect(find.byKey(const Key('categoria-card-Temporal')), findsNothing);
  });

  // ── 8. Bloquear duplicado del preset ────────────────────────────────────
  testWidgets('bloquea un nombre que ya es del preset y conserva el texto', (
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
      find.text('Ese nombre ya es una categoría sugerida de Bodega.'),
      findsOneWidget,
    );
    expect(find.textContaining('Bébidas'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 8b. Bloquear duplicado de otra personalizada ────────────────────────
  testWidgets('bloquea un nombre que ya es de otra personalizada', (
    tester,
  ) async {
    await mostrarPaso(
      tester,
      configuracionInicial: seedPersonalizadas({
        'dulces': (activa: true),
      }),
    );

    await tester.tap(find.text('+ Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-nombre-categoria')),
      '  Dulces ',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsOneWidget);
    expect(
      find.text('Ya existe una categoría con ese nombre.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  // ── 9. Editar personalizada conserva la clave ──────────────────────────
  testWidgets('editar una personalizada cambia la etiqueta y conserva la clave', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final provider = await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      firestore: db,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

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

    final customizing = provider.categoriasPersonalizadas.single;
    expect(customizing.clave, 'ofertas');
    expect(customizing.nombre, 'Promociones');
    expect(customizing.activa, isTrue);
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsNothing);
    expect(find.byKey(const Key('categoria-card-Promociones')), findsOneWidget);
    expect(
      (await personalizadasGuardadas(db)).single['clave'],
      'ofertas',
      reason: 'la clave es la identidad y no se recalcula al renombrar',
    );
  });

  // ── 10. Eliminar personalizada con confirmación ─────────────────────────
  testWidgets('eliminar personalizada exige confirmación', (tester) async {
    final db = FakeFirebaseFirestore();
    final provider = await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      firestore: db,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

    await tester.ensureVisible(find.byKey(const Key('categoria-card-Ofertas')));
    await tester.tap(accionTarjeta('Eliminar', 'Ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Ofertas?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
      contains('ofertas'),
    );

    await tester.tap(accionTarjeta('Eliminar', 'Ofertas'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: finderDialogo(), matching: find.text('Eliminar')),
    );
    await tester.pumpAndSettle();

    expect(provider.categoriasPersonalizadas, isEmpty);
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsNothing);
    expect(await personalizadasGuardadas(db), isEmpty);
  });

  // ── 10b. Desactivar y reactivar una personalizada ───────────────────────
  testWidgets('desactivar una personalizada la conserva y se puede reactivar', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final provider = await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      firestore: db,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

    await tester.ensureVisible(find.byKey(const Key('categoria-card-Ofertas')));
    expect(estadoTarjeta('Ofertas', 'Activa'), findsOneWidget);

    await tester.tap(accionTarjeta('Desactivar', 'Ofertas'));
    await tester.pumpAndSettle();

    // Desactivar NO es eliminar: sigue en la lista, con `activa: false`.
    expect(find.byKey(const Key('categoria-card-Ofertas')), findsOneWidget);
    expect(estadoTarjeta('Ofertas', 'Inactiva'), findsOneWidget);
    expect(estadoTarjeta('Ofertas', 'Activa'), findsNothing);
    expect(provider.categoriasPersonalizadas.single.activa, isFalse);
    expect(
      (await personalizadasGuardadas(db)).single['activa'],
      isFalse,
    );

    await tester.tap(accionTarjeta('Activar', 'Ofertas'));
    await tester.pumpAndSettle();

    expect(estadoTarjeta('Ofertas', 'Activa'), findsOneWidget);
    expect(provider.categoriasPersonalizadas.single.activa, isTrue);
  });

  // ── 11. Preset: solo el interruptor, nunca Editar/Eliminar ─────────────
  testWidgets('una categoría sugerida no ofrece Editar ni Eliminar', (
    tester,
  ) async {
    await mostrarPaso(tester);

    final tarjeta = find.byKey(const Key('categoria-card-Abarrotes'));
    final sugeridas = PresetsVenta.obtener('Bodega').categorias.length;
    expect(find.text('Sugerida para Bodega'), findsNWidgets(sugeridas));
    expect(accionTarjeta('Desactivar', 'Abarrotes'), findsOneWidget);
    expect(find.text('Activa'), findsNWidgets(sugeridas));
    expect(
      find.descendant(of: tarjeta, matching: find.text('Editar')),
      findsNothing,
    );
    expect(
      find.descendant(of: tarjeta, matching: find.text('Eliminar')),
      findsNothing,
    );
  });

  // ── 12. Desactivar y reactivar una categoría del preset ─────────────────
  testWidgets('desactivar una del preset la oculta sin borrarla del catálogo', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final provider = await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      firestore: db,
    );
    final sugeridas = PresetsVenta.obtener('Bodega').categorias;

    // El estado sale de `categoriasDesactivadas`, no de comparar strings.
    expect(provider.categoriaPresetDesactivada('Snacks'), isFalse);
    expect(estadoTarjeta('Snacks', 'Activa'), findsOneWidget);

    await tester.tap(accionTarjeta('Desactivar', 'Snacks'));
    await tester.pumpAndSettle();

    expect(provider.categoriaPresetDesactivada('Snacks'), isTrue);
    expect(provider.categoriasDesactivadas, contains('snacks'));
    expect(estadoTarjeta('Snacks', 'Inactiva'), findsOneWidget);
    expect(estadoTarjeta('Snacks', 'Activa'), findsNothing);
    // Oculta, no borra: el preset sigue íntegro.
    expect(PresetsVenta.obtener('Bodega').categorias, sugeridas);
    expect(find.text('Sugerida para Bodega'), findsNWidgets(sugeridas.length));
    expect(
      (await db.collection('negocios').doc('negocio-1').get()).data()?[
        'categoriasDesactivadas'
      ],
      contains('snacks'),
    );

    await tester.tap(accionTarjeta('Activar', 'Snacks'));
    await tester.pumpAndSettle();

    expect(provider.categoriaPresetDesactivada('Snacks'), isFalse);
    expect(provider.categoriasDesactivadas, isEmpty);
    expect(estadoTarjeta('Snacks', 'Activa'), findsOneWidget);
  });

  // ── 12b. El estado de una del preset sobrevive a la recarga ─────────────
  testWidgets('el estado del preset se restaura desde categoriasDesactivadas', (
    tester,
  ) async {
    final provider = await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      configuracionInicial: {'categoriasDesactivadas': ['snacks']},
    );

    expect(estadoTarjeta('Snacks', 'Inactiva'), findsOneWidget);
    expect(estadoTarjeta('Abarrotes', 'Activa'), findsOneWidget);
    expect(provider.categoriaPresetDesactivada('  SnaCKS '), isTrue);
  });

  // ── 13. Una personalizada no se confunde con una del preset ─────────────
  testWidgets('una personalizada con nombre propio no se marca como sugerida', (
    tester,
  ) async {
    await mostrarPaso(
      tester,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

    // Mismo origen, subtítulos distintos: el preset nunca se infiere por
    // comparación de nombres.
    expect(
      find.descendant(
        of: find.byKey(const Key('categoria-card-Ofertas')),
        matching: find.text('Personalizada'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('categoria-card-Ofertas')),
        matching: find.textContaining('Sugerida'),
      ),
      findsNothing,
    );
    // Y las acciones difieren por origen: el preset solo se activa/desactiva,
    // la personalizada además se renombra y se elimina.
    expect(accionTarjeta('Desactivar', 'Abarrotes'), findsOneWidget);
    expect(accionTarjeta('Eliminar', 'Ofertas'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('categoria-card-Abarrotes')),
        matching: find.text('Eliminar'),
      ),
      findsNothing,
    );
  });

  // ── 14. Bloquear categoría usada por productos ──────────────────────────
  testWidgets('la última categoría efectiva avisa y no se desactiva', (
    tester,
  ) async {
    await mostrarPaso(
      tester,
      negocioId: 'negocio-1',
      configuracionInicial: {
        'categoriasDesactivadas': [
          'bebidas',
          'snacks',
          'limpieza',
          'cuidado personal',
        ],
      },
    );

    await tester.tap(accionTarjeta('Desactivar', 'Abarrotes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Debes mantener al menos una categoría activa.'),
      findsOneWidget,
    );
    // El estado no cambia: sigue activa y el preset no registra la clave.
    expect(estadoTarjeta('Abarrotes', 'Activa'), findsOneWidget);
    expect(estadoTarjeta('Abarrotes', 'Inactiva'), findsNothing);

    await expulsarSnackBar(tester);
  });

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
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

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
    expect(
      provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
      contains('ofertas'),
    );
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
    expect(
      provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
      contains('ofertas'),
    );
    await expulsarSnackBar(tester);
  });

  // ── 15. Guardar diálogo no cierra Configuración ────────────────────────
  testWidgets('guardar categoría no cierra Configuración', (tester) async {
    tester.view.physicalSize = const Size(500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ConfiguracionNegocioProvider(
      rubro: 'Bodega',
      negocioId: 'negocio-1',
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
    expect(
      provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
      contains('frutos secos'),
    );
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
