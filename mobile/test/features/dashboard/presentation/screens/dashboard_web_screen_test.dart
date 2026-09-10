import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:provider/provider.dart';

void main() {
  Future<_EscenarioDashboard> mostrarDashboard(
    WidgetTester tester, {
    bool resultado = true,
    Object? error,
    ProgresoConfiguracion? progreso,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
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
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => DashboardWebScreen(
              abrirUrl: abridor.call,
              progreso: progreso ?? _progresoCompleto(),
              email: 'ana@example.com',
              onAbrirEtapa: (etapa) {
                etapasAbiertas.add(etapa);
                if (etapa == EtapaConfiguracion.plantilla) {
                  Navigator.of(context).pushNamed('/elegir-plantilla');
                }
              },
              onCerrarSesion: () {},
            ),
          ),
          routes: {
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

  testWidgets('muestra etapas y continúa por la primera pendiente', (
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
    await tester.pump();

    expect(escenario.etapasAbiertas, [EtapaConfiguracion.rubro]);
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
}

class _EscenarioDashboard {
  final _AbridorFake abridor;
  final List<EtapaConfiguracion> etapasAbiertas;

  const _EscenarioDashboard({
    required this.abridor,
    required this.etapasAbiertas,
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
