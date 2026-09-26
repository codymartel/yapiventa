import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/authenticated_shell.dart';
import 'package:mobile/features/auth/domain/politica_acceso.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_attention_panel.dart';
import 'package:mobile/features/dashboard/presentation/widgets/configuracion_contextual_panel.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_top_bar.dart';
import 'package:mobile/features/dashboard/presentation/widgets/plantilla_contextual_panel.dart';
import 'package:mobile/features/dashboard/presentation/widgets/rubro_contextual_panel.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/application/use_cases/guardar_plantilla_web.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/catalogo_negocio_dependencies.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/presentation/providers/catalogo_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_flow.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_negocio_flow.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_plantilla_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_plantilla_flow.dart';
import 'package:mobile/features/negocio/seleccion_plantilla_dependencies.dart';
import 'package:mobile/features/productos/application/use_cases/cambiar_disponibilidad_producto.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/eliminar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/obtener_pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_content.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_contextual_panel.dart';
import 'package:mobile/features/productos/presentation/widgets/productos_flow.dart';
import 'package:mobile/features/productos/productos_dependencies.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(PlantillaWeb.cristal);
    registerFallbackValue(PlantillaWeb.galeria);
  });

  Future<_EscenarioDashboard> mostrarDashboard(
    WidgetTester tester, {
    bool resultado = true,
    Object? error,
    ProgresoConfiguracion? progreso,
    NegocioRepository? repositorio,
    _DependenciasProductos? dependencias,
    _DependenciasPlantilla? dependenciasPlantilla,
    Size size = const Size(1400, 1000),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dashboardProvider = DashboardProvider();
    final abridor = _AbridorFake(resultado: resultado, error: error);
    final etapasAbiertas = <EtapaConfiguracion>[];
    final deps = dependencias ?? _crearDependenciasTest();
    final depsPlantilla =
        dependenciasPlantilla ?? _crearDependenciasPlantillaTest();
    final repositorioNegocio =
        repositorio ?? NegocioRepository(firestore: FakeFirebaseFirestore());
    addTearDown(dashboardProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: dashboardProvider,
        child: Provider<NegocioRepository>.value(
          value: repositorioNegocio,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
            home: Builder(
              builder: (context) => DashboardWebScreen(
                uid: 'usuario-1',
                negocioId: 'negocio-1',
                abrirUrl: abridor.call,
                progreso: progreso ?? _progresoCompleto(),
                email: 'ana@example.com',
                onAbrirEtapa: (etapa) {
                  etapasAbiertas.add(etapa);
                  Navigator.of(context).pushNamed(PoliticaAcceso.rutaDe(etapa));
                },
                onCerrarSesion: () {},
                productosDependencies: deps.productos,
                catalogoDependencies: deps.catalogo,
                seleccionPlantillaDependencies:
                    depsPlantilla.seleccionPlantilla,
              ),
            ),
            routes: {
              '/elegir-rubro': (_) => const Scaffold(
                body: Center(child: Text('Seleccion de rubro')),
              ),
              '/configurar-negocio': (_) => const Scaffold(
                body: Center(child: Text('Configuracion de negocio')),
              ),
              '/productos': (_) => const Scaffold(
                body: Center(child: Text('Lista de productos')),
              ),
              '/elegir-plantilla': (_) => const Scaffold(
                body: Center(child: Text('Seleccion de plantilla')),
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _EscenarioDashboard(
      abridor: abridor,
      etapasAbiertas: etapasAbiertas,
      provider: dashboardProvider,
      dependencias: deps,
      dependenciasPlantilla: depsPlantilla,
    );
  }

  Future<_EscenarioDashboard> mostrarDashboardConProgresoActualizable(
    WidgetTester tester, {
    required ProgresoConfiguracion progreso,
    NegocioRepository? repositorio,
    _DependenciasProductos? dependencias,
    _DependenciasPlantilla? dependenciasPlantilla,
    Future<void> Function()? recargarProgreso,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dashboardProvider = DashboardProvider();
    final abridor = _AbridorFake(resultado: true);
    final etapasAbiertas = <EtapaConfiguracion>[];
    final deps = dependencias ?? _crearDependenciasTest();
    final depsPlantilla =
        dependenciasPlantilla ?? _crearDependenciasPlantillaTest();
    final repositorioNegocio =
        repositorio ?? NegocioRepository(firestore: FakeFirebaseFirestore());
    addTearDown(dashboardProvider.dispose);

    final llave = GlobalKey<_EstadoProgresoRecargableState>();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: dashboardProvider,
        child: Provider<NegocioRepository>.value(
          value: repositorioNegocio,
          child: MaterialApp(
            home: _EstadoProgresoRecargable(
              key: llave,
              progreso: progreso,
              builder: (context, progresoActual) => DashboardWebScreen(
                uid: 'usuario-1',
                negocioId: 'negocio-1',
                recargarProgreso: recargarProgreso,
                abrirUrl: abridor.call,
                progreso: progresoActual,
                email: 'ana@example.com',
                onAbrirEtapa: (etapa) {
                  etapasAbiertas.add(etapa);
                  Navigator.of(context).pushNamed(PoliticaAcceso.rutaDe(etapa));
                },
                onCerrarSesion: () {},
                productosDependencies: deps.productos,
                catalogoDependencies: deps.catalogo,
                seleccionPlantillaDependencies:
                    depsPlantilla.seleccionPlantilla,
              ),
            ),
            routes: {
              '/elegir-rubro': (_) => const Scaffold(
                body: Center(child: Text('Seleccion de rubro')),
              ),
              '/configurar-negocio': (_) => const Scaffold(
                body: Center(child: Text('Configuracion de negocio')),
              ),
              '/productos': (_) => const Scaffold(
                body: Center(child: Text('Lista de productos')),
              ),
              '/elegir-plantilla': (_) => const Scaffold(
                body: Center(child: Text('Seleccion de plantilla')),
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _EscenarioDashboard(
      abridor: abridor,
      etapasAbiertas: etapasAbiertas,
      provider: dashboardProvider,
      dependencias: deps,
      dependenciasPlantilla: depsPlantilla,
      actualizarProgreso: (nuevo) =>
          llave.currentState!.actualizarProgreso(nuevo),
    );
  }

  testWidgets(
    'usa el progreso compartido y abre el dominio publico sin releer',
    (tester) async {
      final escenario = await mostrarDashboard(tester);
      await tester.tap(find.text('Ver tienda web'));
      await tester.pumpAndSettle();

      expect(escenario.abridor.llamadas, 1);
      expect(
        escenario.abridor.ultimaUrl,
        Uri.parse('https://yapiventa-tienda.web.app/mi-tienda'),
      );
      expect(escenario.abridor.ultimoDestino, '_blank');
    },
  );

  testWidgets('diferencia el resultado false en Dashboard', (tester) async {
    await mostrarDashboard(tester, resultado: false);

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(
      find.text('El navegador no pudo abrir la tienda web.'),
      findsOneWidget,
    );
  });

  testWidgets('captura la excepcion de apertura en Dashboard', (tester) async {
    await mostrarDashboard(tester, error: StateError('plugin no registrado'));

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ocurrió un error al abrir la tienda web. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'abre el flujo de plantilla interno desde la barra superior sin ruta raíz',
    (tester) async {
      final escenario = await mostrarDashboard(tester);

      await tester.tap(find.byTooltip('Elegir plantilla'));
      await tester.pumpAndSettle();

      expect(escenario.etapasAbiertas, isEmpty);
      expect(escenario.abridor.llamadas, 0);
      expect(find.text('Seleccion de plantilla'), findsNothing);
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(find.byType(SeleccionPlantillaContent), findsOneWidget);
      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.plantilla);
    },
  );

  testWidgets('abre la primera etapa pendiente dentro del Navigator interno', (
    tester,
  ) async {
    final escenario = await mostrarDashboard(
      tester,
      progreso: _progresoPendiente(),
    );

    expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);
    expect(find.text('Continuar configuración'), findsOneWidget);
    expect(find.text('Requiere un rubro guardado.'), findsOneWidget);

    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(escenario.etapasAbiertas, isEmpty);
    expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
    expect(find.text('Seleccion de rubro'), findsNothing);
  });

  testWidgets('bloquea módulos ajenos mientras el onboarding está pendiente', (
    tester,
  ) async {
    await mostrarDashboard(tester, progreso: _progresoPendiente());

    await tester.tap(find.text('Pedidos').first);
    await tester.pump();

    expect(
      find.text('Completa primero las etapas pendientes de configuración.'),
      findsOneWidget,
    );
  });

  testWidgets('usa tres columnas y un unico Scaffold en escritorio', (
    tester,
  ) async {
    await mostrarDashboard(tester, size: const Size(1366, 1000));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(find.byType(DashboardSidebar), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('authenticated-shell-contextual-expansion')),
      findsNothing,
    );
    expect(find.text('Necesita tu atención'), findsOneWidget);
    expect(find.text('Resumen de tu negocio'), findsOneWidget);
    expect(find.text('Ventas de los últimos 7 días'), findsOneWidget);
    expect(find.text('Acciones rápidas'), findsOneWidget);
    expect(find.text('Pedidos recientes'), findsOneWidget);

    final navegacion = tester.getRect(
      find.byKey(const Key('authenticated-shell-navigation')),
    );
    final contenido = tester.getRect(
      find.byKey(const Key('authenticated-shell-content')),
    );
    final panel = tester.getRect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
    );
    expect(navegacion.width, AuthenticatedShell.navigationWidth);
    expect(panel.width, AuthenticatedShell.contextualPanelWidth);
    expect(navegacion.right, contenido.left);
    expect(contenido.right, panel.left);
  });

  testWidgets(
    'bajo el umbral de tres columnas el panel se pliega y el centro gana ancho',
    (tester) async {
      final ancho = AuthenticatedShell.anchoMinimoTresColumnas - 1;
      await mostrarDashboard(tester, size: Size(ancho, 1000));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsNothing,
      );
      expect(_botonAyuda(), findsOneWidget);
      expect(find.byTooltip('Abrir menú'), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-navigation')),
        findsNothing,
      );

      final contenido = tester.getRect(
        find.byKey(const Key('authenticated-shell-content')),
      );
      expect(contenido.width, ancho);
      expect(
        contenido.width,
        greaterThan(AuthenticatedShell.contenidoMinimoComodo),
      );
    },
  );

  testWidgets(
    'bajo el umbral de tres columnas la ayuda se abre bajo demanda',
    (tester) async {
      await mostrarDashboard(
        tester,
        size: Size(AuthenticatedShell.anchoMinimoTresColumnas - 1, 1000),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(DashboardTopBar), findsOneWidget);
      expect(find.byTooltip('Abrir menú'), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-navigation')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsNothing,
      );
      expect(_botonAyuda(), findsOneWidget);
      expect(find.text('Necesita tu atención'), findsNothing);

      await _abrirAyuda(tester);

      expect(_dialogoAyuda(), findsOneWidget);
      expect(find.text('Necesita tu atención'), findsOneWidget);

      await _cerrarAyuda(tester);

      expect(find.text('Necesita tu atención'), findsNothing);

      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardSidebar), findsOneWidget);
    },
  );

  testWidgets('el panel derecho se pliega antes de comprimir el contenido', (
    tester,
  ) async {
    await mostrarDashboard(
      tester,
      size: Size(AuthenticatedShell.anchoMinimoTresColumnas, 1000),
    );

    final centroConAmbas = tester.getRect(
      find.byKey(const Key('authenticated-shell-content')),
    );
    expect(
      centroConAmbas.width,
      AuthenticatedShell.anchoMinimoTresColumnas -
          AuthenticatedShell.navigationWidth -
          AuthenticatedShell.contextualPanelWidth,
    );
    expect(
      centroConAmbas.width,
      greaterThanOrEqualTo(AuthenticatedShell.contenidoMinimoComodo),
    );
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
    expect(_botonAyuda(), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await mostrarDashboard(
      tester,
      size: Size(AuthenticatedShell.anchoMinimoTresColumnas - 1, 1000),
    );

    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsNothing,
    );
    expect(_botonAyuda(), findsOneWidget);
    final centroPlegado = tester.getRect(
      find.byKey(const Key('authenticated-shell-content')),
    );
    expect(centroPlegado.width, greaterThan(centroConAmbas.width));
    expect(
      centroPlegado.width,
      greaterThanOrEqualTo(AuthenticatedShell.contenidoMinimoComodo),
    );
  });

  testWidgets('el menú pasa a Drawer solo cuando el centro necesita espacio', (
    tester,
  ) async {
    final arriba = AuthenticatedShell.anchoMinimoTresColumnas;
    for (final ancho in const [360.0, 500.0, 768.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(tester, size: Size(ancho, 1000));

      expect(
        find.byTooltip('Abrir menú'),
        findsOneWidget,
        reason: 'hamburguesa esperada a $ancho px',
      );
      expect(
        find.byKey(const Key('authenticated-shell-navigation')),
        findsNothing,
        reason: 'sin navegación fija a $ancho px',
      );
      expect(
        _botonAyuda(),
        findsOneWidget,
        reason: 'ayuda bajo demanda esperada a $ancho px',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await mostrarDashboard(tester, size: Size(arriba - 1, 1000));

    expect(find.byTooltip('Abrir menú'), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-navigation')),
      findsNothing,
    );

    for (final ancho in [arriba, 1366.0, 1720.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(tester, size: Size(ancho, 1000));

      expect(
        find.byTooltip('Abrir menú'),
        findsNothing,
        reason: 'sin hamburguesa a $ancho px',
      );
      expect(
        find.byKey(const Key('authenticated-shell-navigation')),
        findsOneWidget,
        reason: 'navegación fija esperada a $ancho px',
      );
    }
  });

  testWidgets('nunca se muestran dos ayudas contextuales a la vez', (
    tester,
  ) async {
    const panel = Key('authenticated-shell-contextual-panel');
    const expansion = Key('authenticated-shell-contextual-expansion');
    const anchos = [
      360.0,
      500.0,
      768.0,
      1049.0,
      1050.0,
      1139.0,
      1140.0,
      1200.0,
      1366.0,
      1440.0,
      1720.0,
    ];
    for (final ancho in anchos) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(tester, size: Size(ancho, 1000));

      final ayudaVisible = (find.byKey(panel).evaluate().isNotEmpty ? 1 : 0) +
          (find.byKey(expansion).evaluate().isNotEmpty ? 1 : 0);
      expect(
        ayudaVisible,
        lessThanOrEqualTo(1),
        reason: 'dos ayudas simultáneas a $ancho px',
      );
    }
  });

  testWidgets(
    'redimensionar la ventana conserva shell, provider y paso actual',
    (tester) async {
      await mostrarDashboard(
        tester,
        size: const Size(1440, 1000),
        progreso: _progresoConRubro(),
      );

      await tester.tap(_textoSidebar('Configuración'));
      await tester.pumpAndSettle();

      final proveedor = Provider.of<ConfiguracionNegocioProvider>(
        tester.element(find.byType(ConfiguracionNegocioFlow)),
        listen: false,
      );
      final pasoAntes = proveedor.pasoActual;
      final shellAntes = tester.element(find.byType(AuthenticatedShell));

      for (final ancho in const [1050, 768, 500, 1366, 1440]) {
        tester.view.physicalSize = Size(ancho.toDouble(), 1000);
        await tester.pumpAndSettle();
      }

      final proveedorDespues = Provider.of<ConfiguracionNegocioProvider>(
        tester.element(find.byType(ConfiguracionNegocioFlow)),
        listen: false,
      );
      final shellDespues = tester.element(find.byType(AuthenticatedShell));
      expect(identical(proveedorDespues, proveedor), isTrue);
      expect(proveedorDespues.pasoActual, pasoAntes);
      expect(identical(shellDespues, shellAntes), isTrue);
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el shell preserva estructura y contenido en la matriz de anchos',
    (tester) async {
      const anchos = [
        360.0,
        500.0,
        768.0,
        1050.0,
        1200.0,
        1366.0,
        1440.0,
        1720.0,
      ];
      for (final ancho in anchos) {
        await tester.pumpWidget(const SizedBox.shrink());
        await mostrarDashboard(tester, size: Size(ancho, 1000));

        final conDrawer = ancho < AuthenticatedShell.desktopBreakpoint;
        final conColumnaPanel = ancho >=
            AuthenticatedShell.navigationWidth +
                AuthenticatedShell.contextualPanelWidth +
                AuthenticatedShell.contenidoMinimoComodo;
        final centroEsperado = conDrawer
            ? ancho
            : conColumnaPanel
                ? ancho -
                    AuthenticatedShell.navigationWidth -
                    AuthenticatedShell.contextualPanelWidth
                : ancho - AuthenticatedShell.navigationWidth;

        expect(
          find.byType(AuthenticatedShell),
          findsOneWidget,
          reason: 'shell a $ancho px',
        );
        expect(find.byType(Scaffold), findsOneWidget,
            reason: 'scaffold a $ancho px');
        expect(find.text('Resumen de tu negocio'), findsOneWidget,
            reason: 'inicio a $ancho px');
        expect(
          tester
              .getRect(find.byKey(const Key('authenticated-shell-content')))
              .width,
          centroEsperado,
          reason: 'ancho del contenido a $ancho px',
        );
        expect(tester.takeException(), isNull, reason: 'overflow a $ancho px');
      }
    },
  );

  testWidgets('mantiene el shell estable con texto ampliado', (tester) async {
    await mostrarDashboard(
      tester,
      size: const Size(1050, 1000),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(find.text('Resumen de tu negocio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva un unico shell con Navigator interno e Inicio activo', (
    tester,
  ) async {
    await mostrarDashboard(tester);

    expect(find.byType(AuthenticatedShell), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(DashboardWebScreen.navegadorInicioClave), findsOneWidget);
    final shell = find.byKey(const Key('authenticated-shell'));
    expect(
      find.descendant(of: shell, matching: find.byType(Navigator)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: shell, matching: find.text('Resumen de tu negocio')),
      findsOneWidget,
    );

    final sidebar = tester.widget<DashboardSidebar>(
      find.byType(DashboardSidebar),
    );
    expect(sidebar.destinoActivo, DashboardDestination.inicio);
  });

  testWidgets(
    'Productos se abre dentro de la navegación interna sin la ruta raíz',
    (tester) async {
      final escenario = await mostrarDashboard(tester);

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(
        escenario.etapasAbiertas,
        isNot(contains(EtapaConfiguracion.productos)),
      );
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.text('Lista de productos'), findsNothing);
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.productos);
    },
  );

  testWidgets('Productos bloqueado no monta la rama ni lee dependencias', (
    tester,
  ) async {
    final escenario = await mostrarDashboard(
      tester,
      progreso: _progresoConRubro(),
    );

    await tester.tap(find.text('Productos'));
    await tester.pump();

    expect(escenario.etapasAbiertas, isEmpty);
    expect(find.byType(ProductosFlow), findsNothing);
    expect(find.byType(ProductosContent, skipOffstage: false), findsNothing);
    verifyNever(
      () => escenario.dependencias.obtenerPagina(
        negocioId: any(named: 'negocioId'),
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    );
    expect(
      find.text('Completa primero las etapas pendientes de configuración.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'la primera visita a Productos crea la rama y sus providers una sola vez',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConNegocio());

      expect(find.byType(ProductosFlow, skipOffstage: false), findsNothing);
      expect(find.byType(ProductosContent, skipOffstage: false), findsNothing);

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.byType(ProductosContent), findsOneWidget);
      expect(_leerProveedorProductos(tester), isNotNull);
      expect(_leerProveedorCatalogo(tester), isNotNull);
      expect(find.text('Café molido'), findsOneWidget);
    },
  );

  testWidgets(
    'Productos→Inicio→Productos conserva providers, lista y no relee',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.text('Café molido'), findsOneWidget);

      final proveedorProductos = _leerProveedorProductos(tester);
      final proveedorCatalogo = _leerProveedorCatalogo(tester);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsNothing);
      expect(find.text('Resumen de tu negocio'), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.text('Café molido'), findsOneWidget);

      expect(
        identical(_leerProveedorProductos(tester), proveedorProductos),
        isTrue,
      );
      expect(
        identical(_leerProveedorCatalogo(tester), proveedorCatalogo),
        isTrue,
      );

      verify(
        () => escenario.dependencias.obtenerPagina(
          negocioId: any(named: 'negocioId'),
          despuesDe: any(named: 'despuesDe'),
          limite: any(named: 'limite'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'al abrir Productos el shell, el Navigator y el provider conservan identidad',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConNegocio(),
      );

      final navegador = find.byKey(
        DashboardWebScreen.navegadorInicioClave,
        skipOffstage: false,
      );
      final estadoNavigator = tester.state<NavigatorState>(navegador);
      final shellElemento = tester.element(find.byType(AuthenticatedShell));

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(
        identical(tester.state<NavigatorState>(navegador), estadoNavigator),
        isTrue,
      );
      expect(
        identical(
          tester.element(find.byType(AuthenticatedShell)),
          shellElemento,
        ),
        isTrue,
      );
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      final elemento = tester.element(find.byType(DashboardSidebar));
      final enArbol = Provider.of<DashboardProvider>(elemento, listen: false);
      expect(identical(enArbol, escenario.provider), isTrue);
    },
  );

  testWidgets(
    'Productos usa un único panel de ayuda en el shell y restaura Inicio',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConNegocio());

      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(DashboardAttentionPanel), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsNothing);

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
      expect(find.byKey(const Key('fases-negocio-panel')), findsNothing);
      expect(find.text('¿Cómo funciona?'), findsOneWidget);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsNothing);
      expect(find.byType(ProductosContextualPanel), findsNothing);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(DashboardAttentionPanel), findsOneWidget);
    },
  );

  testWidgets(
    'en escritorio amplio Productos no muestra dos paneles de ayuda',
    (tester) async {
      await mostrarDashboard(
        tester,
        size: const Size(1720, 1000),
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(find.byKey(const Key('fases-negocio-panel')), findsNothing);
      expect(find.byKey(const Key('ayuda-productos-panel')), findsNothing);
      expect(find.text('¿Cómo funciona?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('en compacto la ayuda de Productos se abre bajo demanda', (
    tester,
  ) async {
    for (final ancho in const [500.0, 768.0, 1049.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(
        tester,
        size: Size(ancho, 1000),
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsNothing,
      );
      expect(_botonAyuda(), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsNothing);
      expect(find.byKey(const Key('fases-negocio-panel')), findsNothing);

      await _abrirAyuda(tester);

      expect(_dialogoAyuda(), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(find.text('¿Cómo funciona?').hitTestable(), findsOneWidget);

      await _cerrarAyuda(tester);

      expect(find.byType(ProductosContextualPanel), findsNothing);
      expect(_dialogoAyuda(), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('en 360 px la ayuda de Productos es accesible sin overflow', (
    tester,
  ) async {
    await mostrarDashboard(
      tester,
      size: const Size(360, 700),
      progreso: _progresoConNegocio(),
    );

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardSidebar), findsNothing);
    expect(find.byType(ProductosFlow), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsNothing,
    );
    expect(_botonAyuda(), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _abrirAyuda(tester);

    expect(_dialogoAyuda(), findsOneWidget);
    expect(find.byType(ProductosContextualPanel), findsOneWidget);
    expect(find.text('¿Cómo funciona?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en compacto la ayuda de Productos soporta texto ampliado', (
    tester,
  ) async {
    for (final escala in const [
      TextScaler.linear(1.3),
      TextScaler.linear(2.0),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(
        tester,
        size: const Size(768, 1000),
        textScaler: escala,
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(_botonAyuda(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _abrirAyuda(tester);

      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(find.text('¿Cómo funciona?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('la ayuda de Productos soporta texto ampliado en escritorio', (
    tester,
  ) async {
    for (final escala in const [
      TextScaler.linear(1.3),
      TextScaler.linear(2.0),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(
        tester,
        size: const Size(1440, 1000),
        textScaler: escala,
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'el cierre de Productos desde onVolver vuelve a Inicio sin destruir la rama',
    (tester) async {
      await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsOneWidget);

      final flujo = tester.widget<ProductosFlow>(find.byType(ProductosFlow));
      flujo.onVolver!();
      await tester.pumpAndSettle();

      expect(find.byType(ProductosFlow), findsNothing);
      expect(
        find.byType(ProductosContent, skipOffstage: false),
        findsOneWidget,
      );
      expect(_leerProveedorProductos(tester), isNotNull);
      expect(find.text('Resumen de tu negocio'), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.text('Café molido'), findsOneWidget);
    },
  );

  testWidgets(
    'el progreso reactivo desbloquea Plantilla tras completar Productos',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConNegocio(),
      );

      await tester.tap(find.byTooltip('Elegir plantilla'));
      await tester.pump();
      expect(
        find.text('Completa primero las etapas pendientes de configuración.'),
        findsOneWidget,
      );

      escenario.actualizarProgreso(_progresoConProductos());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Elegir plantilla'));
      await tester.pumpAndSettle();
      expect(find.text('Seleccion de plantilla'), findsNothing);
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(find.byKey(const Key('plantillas-wrap')), findsOneWidget);
    },
  );

  testWidgets(
    'elegir plantilla desde Productos la abre internamente y conserva Productos',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConProductos(),
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsOneWidget);

      final flujo = tester.widget<ProductosFlow>(find.byType(ProductosFlow));
      flujo.onElegirPlantilla!('Bodega');
      await tester.pumpAndSettle();

      expect(escenario.etapasAbiertas, isEmpty);
      expect(find.text('Seleccion de plantilla'), findsNothing);
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(
        find.byType(ProductosContent, skipOffstage: false),
        findsOneWidget,
      );
      expect(_leerProveedorProductos(tester), isNotNull);
      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.plantilla);
    },
  );

  testWidgets(
    'Configuración se abre dentro del Navigator interno sin usar la ruta raíz',
    (tester) async {
      final escenario = await mostrarDashboard(tester);

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      expect(
        escenario.etapasAbiertas,
        isNot(contains(EtapaConfiguracion.negocio)),
      );
      expect(find.text('Configuracion de negocio'), findsNothing);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.text('Configura tu Bodega'), findsOneWidget);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
    },
  );

  testWidgets('Configuración interna conserva un único Scaffold y el shell', (
    tester,
  ) async {
    await mostrarDashboard(tester, progreso: _progresoConRubro());

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedShell), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(find.byType(DashboardSidebar), findsOneWidget);
    expect(find.byKey(DashboardWebScreen.navegadorInicioClave), findsOneWidget);
    expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
  });

  testWidgets(
    'el shell, el Navigator y el provider conservan identidad con Configuración',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConRubro(),
      );

      final navegador = find.byKey(DashboardWebScreen.navegadorInicioClave);
      final estadoNavigator = tester.state<NavigatorState>(navegador);
      final shellElemento = tester.element(find.byType(AuthenticatedShell));

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      expect(
        identical(tester.state<NavigatorState>(navegador), estadoNavigator),
        isTrue,
      );
      expect(
        identical(
          tester.element(find.byType(AuthenticatedShell)),
          shellElemento,
        ),
        isTrue,
      );
      expect(find.byType(AuthenticatedShell), findsOneWidget);

      final elemento = tester.element(find.byType(DashboardSidebar));
      final enArbol = Provider.of<DashboardProvider>(elemento, listen: false);
      expect(identical(enArbol, escenario.provider), isTrue);
    },
  );

  testWidgets(
    'el provider de Configuración solo se crea al abrir la fase interna',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      expect(find.byType(ConfiguracionNegocioFlow), findsNothing);
      expect(
        find.byType(ChangeNotifierProvider<ConfiguracionNegocioProvider>),
        findsNothing,
      );

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(
        find.byType(ChangeNotifierProvider<ConfiguracionNegocioProvider>),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Configuración interna muestra su ayuda contextual y no el panel de Inicio',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );

      await tester.tap(_textoSidebar('Configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuracion-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(DashboardAttentionPanel), findsNothing);
    },
  );

  testWidgets(
    'volver desde Configuración interna restaura Inicio y su ayuda contextual',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      await tester.tap(find.byTooltip('Cambiar rubro'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionNegocioFlow), findsNothing);
      expect(find.text('Resumen de tu negocio'), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(DashboardAttentionPanel), findsOneWidget);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.inicio);
    },
  );

  testWidgets(
    'agregar categoría en Configuración/Catálogo conserva el flujo sin cerrar',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConNegocio());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      provider.irAPaso(1);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
      final barrerasIniciales = find.byType(ModalBarrier).evaluate().length;

      // El rótulo del botón de la cabecera también es 'Nueva categoría', así que
      // el título del formulario se busca acotado al diálogo.
      Finder tituloFormulario() => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nueva categoría'),
      );

      await tester.tap(find.byTooltip('Agregar categoría'));
      await tester.pumpAndSettle();
      expect(tituloFormulario(), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('campo-nombre-categoria')),
        'Frutos secos',
      );
      await tester.tap(find.byKey(const Key('guardar-categoria')));
      await tester.pumpAndSettle();

      expect(tituloFormulario(), findsNothing);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        barrerasIniciales,
      );
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
      // La alta va a `categoriasPersonalizadas`, no al borrador legacy.
      expect(
        provider.categoriasPersonalizadas.map((categoria) => categoria.clave),
        contains('frutos secos'),
      );
      expect(find.text('Frutos secos'), findsOneWidget);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
    },
  );

  testWidgets(
    'agregar zona en Configuración/Logística conserva el flujo sin cerrar',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConNegocio());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      provider
        ..tieneDelivery = true
        ..irAPaso(2);
      await tester.pumpAndSettle();

      expect(find.text('Zonas de delivery *'), findsOneWidget);
      final barrerasBasales = find.byType(ModalBarrier).evaluate().length;

      await tester.tap(find.text('Agregar zona de delivery'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva zona'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Zona (Ej: Centro)'),
        'Miraflores',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Costo S/'),
        '10',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva zona'), findsNothing);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        barrerasBasales,
      );
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.text('Zonas de delivery *'), findsOneWidget);
      expect(find.text('¿Ofreces delivery?'), findsOneWidget);
      expect(provider.zonasDelivery, hasLength(1));
      expect(provider.zonasDelivery.single.zona, 'Miraflores');
      expect(provider.zonasDelivery.single.costo, '10');
      expect(find.text('Miraflores'), findsOneWidget);

      await tester.tap(find.text('Agregar zona de delivery'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva zona'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva zona'), findsNothing);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        barrerasBasales,
      );
      expect(provider.zonasDelivery, hasLength(1));
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.text('Zonas de delivery *'), findsOneWidget);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
    },
  );

  testWidgets(
    'agregar horario en Configuración/Logística conserva el flujo sin cerrar',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConNegocio());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      provider.irAPaso(2);
      await tester.pumpAndSettle();

      expect(find.text('Horario de atención (opcional)'), findsOneWidget);
      final barrerasBasales = find.byType(ModalBarrier).evaluate().length;

      await tester.tap(find.text('Agregar horario'));
      await tester.pumpAndSettle();
      expect(find.text('Abierto este día'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Abierto este día'), findsNothing);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        barrerasBasales,
      );
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.text('Horario de atención (opcional)'), findsOneWidget);
      expect(provider.horarios, hasLength(1));
      expect(provider.horarios.single.dia, 'Lunes');
      expect(provider.horarios.single.activo, isTrue);
      expect(find.text('Lunes'), findsOneWidget);

      await tester.tap(find.text('Agregar horario'));
      await tester.pumpAndSettle();
      expect(find.text('Abierto este día'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Abierto este día'), findsNothing);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        barrerasBasales,
      );
      expect(provider.horarios, hasLength(1));
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.text('Horario de atención (opcional)'), findsOneWidget);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
    },
  );

  testWidgets(
    'editar el nombre del negocio en Configuración conserva el destino activo',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del negocio *'),
        'Nuevo Nombre',
      );
      await tester.pumpAndSettle();

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuracion-contextual-panel')),
        findsOneWidget,
      );

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      expect(provider.nombreNegocio, 'Nuevo Nombre');
    },
  );

  testWidgets(
    'cambiar el prefijo telefónico en Configuración conserva el destino activo',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<PaisTelefono>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+503 El Salvador').last);
      await tester.pumpAndSettle();

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      expect(provider.paisTelefono.prefijo, '+503');

      var sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuracion-contextual-panel')),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButton<PaisTelefono>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+51 Perú').last);
      await tester.pumpAndSettle();

      sidebar = tester.widget<DashboardSidebar>(find.byType(DashboardSidebar));
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
    },
  );

  testWidgets(
    'avanzar a Catálogo y Logística en Configuración conserva el destino activo',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );

      provider.irAPaso(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('seccion-sugeridas')), findsOneWidget);
      var sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);

      provider.tieneDelivery = true;
      provider.irAPaso(2);
      await tester.pumpAndSettle();
      expect(find.text('Zonas de delivery *'), findsOneWidget);
      sidebar = tester.widget<DashboardSidebar>(find.byType(DashboardSidebar));
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuracion-contextual-panel')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'editar, cambiar prefijo y avanzar pasos no recrea shell, Navigator ni providers',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConRubro(),
      );

      final navegador = find.byKey(DashboardWebScreen.navegadorInicioClave);
      final estadoNavigator = tester.state<NavigatorState>(navegador);
      final shellElemento = tester.element(find.byType(AuthenticatedShell));

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final providerConfiguracion = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del negocio *'),
        'Nuevo Nombre',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<PaisTelefono>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+503 El Salvador').last);
      await tester.pumpAndSettle();

      providerConfiguracion.irAPaso(1);
      await tester.pumpAndSettle();
      providerConfiguracion.irAPaso(2);
      await tester.pumpAndSettle();

      expect(
        identical(tester.state<NavigatorState>(navegador), estadoNavigator),
        isTrue,
      );
      expect(
        identical(
          tester.element(find.byType(AuthenticatedShell)),
          shellElemento,
        ),
        isTrue,
      );
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      final elementoFinal = tester.element(find.byType(ConfiguracionNegocioFlow));
      final providerFinal = Provider.of<ConfiguracionNegocioProvider>(
        elementoFinal,
        listen: false,
      );
      expect(identical(providerFinal, providerConfiguracion), isTrue);

      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      final enArbol = Provider.of<DashboardProvider>(
        tester.element(find.byType(DashboardSidebar)),
        listen: false,
      );
      expect(sidebar.destinoActivo, DashboardDestination.configuracion);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
      expect(identical(enArbol, escenario.provider), isTrue);
    },
  );

  testWidgets('el panel de Configuración sigue cada paso y muestra su ayuda', (
    tester,
  ) async {
    await mostrarDashboard(tester, progreso: _progresoConRubro());
    await tester.tap(_textoSidebar('Configuración'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('configuracion-contextual-panel'));
    expect(panel, findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );

    Finder enPanel(Finder interno) =>
        find.descendant(of: panel, matching: interno);

    expect(enPanel(find.text('Paso 1 de 4')), findsOneWidget);
    expect(enPanel(find.text('Negocio')), findsOneWidget);
    expect(
      enPanel(find.textContaining('Nombre, WhatsApp y dirección')),
      findsOneWidget,
    );
    expect(
      enPanel(find.textContaining('El prefijo solo indica el país del número')),
      findsOneWidget,
    );

    final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
    final provider = Provider.of<ConfiguracionNegocioProvider>(
      elemento,
      listen: false,
    );

    provider.irAPaso(1);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(enPanel(find.text('Paso 2 de 4')), findsOneWidget);
    expect(enPanel(find.text('Catálogo')), findsOneWidget);

    // Catálogo: el panel sigue la pestaña interna activa del paso.
    expect(provider.catalogoPestana, 0);
    expect(
      enPanel(find.textContaining('Las categorías organizan tus productos')),
      findsOneWidget,
    );
    expect(enPanel(find.text('Presentaciones')), findsNothing);

    provider.cambiarCatalogoPestana(1);
    await tester.pumpAndSettle();
    expect(
      enPanel(find.textContaining('el formato describe su contenido')),
      findsOneWidget,
    );
    expect(
      enPanel(find.textContaining('una botella de 650 ml')),
      findsOneWidget,
    );
    expect(enPanel(find.text('Categorías')), findsNothing);

    provider.cambiarCatalogoPestana(2);
    await tester.pumpAndSettle();
    expect(
      enPanel(find.textContaining('partes de un stock mayor')),
      findsOneWidget,
    );
    expect(
      enPanel(find.textContaining('por cantidad o por soles')),
      findsOneWidget,
    );
    expect(enPanel(find.text('Categorías')), findsNothing);

    // Cambiar de pestaña no desmonta el flujo ni reemplaza el provider.
    expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
    final elementoActual = tester.element(find.byType(ConfiguracionNegocioFlow));
    final providerActual = Provider.of<ConfiguracionNegocioProvider>(
      elementoActual,
      listen: false,
    );
    expect(identical(providerActual, provider), isTrue);

    provider.irAPaso(2);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(enPanel(find.text('Paso 3 de 4')), findsOneWidget);
    expect(enPanel(find.text('Logística')), findsOneWidget);
    expect(
      enPanel(find.textContaining('Delivery, zonas, costo fijo y horarios')),
      findsOneWidget,
    );
    expect(
      enPanel(find.textContaining('no calcula distancias ni usa GPS')),
      findsOneWidget,
    );

    provider.irAPaso(3);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(enPanel(find.text('Paso 4 de 4')), findsOneWidget);
    expect(enPanel(find.text('Pagos')), findsOneWidget);
    expect(
      enPanel(find.textContaining('métodos que el negocio acepta')),
      findsOneWidget,
    );
    expect(
      enPanel(find.textContaining('no verifica depósitos automáticamente')),
      findsOneWidget,
    );

    expect(find.byType(DashboardAttentionPanel), findsNothing);
  });

  testWidgets(
    'editar campos y cambiar el prefijo conserva la ayuda del paso',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());
      await tester.tap(_textoSidebar('Configuración'));
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('configuracion-contextual-panel'));
      Finder enPanel(Finder interno) =>
          find.descendant(of: panel, matching: interno);

      expect(enPanel(find.text('Negocio')), findsOneWidget);
      expect(
        enPanel(find.textContaining('El prefijo solo indica el país del número')),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del negocio *'),
        'Mi Negocio',
      );
      await tester.pumpAndSettle();

      expect(enPanel(find.text('Paso 1 de 4')), findsOneWidget);
      expect(enPanel(find.text('Qué registras')), findsOneWidget);
      expect(
        enPanel(find.textContaining('Nombre, WhatsApp y dirección')),
        findsOneWidget,
      );
      expect(find.byType(DashboardAttentionPanel), findsNothing);

      await tester.tap(find.byType(DropdownButton<PaisTelefono>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+503 El Salvador').last);
      await tester.pumpAndSettle();

      expect(enPanel(find.text('Paso 1 de 4')), findsOneWidget);
      expect(enPanel(find.text('Qué registras')), findsOneWidget);
      expect(
        enPanel(find.textContaining('El prefijo solo indica el país del número')),
        findsOneWidget,
      );

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      expect(provider.nombreNegocio, 'Mi Negocio');
      expect(provider.paisTelefono.prefijo, '+503');

      provider.irAPaso(1);
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(enPanel(find.text('Catálogo')), findsOneWidget);
      expect(
        enPanel(
          find.textContaining('Las categorías organizan tus productos'),
        ),
        findsOneWidget,
      );
      expect(find.byType(DashboardAttentionPanel), findsNothing);
    },
  );

  testWidgets(
    'no aparecen a la vez el panel de Configuración y el de atención',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      expect(find.byType(DashboardAttentionPanel), findsOneWidget);
      expect(find.byType(ConfiguracionContextualPanel), findsNothing);

      await tester.tap(_textoSidebar('Configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.byType(ConfiguracionContextualPanel), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      provider.irAPaso(3);
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracionContextualPanel), findsOneWidget);
      expect(find.byType(DashboardAttentionPanel), findsNothing);

      await tester.tap(find.byTooltip('Cambiar rubro'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionContextualPanel), findsNothing);
      expect(find.byType(DashboardAttentionPanel), findsOneWidget);
    },
  );

  testWidgets(
    'la ayuda de Configuración no desborda en distintos tamaños',
    (tester) async {
      for (final ancho in const [
        360,
        500,
        768,
        1049,
        1050,
        1140,
        1200,
        1366,
        1440,
        1720,
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await mostrarDashboard(
          tester,
          size: Size(ancho.toDouble(), 1000),
          progreso: _progresoConRubro(),
        );

        final conTresColumnas = ancho >= AuthenticatedShell.anchoMinimoTresColumnas;
        final anchoCentroEsperado = conTresColumnas
            ? ancho -
                  AuthenticatedShell.navigationWidth -
                  AuthenticatedShell.contextualPanelWidth
            : ancho.toDouble();

        if (!conTresColumnas) {
          await tester.tap(find.byTooltip('Abrir menú'));
          await tester.pumpAndSettle();
        }
        await tester.tap(_textoSidebar('Configuración'));
        await tester.pumpAndSettle();

        expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);

        if (conTresColumnas) {
          expect(
            find.byKey(const Key('authenticated-shell-contextual-panel')),
            findsOneWidget,
          );
          expect(_botonAyuda(), findsNothing);
        } else {
          expect(
            find.byKey(const Key('authenticated-shell-contextual-panel')),
            findsNothing,
          );
          expect(_botonAyuda(), findsOneWidget);
          await _abrirAyuda(tester);
        }

        expect(
          find.byKey(const Key('configuracion-contextual-panel')),
          findsOneWidget,
        );
        expect(
          tester
              .getRect(find.byKey(const Key('authenticated-shell-content')))
              .width,
          anchoCentroEsperado,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'la ayuda de Configuración conserva su contenido con texto ampliado',
    (tester) async {
      for (final escala in const [
        TextScaler.linear(1.0),
        TextScaler.linear(1.3),
        TextScaler.linear(2.0),
      ]) {
        final repositorio = NegocioRepository(firestore: FakeFirebaseFirestore());
        final provider = ConfiguracionNegocioProvider(
          rubro: 'Bodega',
          repository: repositorio,
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          Provider<NegocioRepository>.value(
            value: repositorio,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: escala),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: AuthenticatedShell.contextualPanelWidth,
                    child: ConfiguracionContextualPanel(provider: provider),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final panel = find.byKey(
          const Key('configuracion-contextual-panel'),
        );
        final contenidoPorPaso = <int, List<String>>{
          0: [
            'Paso 1 de 4',
            'Negocio',
            'Nombre, WhatsApp y dirección',
            'El prefijo solo indica el país del número',
          ],
          1: [
            'Paso 2 de 4',
            'Catálogo',
            'Las categorías organizan tus productos',
          ],
          2: [
            'Paso 3 de 4',
            'Logística',
            'Delivery, zonas, costo fijo y horarios',
            'no calcula distancias ni usa GPS',
          ],
          3: [
            'Paso 4 de 4',
            'Pagos',
            'métodos que el negocio acepta',
            'no verifica depósitos automáticamente',
          ],
        };
        for (final paso in contenidoPorPaso.keys) {
          provider.irAPaso(paso);
          await tester.pumpAndSettle();
          for (final texto in contenidoPorPaso[paso]!) {
            expect(
              find.descendant(
                of: panel,
                matching: find.textContaining(texto),
              ),
              findsOneWidget,
              reason: 'escala=${escala.scale(10.0)} paso=$paso texto="$texto"',
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: 'escala=${escala.scale(10.0)} paso=$paso',
          );
        }

        // Catálogo: cada pestaña del paso muestra su propia tarjeta.
        provider.irAPaso(1);
        await tester.pumpAndSettle();
        final pestanas = <int, String>{
          0: 'Las categorías organizan tus productos',
          1: 'el formato describe su contenido',
          2: 'partes de un stock mayor',
        };
        for (final entry in pestanas.entries) {
          provider.cambiarCatalogoPestana(entry.key);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: panel,
              matching: find.textContaining(entry.value),
            ),
            findsOneWidget,
            reason: 'escala=${escala.scale(10.0)} pestana=${entry.key} '
                'texto="${entry.value}"',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'escala=${escala.scale(10.0)} pestana=${entry.key}',
          );
        }
      }
    },
  );

  testWidgets(
    'guardar desde Configuración interna recarga el progreso y desbloquea Productos',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
        'negocioId': 'negocio-1',
      });
      final repositorio = NegocioRepository(firestore: firestore);

      late _EscenarioDashboard escenario;
      escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConRubro(),
        repositorio: repositorio,
        recargarProgreso: () async {
          final datos =
              (await firestore.collection('negocios').doc('negocio-1').get())
                  .data() ??
              const <String, dynamic>{};
          escenario.actualizarProgreso(_progresoPostGuardado(datos));
        },
      );

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      final elemento = tester.element(find.byType(ConfiguracionNegocioFlow));
      final provider = Provider.of<ConfiguracionNegocioProvider>(
        elemento,
        listen: false,
      );
      provider
        ..nombreNegocio = 'Bodega Ana'
        ..telefono = '999999999'
        ..direccion = 'Av. Lima 123'
        ..referencia = 'Frente al parque'
        ..irAPaso(3);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionNegocioFlow), findsNothing);
      expect(find.text('Resumen de tu negocio'), findsOneWidget);

      await tester.tap(find.byTooltip('Elegir plantilla'));
      await tester.pump();
      expect(
        find.text('Completa primero las etapas pendientes de configuración.'),
        findsOneWidget,
      );
      expect(escenario.etapasAbiertas, isEmpty);

      await tester.tap(find.text('Productos').first);
      await tester.pumpAndSettle();
      expect(
        escenario.etapasAbiertas,
        isNot(contains(EtapaConfiguracion.productos)),
      );
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.text('Lista de productos'), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
    },
  );

  testWidgets('el Rubro interno conserva shell, provider y un único Scaffold', (
    tester,
  ) async {
    final escenario = await mostrarDashboard(
      tester,
      progreso: _progresoPendiente(),
    );

    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedShell), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(find.byType(DashboardSidebar), findsOneWidget);
    expect(find.byKey(DashboardWebScreen.navegadorInicioClave), findsOneWidget);
    expect(find.byType(SeleccionNegocioFlow), findsOneWidget);

    final elemento = tester.element(find.byType(DashboardSidebar));
    final enArbol = Provider.of<DashboardProvider>(elemento, listen: false);
    expect(identical(enArbol, escenario.provider), isTrue);

    final sidebar = tester.widget<DashboardSidebar>(
      find.byType(DashboardSidebar),
    );
    expect(sidebar.destinoActivo, DashboardDestination.inicio);
  });

  testWidgets('Rubro muestra su panel contextual y oculta el de Inicio', (
    tester,
  ) async {
    await mostrarDashboard(tester, progreso: _progresoPendiente());

    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
    expect(find.byType(RubroContextualPanel), findsNothing);
    expect(find.byType(DashboardAttentionPanel), findsOneWidget);

    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
    expect(find.byType(RubroContextualPanel), findsOneWidget);
    expect(find.byType(DashboardAttentionPanel), findsNothing);
    expect(find.text('Necesita tu atención'), findsNothing);
    expect(find.text('Sirve para'), findsOneWidget);
    expect(find.text('Medidas sugeridas'), findsOneWidget);
    expect(find.text('No incluye'), findsOneWidget);
  });

  testWidgets('el panel derecho sigue exclusivamente el rubro seleccionado', (
    tester,
  ) async {
    await mostrarDashboard(
      tester,
      size: const Size(1440, 1000),
      progreso: _progresoPendiente(),
    );
    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Crear un catálogo básico de productos'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('rubro-card-Bodega')));
    await tester.pump();
    expect(
      find.textContaining('Organizar productos vendidos por unidad, peso'),
      findsOneWidget,
    );
    expect(find.byType(ProductosContextualPanel), findsNothing);

    await tester.tap(find.byKey(const Key('rubro-card-Restaurante')));
    await tester.pump();
    expect(
      find.textContaining('Organizar una carta de comidas y bebidas'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Organizar productos vendidos por unidad, peso'),
      findsNothing,
    );
  });

  testWidgets(
    'volver desde Rubro interno regresa a Inicio y restaura la ayuda',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoPendiente());

      await tester.tap(find.text('Continuar configuración'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionNegocioFlow), findsOneWidget);

      await tester.tap(find.byTooltip('Volver al dashboard'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionNegocioFlow), findsNothing);
      expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);
      expect(find.text('Resumen de tu negocio'), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(RubroContextualPanel), findsNothing);
      expect(find.byType(DashboardAttentionPanel), findsOneWidget);
      expect(find.text('Necesita tu atención'), findsOneWidget);
    },
  );

  testWidgets('Inicio muestra el panel de atención y oculta el de Rubro', (
    tester,
  ) async {
    await mostrarDashboard(tester);

    expect(find.byType(DashboardAttentionPanel), findsOneWidget);
    expect(find.byType(RubroContextualPanel), findsNothing);
  });

  testWidgets('la ayuda de Rubro usa el panel derecho en escritorio', (
    tester,
  ) async {
    for (final ancho in const [1200.0, 1440.0]) {
      await mostrarDashboard(
        tester,
        size: Size(ancho, 1000),
        progreso: _progresoPendiente(),
      );

      await tester.tap(find.text('Continuar configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(RubroContextualPanel), findsOneWidget);
      expect(find.text('Ayuda contextual'), findsNothing);

      await tester.tap(find.byTooltip('Volver al dashboard'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('en compacto la ayuda de Rubro se abre bajo demanda', (
    tester,
  ) async {
    for (final ancho in const [500.0, 768.0, 1049.0]) {
      await mostrarDashboard(
        tester,
        size: Size(ancho, 1000),
        progreso: _progresoPendiente(),
      );

      await tester.tap(find.text('Continuar configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsNothing,
      );
      expect(_botonAyuda(), findsOneWidget);
      expect(find.byType(RubroContextualPanel), findsNothing);
      expect(find.text('Necesita tu atención'), findsNothing);

      await _abrirAyuda(tester);

      expect(_dialogoAyuda(), findsOneWidget);
      expect(find.byType(RubroContextualPanel), findsOneWidget);
      expect(find.text('Sirve para').hitTestable(), findsOneWidget);
      expect(find.text('Necesita tu atención'), findsNothing);

      await _cerrarAyuda(tester);

      expect(find.byType(RubroContextualPanel), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Volver al dashboard'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('en 360 px la ayuda de Rubro es accesible sin overflow', (
    tester,
  ) async {
    await mostrarDashboard(
      tester,
      size: const Size(360, 700),
      progreso: _progresoPendiente(),
    );

    await tester.ensureVisible(find.text('Continuar configuración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsNothing,
    );
    expect(_botonAyuda(), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _abrirAyuda(tester);

    expect(find.byType(RubroContextualPanel), findsOneWidget);
    expect(find.text('Sirve para'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la ayuda de Rubro soporta texto ampliado sin overflow', (
    tester,
  ) async {
    await mostrarDashboard(
      tester,
      size: const Size(1440, 1000),
      textScaler: const TextScaler.linear(1.3),
      progreso: _progresoPendiente(),
    );

    await tester.ensureVisible(find.text('Continuar configuración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(find.byType(RubroContextualPanel), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Volver al dashboard'));
    await tester.pumpAndSettle();
  });

  testWidgets('el panel de Rubro se mantiene sin overflow a escala 1.3 y 2.0', (
    tester,
  ) async {
    for (final escala in const [
      TextScaler.linear(1.3),
      TextScaler.linear(2.0),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: escala),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: AuthenticatedShell.contextualPanelWidth,
                    child: RubroContextualPanel(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RubroContextualPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('una etapa bloqueada no monta el flow de Rubro', (tester) async {
    final escenario = await mostrarDashboard(
      tester,
      progreso: _progresoPendiente(),
    );

    await tester.tap(find.text('Agregar productos').first);
    await tester.pump();

    expect(escenario.etapasAbiertas, isEmpty);
    expect(find.byType(SeleccionNegocioFlow), findsNothing);
    expect(find.text('Lista de productos'), findsNothing);
    expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);
  });

  testWidgets(
    'el Navigator interno conserva identidad y refleja el nuevo progreso',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoPendiente(),
      );

      final navegador = find.byKey(DashboardWebScreen.navegadorInicioClave);
      final estadoNavigator = tester.state<NavigatorState>(navegador);
      final shellElemento = tester.element(find.byType(AuthenticatedShell));

      expect(find.text('Requiere un rubro guardado.'), findsOneWidget);

      escenario.actualizarProgreso(_progresoConRubro());
      await tester.pumpAndSettle();

      expect(
        identical(tester.state<NavigatorState>(navegador), estadoNavigator),
        isTrue,
      );
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(
        identical(
          tester.element(find.byType(AuthenticatedShell)),
          shellElemento,
        ),
        isTrue,
      );
      expect(find.byType(Scaffold), findsOneWidget);

      final elemento = tester.element(find.byType(DashboardSidebar));
      final enArbol = Provider.of<DashboardProvider>(elemento, listen: false);
      expect(identical(enArbol, escenario.provider), isTrue);

      expect(find.text('Requiere un rubro guardado.'), findsNothing);
      expect(find.text('Siguiente etapa pendiente.'), findsOneWidget);
      expect(find.text('Completado. Puedes revisarlo.'), findsOneWidget);
    },
  );

  testWidgets(
    'el progreso reactivo desbloquea Configuración y mantiene bloqueos',
    (tester) async {
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoPendiente(),
      );

      escenario.actualizarProgreso(_progresoConRubro());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(
        escenario.etapasAbiertas,
        isNot(contains(EtapaConfiguracion.negocio)),
      );
      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(find.text('Configuracion de negocio'), findsNothing);

      await tester.tap(find.byTooltip('Cambiar rubro'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-setup-panel')), findsOneWidget);

      await tester.tap(find.text('Productos').first);
      await tester.pump();
      expect(
        escenario.etapasAbiertas,
        isNot(contains(EtapaConfiguracion.productos)),
      );
      expect(
        find.text('Completa primero las etapas pendientes de configuración.'),
        findsOneWidget,
      );
      expect(find.text('Lista de productos'), findsNothing);

      await tester.tap(find.byTooltip('Elegir plantilla'));
      await tester.pump();
      expect(
        escenario.etapasAbiertas,
        isNot(contains(EtapaConfiguracion.plantilla)),
      );
      expect(
        find.text('Completa primero las etapas pendientes de configuración.'),
        findsOneWidget,
      );
      expect(find.text('Seleccion de plantilla'), findsNothing);
    },
  );

  testWidgets('el contenido reconstruido conserva el mismo DashboardProvider', (
    tester,
  ) async {
    final escenario = await mostrarDashboard(tester);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    final elemento = tester.element(find.byType(DashboardSidebar));
    final enArbol = Provider.of<DashboardProvider>(elemento, listen: false);
    expect(identical(enArbol, escenario.provider), isTrue);
    expect(
      find.text(
        'Resumen de mes · gráfico con referencia de los últimos 7 días.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'bloquea Productos, Configuración y Plantilla sin montar sus pantallas',
    (tester) async {
      final escenario = await mostrarDashboard(
        tester,
        progreso: _progresoPendiente(),
      );

      await tester.tap(find.text('Productos').first);
      await tester.pump();
      await tester.tap(find.text('Configuración').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Elegir plantilla'));
      await tester.pump();

      expect(escenario.etapasAbiertas, isEmpty);
      expect(
        find.text('Completa primero las etapas pendientes de configuración.'),
        findsOneWidget,
      );
      expect(find.text('Lista de productos'), findsNothing);
      expect(find.byType(ConfiguracionNegocioFlow), findsNothing);
      expect(find.text('Configuracion de negocio'), findsNothing);
      expect(
        find.byType(ChangeNotifierProvider<ConfiguracionNegocioProvider>),
        findsNothing,
      );
      expect(find.text('Seleccion de plantilla'), findsNothing);
      expect(
        find.byType(SeleccionPlantillaFlow, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(ChangeNotifierProvider<SeleccionPlantillaProvider>),
        findsNothing,
      );
      verifyNever(
        () => escenario.dependenciasPlantilla.obtenerSeleccion(any()),
      );
      expect(
        find.byType(ChangeNotifierProvider<DashboardProvider>),
        findsOneWidget,
      );
      expect(
        find.byKey(DashboardWebScreen.navegadorInicioClave),
        findsOneWidget,
      );
      expect(find.text('Resumen de tu negocio'), findsOneWidget);
    },
  );

  testWidgets(
    'la rama de Plantilla nace perezosa y conserva provider y selección',
    (tester) async {
      final escenario = await mostrarDashboard(
        tester,
        progreso: _progresoConProductos(),
      );

      expect(
        find.byType(SeleccionPlantillaFlow, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(
          ChangeNotifierProvider<SeleccionPlantillaProvider>,
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(find.byType(ProductosFlow, skipOffstage: false), findsNothing);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      final provider1 = _leerProveedorPlantilla(tester);

      await tester.tap(find.byKey(const Key('plantilla-card-galeria')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsNothing);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(identical(_leerProveedorPlantilla(tester), provider1), isTrue);

      final provider2 = _leerProveedorPlantilla(tester);
      expect(provider2.cargado, isTrue);
      expect(provider2.cargando, isFalse);
      expect(provider2.seleccionTemporal, PlantillaWeb.galeria);
      verifyNever(
        () => escenario.dependenciasPlantilla.obtenerSeleccion(any()),
      );
    },
  );

  testWidgets(
    'alternar entre Productos y Plantilla conserva ambas ramas vivas',
    (tester) async {
      await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConProductos(),
      );

      expect(find.byType(ProductosFlow, skipOffstage: false), findsNothing);
      expect(
        find.byType(SeleccionPlantillaFlow, skipOffstage: false),
        findsNothing,
      );

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      final productos1 = _leerProveedorProductos(tester);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      final plantilla1 = _leerProveedorPlantilla(tester);

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(identical(_leerProveedorProductos(tester), productos1), isTrue);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(identical(_leerProveedorPlantilla(tester), plantilla1), isTrue);
    },
  );

  testWidgets('onVolver desde Plantilla regresa a Productos sin recrearlo', (
    tester,
  ) async {
    final escenario = await mostrarDashboardConProgresoActualizable(
      tester,
      progreso: _progresoCompleto(),
    );

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();
    final productos1 = _leerProveedorProductos(tester);

    await tester.tap(_textoSidebar('Plantilla web'));
    await tester.pumpAndSettle();
    expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);

    await tester.tap(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionPlantillaFlow), findsNothing);
    expect(find.byType(ProductosFlow), findsOneWidget);
    expect(identical(_leerProveedorProductos(tester), productos1), isTrue);
    verify(
      () => escenario.dependencias.obtenerPagina(
        negocioId: 'negocio-1',
        despuesDe: any(named: 'despuesDe'),
        limite: any(named: 'limite'),
      ),
    ).called(1);
  });

  testWidgets(
    'Guardar recarga el progreso y Finalizar vuelve a Inicio sin desmontar',
    (tester) async {
      late void Function(ProgresoConfiguracion) actualizar;
      final escenario = await mostrarDashboardConProgresoActualizable(
        tester,
        progreso: _progresoConProductos(),
        recargarProgreso: () async {
          actualizar(_progresoCompleto());
        },
      );
      actualizar = escenario.actualizarProgreso;

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plantilla-card-galeria')));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);

      await tester.tap(find.byKey(const Key('guardar-plantilla')));
      await tester.pumpAndSettle();

      expect(
        verify(
          () => escenario.dependenciasPlantilla.guardarPlantilla(
            'usuario-1',
            PlantillaWeb.galeria,
          ),
        ).callCount,
        1,
      );
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);

      await tester.tap(find.byKey(const Key('finalizar-plantilla')));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionPlantillaFlow), findsNothing);
      expect(find.text('Resumen de tu negocio'), findsOneWidget);
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(
        find.byKey(DashboardWebScreen.navegadorInicioClave),
        findsOneWidget,
      );
      expect(
        find.byType(ChangeNotifierProvider<DashboardProvider>),
        findsOneWidget,
      );
      final sidebar = tester.widget<DashboardSidebar>(
        find.byType(DashboardSidebar),
      );
      expect(sidebar.destinoActivo, DashboardDestination.inicio);
    },
  );

  testWidgets(
    'Plantilla interna conserva un único Scaffold, shell, Navigator y provider',
    (tester) async {
      final escenario = await mostrarDashboard(tester);

      final navegador = find.byKey(
        DashboardWebScreen.navegadorInicioClave,
        skipOffstage: false,
      );
      final estadoNavigator = tester.state<NavigatorState>(navegador);
      final shellElemento = tester.element(find.byType(AuthenticatedShell));

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(DashboardTopBar), findsOneWidget);
      expect(find.byType(DashboardSidebar), findsOneWidget);
      expect(
        find.byKey(
          DashboardWebScreen.navegadorInicioClave,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byType(ChangeNotifierProvider<DashboardProvider>),
        findsOneWidget,
      );
      expect(
        identical(tester.state<NavigatorState>(navegador), estadoNavigator),
        isTrue,
      );
      expect(
        identical(
          tester.element(find.byType(AuthenticatedShell)),
          shellElemento,
        ),
        isTrue,
      );
      final elementoArbol = tester.element(find.byType(DashboardSidebar));
      expect(
        identical(
          Provider.of<DashboardProvider>(elementoArbol, listen: false),
          escenario.provider,
        ),
        isTrue,
      );
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsNothing);
      expect(find.byType(DashboardAttentionPanel), findsNothing);
    },
  );

  testWidgets('Plantilla muestra su panel contextual y oculta el de Inicio', (
    tester,
  ) async {
    await mostrarDashboard(tester);

    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
    expect(find.byType(PlantillaContextualPanel), findsNothing);
    expect(find.byType(DashboardAttentionPanel), findsOneWidget);

    await tester.tap(_textoSidebar('Plantilla web'));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
    expect(find.byType(PlantillaContextualPanel), findsOneWidget);
    expect(find.byType(DashboardAttentionPanel), findsNothing);
    expect(find.byType(ProductosContextualPanel), findsNothing);
    expect(find.byType(RubroContextualPanel), findsNothing);
    expect(find.text('Qué hace Finalizar'), findsOneWidget);
    expect(find.text('Necesita tu atención'), findsNothing);
  });

  testWidgets('Plantilla no duplica la ayuda contextual en escritorio amplio', (
    tester,
  ) async {
    await mostrarDashboard(tester, size: const Size(1720, 1000));

    await tester.tap(_textoSidebar('Plantilla web'));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
    expect(find.byType(PlantillaContextualPanel), findsOneWidget);
    expect(find.byType(ProductosContextualPanel), findsNothing);
    expect(find.byType(RubroContextualPanel), findsNothing);
    expect(find.byType(DashboardAttentionPanel), findsNothing);
    expect(find.byKey(const Key('fases-negocio-panel')), findsNothing);
    expect(find.text('¿Cómo funciona?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'volver desde Plantilla a Productos restaura el panel de Productos',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoCompleto());

      await tester.tap(find.text('Productos'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsNothing);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      expect(find.byType(ProductosContextualPanel), findsNothing);

      await tester.tap(find.byKey(const Key('ir-dashboard-plantilla')));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionPlantillaFlow), findsNothing);
      expect(find.byType(ProductosFlow), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsNothing);
      expect(find.byType(ProductosContextualPanel), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
    },
  );

  testWidgets('volver a Inicio desde Plantilla restaura el panel de atención', (
    tester,
  ) async {
    await mostrarDashboard(tester);

    await tester.tap(_textoSidebar('Plantilla web'));
    await tester.pumpAndSettle();
    expect(find.byType(PlantillaContextualPanel), findsOneWidget);
    expect(find.byType(DashboardAttentionPanel), findsNothing);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionPlantillaFlow), findsNothing);
    expect(find.byType(PlantillaContextualPanel), findsNothing);
    expect(find.byType(DashboardAttentionPanel), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );
  });

  testWidgets('la ayuda de Plantilla usa el panel derecho en escritorio', (
    tester,
  ) async {
    for (final ancho in const [1200.0, 1440.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(tester, size: Size(ancho, 1000));

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      expect(find.text('Ayuda contextual'), findsNothing);
    }
  });

  testWidgets('en compacto la ayuda de Plantilla se abre bajo demanda', (
    tester,
  ) async {
    for (final ancho in const [500.0, 768.0, 1049.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(tester, size: Size(ancho, 1000));

      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsNothing,
      );
      expect(_botonAyuda(), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsNothing);

      await _abrirAyuda(tester);

      expect(_dialogoAyuda(), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      expect(find.text('Qué hace Finalizar'), findsOneWidget);

      await _cerrarAyuda(tester);

      expect(find.byType(PlantillaContextualPanel), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('en 360 px la ayuda de Plantilla es accesible sin overflow', (
    tester,
  ) async {
    await mostrarDashboard(tester, size: const Size(360, 700));

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await tester.tap(_textoSidebar('Plantilla web'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardSidebar), findsNothing);
    expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsNothing,
    );
    expect(_botonAyuda(), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _abrirAyuda(tester);

    expect(find.byType(PlantillaContextualPanel), findsOneWidget);
    expect(find.text('Qué hace Finalizar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la ayuda de Plantilla soporta texto ampliado sin overflow', (
    tester,
  ) async {
    for (final escala in const [
      TextScaler.linear(1.3),
      TextScaler.linear(2.0),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarDashboard(
        tester,
        size: const Size(1440, 1000),
        textScaler: escala,
      );

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();

      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'el panel de Plantilla se mantiene sin overflow a escala 1.3 y 2.0',
    (tester) async {
      for (final escala in const [
        TextScaler.linear(1.3),
        TextScaler.linear(2.0),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: escala),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: SizedBox(
                      width: AuthenticatedShell.contextualPanelWidth,
                      child: PlantillaContextualPanel(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlantillaContextualPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Plantilla conserva Flow y provider sin recargar al alternar su panel',
    (tester) async {
      final escenario = await mostrarDashboard(tester);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      final provider1 = _leerProveedorPlantilla(tester);

      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(PlantillaContextualPanel), findsNothing);
      expect(find.byType(DashboardAttentionPanel), findsOneWidget);

      await tester.tap(_textoSidebar('Plantilla web'));
      await tester.pumpAndSettle();
      expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
      expect(find.byType(PlantillaContextualPanel), findsOneWidget);
      expect(identical(_leerProveedorPlantilla(tester), provider1), isTrue);
      expect(_leerProveedorPlantilla(tester).cargado, isTrue);
      verifyNever(
        () => escenario.dependenciasPlantilla.obtenerSeleccion(any()),
      );
    },
  );

  testWidgets('onVerTienda desde Plantilla conserva la apertura de la tienda', (
    tester,
  ) async {
    final escenario = await mostrarDashboard(tester);

    await tester.tap(_textoSidebar('Plantilla web'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ver-tienda-plantilla')));
    await tester.pumpAndSettle();

    expect(escenario.abridor.llamadas, 1);
    expect(
      escenario.abridor.ultimaUrl,
      Uri.parse('https://yapiventa-tienda.web.app/mi-tienda'),
    );
    expect(escenario.abridor.ultimoDestino, '_blank');
  });
}

class _EscenarioDashboard {
  final _AbridorFake abridor;
  final List<EtapaConfiguracion> etapasAbiertas;
  final DashboardProvider provider;
  final _DependenciasProductos dependencias;
  final _DependenciasPlantilla dependenciasPlantilla;
  final void Function(ProgresoConfiguracion progreso) actualizarProgreso;

  const _EscenarioDashboard({
    required this.abridor,
    required this.etapasAbiertas,
    required this.provider,
    required this.dependencias,
    required this.dependenciasPlantilla,
    this.actualizarProgreso = _sinActualizar,
  });
}

class _EstadoProgresoRecargable extends StatefulWidget {
  final ProgresoConfiguracion progreso;
  final Widget Function(BuildContext context, ProgresoConfiguracion progreso)
  builder;

  const _EstadoProgresoRecargable({
    super.key,
    required this.progreso,
    required this.builder,
  });

  @override
  State<_EstadoProgresoRecargable> createState() =>
      _EstadoProgresoRecargableState();
}

class _EstadoProgresoRecargableState extends State<_EstadoProgresoRecargable> {
  late ProgresoConfiguracion _progreso = widget.progreso;

  void actualizarProgreso(ProgresoConfiguracion nuevo) {
    setState(() => _progreso = nuevo);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progreso);
}

void _sinActualizar(ProgresoConfiguracion progreso) {}

ProductosProvider _leerProveedorProductos(WidgetTester tester) {
  final elemento = tester.element(
    find.byType(ProductosContent, skipOffstage: false).first,
  );
  return Provider.of<ProductosProvider>(elemento, listen: false);
}

CatalogoNegocioProvider _leerProveedorCatalogo(WidgetTester tester) {
  final elemento = tester.element(
    find.byType(ProductosContent, skipOffstage: false).first,
  );
  return Provider.of<CatalogoNegocioProvider>(elemento, listen: false);
}

SeleccionPlantillaProvider _leerProveedorPlantilla(WidgetTester tester) {
  final elemento = tester.element(
    find.byType(SeleccionPlantillaContent, skipOffstage: false).first,
  );
  return Provider.of<SeleccionPlantillaProvider>(elemento, listen: false);
}

Finder _textoSidebar(String texto) => find
    .descendant(of: find.byType(DashboardSidebar), matching: find.text(texto))
    .first;

/// Acción pequeña de la barra superior que abre la ayuda contextual cuando no
/// hay panel fijo. Antes era un ExpansionTile encima del contenido.
Finder _botonAyuda() => find.byKey(AuthenticatedShell.helpButtonKey);

Finder _dialogoAyuda() => find.byKey(AuthenticatedShell.helpDialogKey);

Future<void> _abrirAyuda(WidgetTester tester) async {
  await tester.tap(_botonAyuda());
  await tester.pumpAndSettle();
}

Future<void> _cerrarAyuda(WidgetTester tester) async {
  await tester.tapAt(const Offset(8, 8));
  await tester.pumpAndSettle();
}

class _DependenciasPlantilla {
  final SeleccionPlantillaDependencies seleccionPlantilla;
  final _ObtenerSeleccionPlantillaMock obtenerSeleccion;
  final _GuardarPlantillaWebMock guardarPlantilla;

  const _DependenciasPlantilla({
    required this.seleccionPlantilla,
    required this.obtenerSeleccion,
    required this.guardarPlantilla,
  });
}

_DependenciasPlantilla _crearDependenciasPlantillaTest() {
  final obtenerSeleccion = _ObtenerSeleccionPlantillaMock();
  final guardarPlantilla = _GuardarPlantillaWebMock();
  when(() => obtenerSeleccion(any())).thenAnswer(
    (_) async => const SeleccionPlantillaInfo(
      slug: '',
      plantillaGuardada: null,
      provieneDeCampoOficial: false,
    ),
  );
  when(() => guardarPlantilla(any(), any())).thenAnswer((_) async {});

  return _DependenciasPlantilla(
    seleccionPlantilla: SeleccionPlantillaDependencies(
      obtenerSeleccionPlantilla: obtenerSeleccion,
      guardarPlantillaWeb: guardarPlantilla,
    ),
    obtenerSeleccion: obtenerSeleccion,
    guardarPlantilla: guardarPlantilla,
  );
}

class _ObtenerSeleccionPlantillaMock extends Mock
    implements ObtenerSeleccionPlantilla {}

class _GuardarPlantillaWebMock extends Mock implements GuardarPlantillaWeb {}

class _DependenciasProductos {
  final ProductosDependencies productos;
  final CatalogoNegocioDependencies catalogo;
  final _ObtenerPaginaProductosMock obtenerPagina;
  final _CambiarDisponibilidadMock cambiarDisponibilidad;
  final _EliminarProductoMock eliminarProducto;

  const _DependenciasProductos({
    required this.productos,
    required this.catalogo,
    required this.obtenerPagina,
    required this.cambiarDisponibilidad,
    required this.eliminarProducto,
  });
}

_DependenciasProductos _crearDependenciasTest() {
  final obtenerPagina = _ObtenerPaginaProductosMock();
  final cambiarDisponibilidad = _CambiarDisponibilidadMock();
  final eliminarProducto = _EliminarProductoMock();
  final obtenerCatalogo = _ObtenerCatalogoNegocioMock();
  final productos = _ProductosDependenciesMock();
  final catalogo = _CatalogoNegocioDependenciesMock();

  when(
    () => obtenerPagina(
      negocioId: any(named: 'negocioId'),
      despuesDe: any(named: 'despuesDe'),
      limite: any(named: 'limite'),
    ),
  ).thenAnswer(
    (_) async => PaginaProductos(
      productos: [
        Producto(
          id: 'producto-1',
          negocioId: 'negocio-1',
          nombre: 'Café molido',
          precio: 18.5,
          stock: 12,
          categoria: 'Bebidas',
          unidadMedidaNombre: 'Unidad',
        ),
      ],
      ultimoCursor: null,
      hayMas: false,
    ),
  );
  when(
    () => cambiarDisponibilidad(
      negocioId: any(named: 'negocioId'),
      productoId: any(named: 'productoId'),
      disponible: any(named: 'disponible'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => eliminarProducto(
      negocioId: any(named: 'negocioId'),
      productoId: any(named: 'productoId'),
    ),
  ).thenAnswer((_) async {});
  when(() => productos.obtenerPaginaProductos).thenReturn(obtenerPagina);
  when(
    () => productos.cambiarDisponibilidadProducto,
  ).thenReturn(cambiarDisponibilidad);
  when(() => productos.crearProducto).thenReturn(_CrearProductoMock());
  when(() => productos.editarProducto).thenReturn(_EditarProductoMock());
  when(() => productos.eliminarProducto).thenReturn(eliminarProducto);
  when(() => catalogo.obtenerCatalogoNegocio).thenReturn(obtenerCatalogo);

  return _DependenciasProductos(
    productos: productos,
    catalogo: catalogo,
    obtenerPagina: obtenerPagina,
    cambiarDisponibilidad: cambiarDisponibilidad,
    eliminarProducto: eliminarProducto,
  );
}

class _ProductosDependenciesMock extends Mock
    implements ProductosDependencies {}

class _CatalogoNegocioDependenciesMock extends Mock
    implements CatalogoNegocioDependencies {}

class _ObtenerCatalogoNegocioMock extends Mock
    implements ObtenerCatalogoNegocio {}

class _ObtenerPaginaProductosMock extends Mock
    implements ObtenerPaginaProductos {}

class _CambiarDisponibilidadMock extends Mock
    implements CambiarDisponibilidadProducto {}

class _CrearProductoMock extends Mock implements CrearProducto {}

class _EditarProductoMock extends Mock implements EditarProducto {}

class _EliminarProductoMock extends Mock implements EliminarProducto {}

class _AbridorFake {
  final bool resultado;
  final Object? error;
  int llamadas = 0;
  Uri? ultimaUrl;
  String? ultimoDestino;

  _AbridorFake({required this.resultado, this.error});

  Future<bool> call(Uri url, {String? webOnlyWindowName}) async {
    llamadas++;
    ultimaUrl = url;
    ultimoDestino = webOnlyWindowName;
    if (error != null) throw error!;
    return resultado;
  }
}

ProgresoConfiguracion _progresoCompleto() => ProgresoConfiguracion(
  catalogo: CatalogoNegocio(
    rubro: 'Bodega',
    categorias: const ['Bebidas'],
    unidadesMedida: const [],
  ),
  slug: 'mi-tienda',
  plantilla: PlantillaWeb.cristal,
  plantillaProvieneDeCampoOficial: true,
  rubroCompleto: true,
  negocioCompleto: true,
  productosCompletos: true,
  setupCompletePersistido: true,
  productosConfirmadosPersistidos: true,
);

ProgresoConfiguracion _progresoPendiente() => ProgresoConfiguracion(
  catalogo: CatalogoNegocio(
    rubro: '',
    categorias: const [],
    unidadesMedida: const [],
  ),
  slug: '',
  plantilla: null,
  plantillaProvieneDeCampoOficial: false,
  rubroCompleto: false,
  negocioCompleto: false,
  productosCompletos: false,
  setupCompletePersistido: false,
  productosConfirmadosPersistidos: false,
);

ProgresoConfiguracion _progresoConRubro() => ProgresoConfiguracion(
  catalogo: CatalogoNegocio(
    rubro: 'Bodega',
    categorias: const ['Bebidas'],
    unidadesMedida: const [],
  ),
  slug: '',
  plantilla: null,
  plantillaProvieneDeCampoOficial: false,
  rubroCompleto: true,
  negocioCompleto: false,
  productosCompletos: false,
  setupCompletePersistido: false,
  productosConfirmadosPersistidos: false,
);

ProgresoConfiguracion _progresoConNegocio() => ProgresoConfiguracion(
  catalogo: CatalogoNegocio(
    rubro: 'Bodega',
    categorias: const ['Bebidas'],
    unidadesMedida: const [],
  ),
  slug: '',
  plantilla: null,
  plantillaProvieneDeCampoOficial: false,
  rubroCompleto: true,
  negocioCompleto: true,
  productosCompletos: false,
  setupCompletePersistido: false,
  productosConfirmadosPersistidos: false,
);

ProgresoConfiguracion _progresoConProductos() => ProgresoConfiguracion(
  catalogo: CatalogoNegocio(
    rubro: 'Bodega',
    categorias: const ['Bebidas'],
    unidadesMedida: const [],
  ),
  slug: '',
  plantilla: null,
  plantillaProvieneDeCampoOficial: false,
  rubroCompleto: true,
  negocioCompleto: true,
  productosCompletos: true,
  setupCompletePersistido: false,
  productosConfirmadosPersistidos: false,
);

ProgresoConfiguracion _progresoPostGuardado(Map<String, dynamic> datos) =>
    ProgresoConfiguracion(
      catalogo: CatalogoNegocio(
        rubro: datos['rubro'] is String ? datos['rubro'] as String : 'Bodega',
        categorias:
            (datos['categorias'] as List?)?.cast<String>() ?? const ['Bebidas'],
        unidadesMedida: const [],
        configuracionInicial: datos,
      ),
      slug: datos['slug'] is String ? (datos['slug'] as String).trim() : '',
      plantilla: null,
      plantillaProvieneDeCampoOficial: false,
      rubroCompleto: true,
      negocioCompleto: true,
      productosCompletos: false,
      setupCompletePersistido: datos['setupComplete'] == true,
      productosConfirmadosPersistidos: false,
    );
