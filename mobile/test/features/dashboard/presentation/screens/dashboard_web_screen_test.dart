import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/negocio/application/use_cases/guardar_plantilla_web.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'package:provider/provider.dart';

void main() {
  Future<_EscenarioDashboard> mostrarDashboard(
    WidgetTester tester, {
    bool resultado = true,
    Object? error,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repositorio = _RepositorioSeleccionFake();
    final seleccionProvider = SeleccionPlantillaProvider(
      uid: 'usuario-1',
      obtenerSeleccionPlantilla: ObtenerSeleccionPlantilla(repositorio),
      guardarPlantillaWeb: GuardarPlantillaWeb(repositorio),
    );
    await seleccionProvider.cargar();
    final dashboardProvider = DashboardProvider();
    final abridor = _AbridorFake(resultado: resultado, error: error);
    addTearDown(seleccionProvider.dispose);
    addTearDown(dashboardProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: dashboardProvider),
          ChangeNotifierProvider.value(value: seleccionProvider),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          home: DashboardWebScreen(abrirUrl: abridor.call),
          routes: {
            '/elegir-plantilla': (_) => const Scaffold(
              body: Center(child: Text('Seleccion de plantilla')),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _EscenarioDashboard(repositorio: repositorio, abridor: abridor);
  }

  testWidgets(
    'usa la precarga y abre el dominio publico sin releer al pulsar',
    (tester) async {
      final escenario = await mostrarDashboard(tester);
      expect(escenario.repositorio.lecturas, 1);

      await tester.tap(find.text('Ver tienda web'));
      await tester.pumpAndSettle();

      expect(escenario.repositorio.lecturas, 1);
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
    expect(escenario.repositorio.lecturas, 1);
    expect(escenario.abridor.llamadas, 0);
  });
}

class _EscenarioDashboard {
  final _RepositorioSeleccionFake repositorio;
  final _AbridorFake abridor;

  const _EscenarioDashboard({required this.repositorio, required this.abridor});
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

class _RepositorioSeleccionFake implements RepositorioSeleccionPlantilla {
  int lecturas = 0;

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    lecturas++;
    return const SeleccionPlantillaInfo(
      slug: 'mi-tienda',
      plantillaGuardada: PlantillaWeb.cristal,
      provieneDeCampoOficial: true,
    );
  }

  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {}
}
