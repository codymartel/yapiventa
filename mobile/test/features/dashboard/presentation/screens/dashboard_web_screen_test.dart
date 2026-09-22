import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/authenticated_shell.dart';
import 'package:mobile/features/auth/domain/politica_acceso.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_attention_panel.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_top_bar.dart';
import 'package:mobile/features/dashboard/presentation/widgets/rubro_contextual_panel.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/catalogo_negocio_dependencies.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/presentation/providers/catalogo_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_flow.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_negocio_flow.dart';
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
  Future<_EscenarioDashboard> mostrarDashboard(
    WidgetTester tester, {
    bool resultado = true,
    Object? error,
    ProgresoConfiguracion? progreso,
    NegocioRepository? repositorio,
    _DependenciasProductos? dependencias,
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
    );
  }

  Future<_EscenarioDashboard> mostrarDashboardConProgresoActualizable(
    WidgetTester tester, {
    required ProgresoConfiguracion progreso,
    NegocioRepository? repositorio,
    _DependenciasProductos? dependencias,
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

  testWidgets('navega a elegir plantilla desde la barra superior', (
    tester,
  ) async {
    final escenario = await mostrarDashboard(tester);

    await tester.tap(find.byTooltip('Elegir plantilla'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccion de plantilla'), findsOneWidget);
    expect(escenario.abridor.llamadas, 0);
  });

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
    await mostrarDashboard(tester, size: const Size(1050, 1000));

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
    expect(navegacion.width, 252);
    expect(panel.width, 320);
    expect(navegacion.right, contenido.left);
    expect(contenido.right, panel.left);
  });

  testWidgets('muestra Drawer y ayuda contextual plegable bajo 1050 px', (
    tester,
  ) async {
    await mostrarDashboard(tester, size: const Size(1049, 1000));

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
    expect(
      find.byKey(const Key('authenticated-shell-contextual-expansion')),
      findsOneWidget,
    );
    expect(find.text('Necesita tu atención'), findsNothing);

    await tester.tap(find.text('Ayuda contextual'));
    await tester.pumpAndSettle();

    expect(find.text('Necesita tu atención'), findsOneWidget);

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardSidebar), findsOneWidget);
  });

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

  testWidgets(
    'en compacto la ayuda de Productos es plegable y cerrada por defecto',
    (tester) async {
      for (final ancho in const [768.0, 1049.0]) {
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
        expect(
          find.byKey(const Key('authenticated-shell-contextual-expansion')),
          findsOneWidget,
        );
        expect(find.text('Ayuda contextual'), findsOneWidget);
        expect(find.byType(ProductosContextualPanel), findsNothing);
        expect(find.byKey(const Key('fases-negocio-panel')), findsNothing);

        final tileFinder = find.byKey(
          const Key('authenticated-shell-contextual-expansion'),
        );
        expect(tester.getRect(tileFinder).height, lessThan(160));

        await tester.tap(find.text('Ayuda contextual'));
        await tester.pumpAndSettle();

        expect(find.byType(ProductosContextualPanel), findsOneWidget);
        expect(find.text('¿Cómo funciona?').hitTestable(), findsOneWidget);
        expect(tester.getRect(tileFinder).height, greaterThan(200));

        await tester.tap(find.text('Ayuda contextual'));
        await tester.pumpAndSettle();
        expect(tester.getRect(tileFinder).height, lessThan(160));
      }
    },
  );

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
      find.byKey(const Key('authenticated-shell-contextual-expansion')),
      findsOneWidget,
    );
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    final tileFinder360 = find.byKey(
      const Key('authenticated-shell-contextual-expansion'),
    );
    expect(tester.getRect(tileFinder360).height, lessThan(160));

    await tester.tap(find.text('Ayuda contextual'));
    await tester.pumpAndSettle();

    expect(tester.getRect(tileFinder360).height, greaterThan(160));
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
      expect(find.text('Ayuda contextual'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ayuda contextual'));
      await tester.pumpAndSettle();

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
      expect(find.text('Seleccion de plantilla'), findsOneWidget);
    },
  );

  testWidgets(
    'elegir plantilla desde Productos conserva la navegación a la ruta raíz',
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

      expect(escenario.etapasAbiertas, contains(EtapaConfiguracion.plantilla));
      expect(find.text('Seleccion de plantilla'), findsOneWidget);
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
    'Configuración interna oculta el panel contextual derecho y lo restaura',
    (tester) async {
      await mostrarDashboard(tester, progreso: _progresoConRubro());

      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsOneWidget,
      );

      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
      expect(
        find.byKey(const Key('authenticated-shell-contextual-panel')),
        findsNothing,
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
    for (final ancho in const [1050.0, 1440.0]) {
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

  testWidgets(
    'en compacto la ayuda de Rubro es plegable y cerrada por defecto',
    (tester) async {
      for (final ancho in const [768.0, 1049.0]) {
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
        expect(
          find.byKey(const Key('authenticated-shell-contextual-expansion')),
          findsOneWidget,
        );
        expect(find.text('Ayuda contextual'), findsOneWidget);

        final tileFinder = find.byKey(
          const Key('authenticated-shell-contextual-expansion'),
        );
        expect(tester.getRect(tileFinder).height, lessThan(160));

        await tester.tap(find.text('Ayuda contextual'));
        await tester.pumpAndSettle();

        expect(find.byType(RubroContextualPanel), findsOneWidget);
        expect(find.text('¿Qué es un rubro?').hitTestable(), findsOneWidget);
        expect(tester.getRect(tileFinder).height, greaterThan(200));
        expect(find.text('Necesita tu atención'), findsNothing);

        await tester.tap(find.text('Ayuda contextual'));
        await tester.pumpAndSettle();
        expect(tester.getRect(tileFinder).height, lessThan(160));

        await tester.tap(find.byTooltip('Volver al dashboard'));
        await tester.pumpAndSettle();
      }
    },
  );

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
      find.byKey(const Key('authenticated-shell-contextual-expansion')),
      findsOneWidget,
    );
    expect(find.text('Ayuda contextual'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ayuda contextual'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué es un rubro?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la ayuda de Rubro soporta texto ampliado sin overflow', (
    tester,
  ) async {
    await mostrarDashboard(
      tester,
      size: const Size(1050, 1000),
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
}

class _EscenarioDashboard {
  final _AbridorFake abridor;
  final List<EtapaConfiguracion> etapasAbiertas;
  final DashboardProvider provider;
  final _DependenciasProductos dependencias;
  final void Function(ProgresoConfiguracion progreso) actualizarProgreso;

  const _EscenarioDashboard({
    required this.abridor,
    required this.etapasAbiertas,
    required this.provider,
    required this.dependencias,
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
