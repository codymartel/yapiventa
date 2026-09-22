import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/authenticated_shell.dart';
import 'package:mobile/features/auth/domain/politica_acceso.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_top_bar.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_negocio_flow.dart';
import 'package:provider/provider.dart';

void main() {
  Future<_EscenarioDashboard> mostrarDashboard(
    WidgetTester tester, {
    bool resultado = true,
    Object? error,
    ProgresoConfiguracion? progreso,
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
    addTearDown(dashboardProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: dashboardProvider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: Builder(
            builder: (context) => DashboardWebScreen(
              abrirUrl: abridor.call,
              progreso: progreso ?? _progresoCompleto(),
              email: 'ana@example.com',
              onAbrirEtapa: (etapa) {
                etapasAbiertas.add(etapa);
                Navigator.of(context).pushNamed(PoliticaAcceso.rutaDe(etapa));
              },
              onCerrarSesion: () {},
            ),
          ),
          routes: {
            '/elegir-rubro': (_) =>
                const Scaffold(body: Center(child: Text('Seleccion de rubro'))),
            '/configurar-negocio': (_) => const Scaffold(
              body: Center(child: Text('Configuracion de negocio')),
            ),
            '/productos': (_) =>
                const Scaffold(body: Center(child: Text('Lista de productos'))),
            '/elegir-plantilla': (_) => const Scaffold(
              body: Center(child: Text('Seleccion de plantilla')),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _EscenarioDashboard(
      abridor: abridor,
      etapasAbiertas: etapasAbiertas,
      provider: dashboardProvider,
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

  testWidgets('Productos conserva la ruta raíz /productos', (tester) async {
    final escenario = await mostrarDashboard(tester);

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();

    expect(escenario.etapasAbiertas, contains(EtapaConfiguracion.productos));
    expect(find.text('Lista de productos'), findsOneWidget);
  });

  testWidgets('Configuración conserva la ruta raíz de negocio', (tester) async {
    final escenario = await mostrarDashboard(tester);

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    expect(escenario.etapasAbiertas, contains(EtapaConfiguracion.negocio));
    expect(find.text('Configuracion de negocio'), findsOneWidget);
  });

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

  testWidgets('oculta la ayuda contextual mientras el Rubro está abierto', (
    tester,
  ) async {
    await mostrarDashboard(tester, progreso: _progresoPendiente());

    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsOneWidget,
    );

    await tester.tap(find.text('Continuar configuración'));
    await tester.pumpAndSettle();

    expect(find.byType(SeleccionNegocioFlow), findsOneWidget);
    expect(
      find.byKey(const Key('authenticated-shell-contextual-panel')),
      findsNothing,
    );
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
    },
  );

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
      expect(find.text('Configuracion de negocio'), findsNothing);
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

  const _EscenarioDashboard({
    required this.abridor,
    required this.etapasAbiertas,
    required this.provider,
  });
}

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
