import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_plantilla_screen.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_plantilla_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_plantilla_flow.dart';
import 'package:mobile/features/negocio/seleccion_plantilla_dependencies.dart';
import 'package:provider/provider.dart';

void main() {
  SeleccionPlantillaInfo inicialDe(_RepositorioSeleccionFake repo) {
    return SeleccionPlantillaInfo(
      slug: repo.slug,
      plantillaGuardada: repo.plantillaGuardada,
      provieneDeCampoOficial: true,
    );
  }

  Future<void> montarFlujo(
    WidgetTester tester, {
    _RepositorioSeleccionFake? repositorio,
    SeleccionPlantillaInfo? seleccionInicial,
    bool conSeleccionInicial = true,
    VoidCallback? onVolver,
    Future<void> Function(String plantilla)? onCompletado,
    Future<void> Function(String slug)? onVerTienda,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = repositorio ?? _RepositorioSeleccionFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeleccionPlantillaFlow(
            uid: 'usuario-1',
            rubro: 'Bodega',
            seleccionInicial: conSeleccionInicial
                ? (seleccionInicial ?? inicialDe(repo))
                : null,
            dependencies: SeleccionPlantillaDependencies.fromRepository(repo),
            onVolver: onVolver ?? () {},
            onCompletado: onCompletado ?? (_) async {},
            onVerTienda: onVerTienda ?? (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SeleccionPlantillaProvider providerDelArbol(WidgetTester tester) {
    final contexto = tester.element(find.byType(SeleccionPlantillaContent));
    return Provider.of<SeleccionPlantillaProvider>(contexto, listen: false);
  }

  Finder popScopeDelFlujo() => find.descendant(
    of: find.byType(SeleccionPlantillaFlow),
    matching: find.byType(PopScope),
  );

  Finder absorbDelFlujo() => find.descendant(
    of: find.byType(SeleccionPlantillaFlow),
    matching: find.byType(AbsorbPointer),
  );

  testWidgets('el flujo se monta sin Scaffold, AppBar ni SafeArea', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SeleccionPlantillaFlow(
            uid: 'usuario-1',
            dependencies: SeleccionPlantillaDependencies.fromRepository(
              _RepositorioSeleccionFake(),
            ),
            seleccionInicial: inicialDe(_RepositorioSeleccionFake()),
            onVolver: () {},
            onCompletado: (_) async {},
            onVerTienda: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SeleccionPlantillaFlow),
        matching: find.byType(Scaffold),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SeleccionPlantillaFlow),
        matching: find.byType(AppBar),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SeleccionPlantillaFlow),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

  testWidgets('la pantalla envuelve el flujo en un único Scaffold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SeleccionPlantillaScreen(
          uid: 'usuario-1',
          seleccionInicial: inicialDe(_RepositorioSeleccionFake()),
          dependencies: SeleccionPlantillaDependencies.fromRepository(
            _RepositorioSeleccionFake(),
          ),
          onVolver: () {},
          onCompletado: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
    expect(find.byType(SeleccionPlantillaContent), findsOneWidget);
  });

  testWidgets('crea y carga el provider una sola vez con identidad estable', (
    tester,
  ) async {
    final repo = _RepositorioSeleccionFake();
    await montarFlujo(tester, repositorio: repo, conSeleccionInicial: false);

    expect(repo.lecturas, 1);
    final provider = providerDelArbol(tester);
    expect(provider.cargado, isTrue);
    expect(provider.seleccionTemporal, PlantillaWeb.neon);
    expect(find.byKey(const Key('plantillas-wrap')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeleccionPlantillaFlow(
            uid: 'usuario-1',
            rubro: 'Bodega',
            dependencies: SeleccionPlantillaDependencies.fromRepository(repo),
            onVolver: () {},
            onCompletado: (_) async {},
            onVerTienda: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lecturas, 1);
    expect(identical(providerDelArbol(tester), provider), isTrue);
  });

  testWidgets('con selección inicial no vuelve a leer el repositorio', (
    tester,
  ) async {
    final repo = _RepositorioSeleccionFake();
    await montarFlujo(tester, repositorio: repo);

    expect(repo.lecturas, 0);
    expect(providerDelArbol(tester).cargado, isTrue);
  });

  testWidgets('la selección temporal se conserva al reconstruir', (
    tester,
  ) async {
    final repo = _RepositorioSeleccionFake();
    await montarFlujo(tester, repositorio: repo);

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-cristal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-cristal')));
    await tester.pumpAndSettle();

    expect(providerDelArbol(tester).seleccionTemporal, PlantillaWeb.cristal);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeleccionPlantillaFlow(
            uid: 'usuario-1',
            rubro: 'Bodega',
            seleccionInicial: inicialDe(repo),
            dependencies: SeleccionPlantillaDependencies.fromRepository(repo),
            onVolver: () {},
            onCompletado: (_) async {},
            onVerTienda: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(providerDelArbol(tester).seleccionTemporal, PlantillaWeb.cristal);
    expect(
      find.descendant(
        of: find.byKey(const Key('plantilla-card-cristal')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('guardado exitoso llama una sola vez a onCompletado', (
    tester,
  ) async {
    final repo = _RepositorioSeleccionFake();
    var completados = 0;
    String? plantillaCompletada;
    await montarFlujo(
      tester,
      repositorio: repo,
      onCompletado: (plantilla) async {
        completados++;
        plantillaCompletada = plantilla;
      },
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();

    expect(repo.guardados, 1);
    expect(completados, 1);
    expect(plantillaCompletada, PlantillaWeb.sabroso.valorPersistencia);
  });

  testWidgets('doble clic en Finalizar no duplica el guardado', (tester) async {
    final freno = Completer<void>();
    final repo = _RepositorioSeleccionFake(frenoGuardado: freno);
    var completados = 0;
    await montarFlujo(
      tester,
      repositorio: repo,
      onCompletado: (_) async => completados++,
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('finalizar-plantilla')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('finalizar-plantilla')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isFalse);
    expect(tester.widget<AbsorbPointer>(absorbDelFlujo()).absorbing, isTrue);

    freno.complete();
    await tester.pumpAndSettle();

    expect(repo.guardados, 1);
    expect(completados, 1);
    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isTrue);
  });

  testWidgets('un error de guardado mantiene al usuario en Plantilla', (
    tester,
  ) async {
    final repo = _RepositorioSeleccionFake(fallarGuardado: true);
    var completados = 0;
    await montarFlujo(
      tester,
      repositorio: repo,
      onCompletado: (_) async => completados++,
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();

    expect(repo.guardados, 0);
    expect(completados, 0);
    expect(find.byType(SeleccionPlantillaContent), findsOneWidget);
    expect(find.byKey(const Key('plantillas-wrap')), findsOneWidget);
    expect(find.textContaining('No se pudo guardar'), findsWidgets);
    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isTrue);
  });

  testWidgets('volver y retroceso quedan bloqueados durante el guardado', (
    tester,
  ) async {
    final freno = Completer<void>();
    final repo = _RepositorioSeleccionFake(frenoGuardado: freno);
    var volveres = 0;
    var completados = 0;
    await montarFlujo(
      tester,
      repositorio: repo,
      onVolver: () => volveres++,
      onCompletado: (_) async => completados++,
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-sabroso')));
    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('finalizar-plantilla')));
    await tester.pump();

    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isFalse);
    expect(tester.widget<AbsorbPointer>(absorbDelFlujo()).absorbing, isTrue);

    await tester.ensureVisible(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('ir-dashboard-plantilla')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(volveres, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(SeleccionPlantillaContent), findsOneWidget);

    freno.complete();
    await tester.pumpAndSettle();

    expect(completados, 1);
    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isTrue);
    expect(volveres, 0);
  });

  testWidgets('onVerTienda se propaga con el slug de la tienda', (
    tester,
  ) async {
    final slugs = <String>[];
    await montarFlujo(tester, onVerTienda: (slug) async => slugs.add(slug));

    await tester.ensureVisible(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pumpAndSettle();

    expect(slugs, ['mi-tienda']);
  });

  testWidgets('sin tienda guardada no propaga onVerTienda', (tester) async {
    final repo = _RepositorioSeleccionFake(slug: '');
    var llamadas = 0;
    await montarFlujo(
      tester,
      repositorio: repo,
      onVerTienda: (_) async => llamadas++,
    );

    await tester.ensureVisible(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pump();

    expect(llamadas, 0);
    expect(
      find.text('La vista web estará disponible próximamente'),
      findsOneWidget,
    );
  });
}

class _RepositorioSeleccionFake implements RepositorioSeleccionPlantilla {
  final String slug;
  final PlantillaWeb plantillaGuardada = PlantillaWeb.neon;
  final Completer<void>? frenoGuardado;
  final bool fallarGuardado;
  int lecturas = 0;
  int guardados = 0;

  _RepositorioSeleccionFake({
    this.slug = 'mi-tienda',
    this.frenoGuardado,
    this.fallarGuardado = false,
  });

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    lecturas++;
    return SeleccionPlantillaInfo(
      slug: slug,
      plantillaGuardada: plantillaGuardada,
      provieneDeCampoOficial: true,
    );
  }

  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {
    if (fallarGuardado) throw StateError('sin red');
    final f = frenoGuardado;
    if (f != null) await f.future;
    guardados++;
  }
}
