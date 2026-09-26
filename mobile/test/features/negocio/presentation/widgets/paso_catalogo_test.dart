import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/domain/models/categoria_personalizada.dart';
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
    NegocioRepository? repositorio,
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
      repository: repositorio ?? NegocioRepository(firestore: db),
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

  /// El botón `Editar` vive dentro de la tarjeta de una propia.
  Finder accionTarjetaPropia(String clave) => find.descendant(
    of: find.byKey(Key('categoria-propia-$clave')),
    matching: find.text('Editar'),
  );

  /// Estado visible de una tarjeta: 'Activa' o 'Inactiva'.
  Finder estadoTarjeta(String tarjeta, String estado) => find.descendant(
    of: find.byKey(Key('categoria-card-$tarjeta')),
    matching: find.text(estado),
  );

  /// Igual que [estadoTarjeta], pero para una propia: se identifica por clave.
  Finder estadoPropia(String clave, String estado) => find.descendant(
    of: find.byKey(Key('categoria-propia-$clave')),
    matching: find.text(estado),
  );

  Finder finderDialogo() => find.byType(AlertDialog);

  /// Botón de alta de la cabecera de Categorías. Se ancla a su key porque su
  /// rótulo `Nueva categoría` es el mismo que el del título del formulario.
  Finder botonNuevaCategoria() => find.byKey(const Key('boton-nueva-categoria'));

  /// Título del formulario de alta, acotado al diálogo para no confundirse con
  /// el rótulo del botón de la cabecera.
  Finder tituloDialogoCategoria() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Nueva categoría'),
  );

  // El formulario de alta/edición es un solo componente, así que se busca por
  // sus keys y no por rótulos: el principal cambia entre 'Crear categoría' y
  // 'Guardar cambios' según el estado.
  Finder formularioCategoria() => find.byKey(const Key('dialogo-categoria'));

  Finder campoNombreCategoria() =>
      find.byKey(const Key('campo-nombre-categoria'));

  Finder botonGuardarCategoria() => find.byKey(const Key('guardar-categoria'));

  Finder botonCancelarCategoria() => find.byKey(const Key('cancelar-categoria'));

  /// Zona de error bajo el campo (ocupa el lugar de la ayuda).
  Finder errorCategoria() => find.byKey(const Key('error-nombre-categoria'));

  Finder ayudaCategoria() => find.byKey(const Key('ayuda-nombre-categoria'));

  /// Abre el menú `...` de una categoría propia.
  Future<void> abrirMenu(WidgetTester tester, String tarjeta) async {
    await tester.ensureVisible(find.byKey(Key('categoria-propia-$tarjeta')));
    await tester.tap(find.byKey(Key('menu-categoria-$tarjeta')));
    await tester.pumpAndSettle();
  }

  /// Elige un ítem del menú abierto. Se ancla al key del `PopupMenuItem` porque
  /// los rótulos 'Desactivar' y 'Activar' también existen en las tarjetas
  /// sugeridas.
  Future<void> elegirDelMenu(WidgetTester tester, String opcion) async {
    await tester.tap(find.byKey(ValueKey('menu-item-$opcion')));
    await tester.pumpAndSettle();
  }

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
  /// Devuelve vacía si el documento todavía no existe.
  Future<List<Map<String, dynamic>>> personalizadasGuardadas(
    FakeFirebaseFirestore db,
  ) async {
    final datos = (await db.collection('negocios').doc('negocio-1').get()).data();
    return (datos?['categoriasPersonalizadas'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
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
    expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
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
    expect(find.byKey(const Key('seccion-sugeridas')), findsNothing);

    await irACategorias(tester);
    expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
    expect(find.byKey(const Key('categoria-propia-ofertas')), findsOneWidget);
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

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    expect(tituloDialogoCategoria(), findsOneWidget);

    await tester.enterText(
      campoNombreCategoria(),
      'Ofertas',
    );
    await tester.tap(botonGuardarCategoria());
    await tester.pumpAndSettle();

    expect(tituloDialogoCategoria(), findsNothing);
    expect(find.byKey(const Key('categoria-propia-ofertas')), findsOneWidget);
    expect(estadoPropia('ofertas', 'Activa'), findsOneWidget);
    // Aparece bajo "Tus categorías", no junto a las sugeridas.
    expect(find.byKey(const Key('seccion-propias')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-propias')),
        matching: find.byKey(const Key('categoria-propia-ofertas')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-sugeridas')),
        matching: find.byKey(const Key('categoria-propia-ofertas')),
      ),
      findsNothing,
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

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    await tester.enterText(
      campoNombreCategoria(),
      'Temporal',
    );
    await tester.tap(botonCancelarCategoria());
    await tester.pumpAndSettle();

    expect(tituloDialogoCategoria(), findsNothing);
    expect(provider.categoriasPersonalizadas, isEmpty);
    expect(find.byKey(const Key('categoria-card-Temporal')), findsNothing);
  });

  // ── 8. Bloquear duplicado del preset ────────────────────────────────────
  testWidgets('bloquea un nombre que ya es del preset y conserva el texto', (
    tester,
  ) async {
    await mostrarPaso(tester);

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    await tester.enterText(
      campoNombreCategoria(),
      'Bébidas ',
    );
    await tester.tap(botonGuardarCategoria());
    await tester.pumpAndSettle();

    expect(tituloDialogoCategoria(), findsOneWidget);
    expect(
      find.text('Ese nombre ya es una categoría sugerida de Bodega.'),
      findsOneWidget,
    );
    expect(find.textContaining('Bébidas'), findsOneWidget);

    await tester.tap(botonCancelarCategoria());
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

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    await tester.enterText(
      campoNombreCategoria(),
      '  Dulces ',
    );
    await tester.tap(botonGuardarCategoria());
    await tester.pumpAndSettle();

    expect(tituloDialogoCategoria(), findsOneWidget);
    expect(
      find.text('Ya existe una categoría con ese nombre.'),
      findsOneWidget,
    );

    await tester.tap(botonCancelarCategoria());
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

    await tester.ensureVisible(find.byKey(const Key('categoria-propia-ofertas')));
    await tester.tap(accionTarjetaPropia('ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('Editar categoría'), findsOneWidget);

    await tester.enterText(
      campoNombreCategoria(),
      'Promociones',
    );
    await tester.tap(botonGuardarCategoria());
    await tester.pumpAndSettle();

    final customizing = provider.categoriasPersonalizadas.single;
    expect(customizing.clave, 'ofertas');
    expect(customizing.nombre, 'Promociones');
    expect(customizing.activa, isTrue);
    // La tarjeta se identifica por clave, así que no se recrea al renombrar.
    expect(find.byKey(const Key('categoria-propia-ofertas')), findsOneWidget);
    expect(find.text('Promociones'), findsOneWidget);
    expect(find.text('Ofertas'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-propias')),
        matching: find.byKey(const Key('categoria-propia-ofertas')),
      ),
      findsOneWidget,
    );
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

    await abrirMenu(tester, 'ofertas');
    await elegirDelMenu(tester, 'eliminar');
    expect(find.text('¿Eliminar Ofertas?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
      contains('ofertas'),
    );

    await abrirMenu(tester, 'ofertas');
    await elegirDelMenu(tester, 'eliminar');
    await tester.tap(
      find.descendant(of: finderDialogo(), matching: find.text('Eliminar')),
    );
    await tester.pumpAndSettle();

    expect(provider.categoriasPersonalizadas, isEmpty);
    expect(find.byKey(const Key('categoria-propia-ofertas')), findsNothing);
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

    await tester.ensureVisible(find.byKey(const Key('categoria-propia-ofertas')));
    expect(estadoPropia('ofertas', 'Activa'), findsOneWidget);

    await abrirMenu(tester, 'ofertas');
    await elegirDelMenu(tester, 'alternar');

    // Desactivar NO es eliminar: sigue en la lista, con `activa: false`.
    expect(find.byKey(const Key('categoria-propia-ofertas')), findsOneWidget);
    expect(estadoPropia('ofertas', 'Inactiva'), findsOneWidget);
    expect(estadoPropia('ofertas', 'Activa'), findsNothing);
    expect(provider.categoriasPersonalizadas.single.activa, isFalse);
    expect(
      (await personalizadasGuardadas(db)).single['activa'],
      isFalse,
    );

    await abrirMenu(tester, 'ofertas');
    await elegirDelMenu(tester, 'alternar');

    expect(estadoPropia('ofertas', 'Activa'), findsOneWidget);
    expect(provider.categoriasPersonalizadas.single.activa, isTrue);
  });

  // ── 11. Preset: solo el interruptor, nunca Editar/Eliminar ─────────────
  testWidgets('una categoría sugerida no ofrece Editar ni Eliminar', (
    tester,
  ) async {
    await mostrarPaso(tester);

    final tarjeta = find.byKey(const Key('categoria-card-Abarrotes'));
    final sugeridas = PresetsVenta.obtener('Bodega').categorias.length;
    // El rótulo del origen vive UNA vez, en el encabezado de sección: ya no
    // se repite dentro de cada tarjeta.
    expect(find.text('Sugeridas para Bodega'), findsOneWidget);
    expect(find.text('Sugerida para Bodega'), findsNothing);
    expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
    expect(accionTarjeta('Desactivar', 'Abarrotes'), findsOneWidget);
    expect(find.text('Activa'), findsNWidgets(sugeridas));
    expect(find.byKey(const Key('menu-categoria-Abarrotes')), findsNothing);
    expect(
      find.descendant(of: tarjeta, matching: find.text('Editar')),
      findsNothing,
    );
  });

  // ── 11b. Iconos: solo los conocidos del preset, nunca inferidos ────────
  testWidgets('el preset muestra iconos conocidos y las propias ninguno', (
    tester,
  ) async {
    await mostrarPaso(
      tester,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

    // Nombres conocidos del preset de Bodega.
    expect(
      find.descendant(
        of: find.byKey(const Key('categoria-card-Abarrotes')),
        matching: find.byIcon(Icons.inventory_2_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('categoria-card-Bebidas')),
        matching: find.byIcon(Icons.local_drink_outlined),
      ),
      findsOneWidget,
    );
    // La personalizada no lleva icono propio: solo el del menú.
    final propia = find.byKey(const Key('categoria-propia-ofertas'));
    expect(find.descendant(of: propia, matching: find.byIcon(Icons.more_horiz)), findsOneWidget);
    expect(
      find.descendant(
        of: propia,
        matching: find.byIcon(Icons.local_drink_outlined),
      ),
      findsNothing,
    );
  });

  testWidgets('una personalizada no hereda el icono de una sugerida', (
    tester,
  ) async {
    // "Bebidas" es una categoría CONOCIDA del preset, pero aquí llega como
    // personalizada: el icono no se deduce del texto, así que no lo hereda.
    await mostrarPaso(
      tester,
      configuracionInicial: {
        'categoriasPersonalizadas': [
          {'clave': 'bebidas', 'nombre': 'Bebidas', 'activa': true},
        ],
      },
    );

    final propia = find.byKey(const Key('categoria-propia-bebidas'));
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-propias')),
        matching: propia,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-sugeridas')),
        matching: propia,
      ),
      findsNothing,
    );
    // La tarjeta propia solo lleva el icono del menú, no el de la sugerida.
    expect(
      find.descendant(of: propia, matching: find.byIcon(Icons.local_drink_outlined)),
      findsNothing,
    );
    // Y la sugerida real sí conserva su icono.
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-sugeridas')),
        matching: find.byIcon(Icons.local_drink_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('las dos secciones muestran su contador', (tester) async {
    await mostrarPaso(
      tester,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
        'dulces': (activa: false),
      }),
    );

    // Bodega tiene 5 de preset + 1 propia activa.
    expect(find.text('6 activas · 5 sugeridas · 1 propia'), findsOneWidget);
    expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
    expect(find.byKey(const Key('seccion-propias')), findsOneWidget);
    expect(find.text('5 de 5'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    // Con propias visibles no debe aparecer el estado vacío.
    expect(
      find.textContaining('Todavía no has creado categorías propias.'),
      findsNothing,
    );
  });

  testWidgets('sin personalizadas se muestra el estado vacío compacto', (
    tester,
  ) async {
    await mostrarPaso(tester);

    expect(
      find.textContaining('Todavía no has creado categorías propias.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('categoria-propia-ofertas')), findsNothing);
  });

  testWidgets('las propias ofrecen Editar y el menú con las tres acciones', (
    tester,
  ) async {
    await mostrarPaso(
      tester,
      configuracionInicial: seedPersonalizadas({
        'ofertas': (activa: true),
      }),
    );

    final propia = find.byKey(const Key('categoria-propia-ofertas'));
    expect(
      find.descendant(of: propia, matching: find.text('Editar')),
      findsOneWidget,
    );
    // Eliminar y el interruptor viven en el menú, no en la tarjeta.
    expect(
      find.descendant(of: propia, matching: find.text('Eliminar')),
      findsNothing,
    );
    expect(
      find.descendant(of: propia, matching: find.text('Desactivar')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('menu-categoria-ofertas')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-item-alternar')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-eliminar')), findsOneWidget);
    // Está activa, así que el ítem ofrece desactivar y no activar.
    expect(find.text('Activar'), findsNothing);
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
    expect(find.text('Sugeridas para Bodega'), findsOneWidget);
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

    // El origen decide la SECCIÓN, no el nombre: 'Ofertas' vive bajo "Tus
    // categorías" aunque comparta forma con una sugerida.
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-propias')),
        matching: find.byKey(const Key('categoria-propia-ofertas')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('seccion-sugeridas')),
        matching: find.byKey(const Key('categoria-propia-ofertas')),
      ),
      findsNothing,
    );
    // Y las acciones difieren por origen: el preset solo se activa/desactiva,
    // la personalizada además se renombra y se elimina (vía menú).
    expect(accionTarjeta('Desactivar', 'Abarrotes'), findsOneWidget);
    expect(find.byKey(const Key('menu-categoria-ofertas')), findsOneWidget);
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

    await abrirMenu(tester, 'ofertas');
    await elegirDelMenu(tester, 'eliminar');
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

    await tester.tap(accionTarjetaPropia('ofertas'));
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

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    await tester.enterText(
      campoNombreCategoria(),
      'Frutos secos',
    );
    await tester.tap(botonGuardarCategoria());
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

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    await tester.enterText(
      campoNombreCategoria(),
      'a',
    );
    await tester.tap(botonGuardarCategoria());
    await tester.pumpAndSettle();

    expect(tituloDialogoCategoria(), findsOneWidget);
    expect(
      find.text('El nombre debe tener al menos 2 caracteres.'),
      findsOneWidget,
    );
    await tester.tap(botonCancelarCategoria());
    await tester.pumpAndSettle();
  });

  testWidgets('rechaza nombres formados solo por símbolos', (tester) async {
    await mostrarPaso(tester);

    await tester.tap(botonNuevaCategoria());
    await tester.pumpAndSettle();
    await tester.enterText(
      campoNombreCategoria(),
      '@@@',
    );
    await tester.tap(botonGuardarCategoria());
    await tester.pumpAndSettle();

    expect(tituloDialogoCategoria(), findsOneWidget);
    expect(
      find.text('El nombre debe incluir letras o números.'),
      findsOneWidget,
    );
    await tester.tap(botonCancelarCategoria());
    await tester.pumpAndSettle();
  });

  // ── Cabecera: título/contador a la izquierda, botón a la derecha ───────
  testWidgets('el botón de la cabecera cierra contra las tarjetas', (
    tester,
  ) async {
    await mostrarPaso(tester, size: const Size(1000, 2400));

    final boton = botonNuevaCategoria();
    // La rejilla de tarjetas sugeridas es la referencia del "borde derecho del
    // contenido": mide la fila completa, no una card suelta.
    final grilla = find.descendant(
      of: find.byKey(const Key('seccion-sugeridas')),
      matching: find.byType(Wrap),
    );

    // Mismo borde derecho que el contenido, sin offsets ni paddings a mano.
    expect(
      tester.getTopRight(boton).dx,
      moreOrLessEquals(tester.getTopRight(grilla).dx, epsilon: 0.01),
    );
    // Título y contador se quedan a la izquierda, en la misma cabecera.
    expect(find.text('Organiza tus productos'), findsOneWidget);
    expect(find.textContaining('activas ·'), findsOneWidget);
    // El rótulo no repite el `Icons.add`.
    expect(find.text('Nueva categoría'), findsOneWidget);
    expect(find.text('+ Nueva categoría'), findsNothing);
  });

  testWidgets('en anchos pequeños el botón baja debajo del título', (
    tester,
  ) async {
    await mostrarPaso(tester, size: const Size(360, 2400));

    final boton = botonNuevaCategoria();
    final titulo = find.text('Organiza tus productos');

    expect(
      tester.getTopLeft(boton).dy,
      greaterThan(tester.getBottomLeft(titulo).dy),
    );
    // Ocupa el ancho del contenido, así también cierra a la derecha.
    expect(
      tester.getSize(boton).width,
      moreOrLessEquals(tester.getSize(titulo).width, epsilon: 0.01),
    );
  });

  // ── Formulario de categoría ─────────────────────────────────────────────
  // Alta y edición comparten un único componente: estos tests fijan el
  // contrato visual (título, label, ayuda, rótulos del botón) sin repetir los
  // que ya cubren la validación y la persistencia.
  group('formulario de categoría', () {
    testWidgets('abre "Nueva categoría" con label, ayuda y botón de alta', (
      tester,
    ) async {
      await mostrarPaso(tester);

      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsOneWidget);
      expect(tituloDialogoCategoria(), findsOneWidget);
      expect(find.text('Nombre de la categoría'), findsOneWidget);
      expect(find.text('Ej. Comida para mascotas'), findsOneWidget);
      expect(ayudaCategoria(), findsOneWidget);
      expect(find.text('Crear categoría'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsNothing);
      expect(errorCategoria(), findsNothing);
      // El campo arranca vacío y con el foco para escribir de inmediato.
      expect(tester.widget<TextField>(campoNombreCategoria()).controller?.text, '');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: campoNombreCategoria(),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('un campo vacío no guarda y lo explica bajo el campo', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final provider = await mostrarPaso(
        tester,
        negocioId: 'negocio-1',
        firestore: db,
      );

      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      await tester.tap(botonGuardarCategoria());
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsOneWidget);
      expect(errorCategoria(), findsOneWidget);
      expect(
        find.text('Escribe el nombre de la categoría.'),
        findsOneWidget,
      );
      // El error sustituye a la ayuda: la zona bajo el campo no se duplica.
      expect(ayudaCategoria(), findsNothing);
      expect(provider.categoriasPersonalizadas, isEmpty);
      expect(await personalizadasGuardadas(db), isEmpty);
    });

    testWidgets('un duplicado muestra el error y conserva lo escrito', (
      tester,
    ) async {
      await mostrarPaso(
        tester,
        configuracionInicial: seedPersonalizadas({
          'dulces': (activa: true),
        }),
      );

      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      await tester.enterText(campoNombreCategoria(), '  Dulces ');
      await tester.tap(botonGuardarCategoria());
      await tester.pumpAndSettle();

      expect(errorCategoria(), findsOneWidget);
      expect(
        find.text('Ya existe una categoría con ese nombre.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(campoNombreCategoria()).controller?.text,
        '  Dulces ',
        reason: 'corregir el nombre no obliga a reescribirlo desde cero',
      );

      await tester.tap(botonCancelarCategoria());
      await tester.pumpAndSettle();
    });

    testWidgets('una categoría válida se crea y cierra el formulario', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final provider = await mostrarPaso(
        tester,
        negocioId: 'negocio-1',
        firestore: db,
      );

      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      await tester.enterText(
        campoNombreCategoria(),
        'Comida para mascotas',
      );
      await tester.tap(botonGuardarCategoria());
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsNothing);
      expect(provider.categoriasPersonalizadas.single.nombre,
          'Comida para mascotas');
      expect(
        (await personalizadasGuardadas(db)).map((c) => c['clave']),
        contains('comida para mascotas'),
      );
    });

    testWidgets('Editar precarga el nombre existente', (tester) async {
      await mostrarPaso(
        tester,
        configuracionInicial: seedPersonalizadas({
          'ofertas': (activa: true),
        }),
      );

      await tester.ensureVisible(
        find.byKey(const Key('categoria-propia-ofertas')),
      );
      await tester.tap(accionTarjetaPropia('ofertas'));
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsOneWidget);
      expect(find.text('Editar categoría'), findsOneWidget);
      // Mismo formulario, otro rótulo: solo cambia el estado.
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Crear categoría'), findsNothing);
      expect(find.text('Nombre de la categoría'), findsOneWidget);
      expect(
        tester.widget<TextField>(campoNombreCategoria()).controller?.text,
        'Ofertas',
      );
    });

    testWidgets('guardar la edición actualiza el nombre y conserva la clave', (
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

      await tester.ensureVisible(
        find.byKey(const Key('categoria-propia-ofertas')),
      );
      await tester.tap(accionTarjetaPropia('ofertas'));
      await tester.pumpAndSettle();
      await tester.enterText(campoNombreCategoria(), 'Promociones');
      await tester.tap(botonGuardarCategoria());
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsNothing);
      final actualizada = provider.categoriasPersonalizadas.single;
      expect(actualizada.clave, 'ofertas');
      expect(actualizada.nombre, 'Promociones');
      expect(
        (await personalizadasGuardadas(db)).single['nombre'],
        'Promociones',
      );
    });

    testWidgets('el loading deshabilita el botón y evita el doble submit', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final repositorio = _RepositorioLento(db);
      final provider = await mostrarPaso(
        tester,
        negocioId: 'negocio-1',
        firestore: db,
        repositorio: repositorio,
      );

      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      await tester.enterText(campoNombreCategoria(), 'Lentos');
      await tester.tap(botonGuardarCategoria());
      // Un solo frame: la escritura sigue retenida por el repositorio.
      await tester.pump();

      expect(
        find.descendant(
          of: formularioCategoria(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('Crear categoría'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(botonGuardarCategoria()).enabled,
        isFalse,
        reason: 'mientras guarda no se puede volver a enviar',
      );
      // Enter tampoco sirve de atajo para saltarse el bloqueo.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repositorio.llamadas, 1);
      expect(provider.categoriasPersonalizadas, isEmpty);

      repositorio.liberar();
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsNothing);
      expect(repositorio.llamadas, 1);
      expect(provider.categoriasPersonalizadas.single.nombre, 'Lentos');
    });

    testWidgets('el formulario no desborda en móvil ni se ensancha en escritorio', (
      tester,
    ) async {
      // Móvil: todo cabe y no hay desbordamiento.
      await mostrarPaso(tester, size: const Size(320, 640));
      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(botonGuardarCategoria(), findsOneWidget);
      // El formulario ocupa el ancho disponible menos el margen, ni más.
      expect(
        tester.getSize(campoNombreCategoria()).width,
        moreOrLessEquals(240),
      );
      await tester.tap(botonCancelarCategoria());
      await tester.pumpAndSettle();

      // Escritorio: el ancho está acotado a 380, no se estira a la ventana.
      await mostrarPaso(tester, size: const Size(1720, 900));
      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(campoNombreCategoria()).width,
        moreOrLessEquals(380),
      );
      await tester.tap(botonCancelarCategoria());
      await tester.pumpAndSettle();
    });

    testWidgets('cancelar y Escape cierran sin modificar nada', (tester) async {
      final db = FakeFirebaseFirestore();
      final provider = await mostrarPaso(
        tester,
        negocioId: 'negocio-1',
        firestore: db,
        configuracionInicial: seedPersonalizadas({
          'ofertas': (activa: true),
        }),
      );

      // Cancelar en el alta.
      await tester.tap(botonNuevaCategoria());
      await tester.pumpAndSettle();
      await tester.enterText(campoNombreCategoria(), 'Temporal');
      await tester.tap(botonCancelarCategoria());
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsNothing);
      expect(provider.categoriasPersonalizadas.map((c) => c.clave), ['ofertas']);
      expect(await personalizadasGuardadas(db), isEmpty);

      // Escape en la edición.
      await tester.ensureVisible(
        find.byKey(const Key('categoria-propia-ofertas')),
      );
      await tester.tap(accionTarjetaPropia('ofertas'));
      await tester.pumpAndSettle();
      await tester.enterText(campoNombreCategoria(), 'Renombrada');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(formularioCategoria(), findsNothing);
      expect(provider.categoriasPersonalizadas.single.nombre, 'Ofertas');
      expect(await personalizadasGuardadas(db), isEmpty);
    });
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

        expect(botonNuevaCategoria(), findsOneWidget);
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
        expect(botonNuevaCategoria(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// Repositorio que retiene la escritura de categorías hasta que se le libera.
/// Permite observar el estado "guardando" sin depender de timers ni de esperas.
class _RepositorioLento extends NegocioRepository {
  _RepositorioLento(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  /// Escrituras pedidas: si el formulario permitiera el doble submit, esta
  /// cuenta sube a 2.
  int llamadas = 0;

  final Completer<void> _liberar = Completer<void>();

  void liberar() => _liberar.complete();

  @override
  Future<void> guardarCategoriasPersonalizadas(
    String uid,
    List<CategoriaPersonalizada> categorias, {
    String? negocioId,
  }) async {
    llamadas++;
    await _liberar.future;
    return super.guardarCategoriasPersonalizadas(
      uid,
      categorias,
      negocioId: negocioId,
    );
  }
}
