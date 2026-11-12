import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/authenticated_shell.dart';
import 'package:mobile/features/apariencia/domain/tamano_letra.dart';
import 'package:mobile/features/apariencia/presentation/providers/apariencia_provider.dart';
import 'package:mobile/features/apariencia/presentation/screens/configuracion_app_screen.dart';
import 'package:mobile/features/caja/presentation/widgets/caja_flow.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_flow.dart';
import 'package:mobile/features/planes/presentation/screens/planes_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../caja/helpers/banco_caja_flow.dart';

// Paso B y C: «Negocio» (antes «Configuración»), la «Configuración» nueva
// (apariencia de la app) y «Plan» en el menú del tablero.

ProgresoConfiguracion _progreso({bool completo = true}) =>
    ProgresoConfiguracion(
      catalogo: CatalogoNegocio(
        rubro: 'Bodega',
        categorias: const ['Abarrotes'],
        unidadesMedida: const [],
        configuracionInicial: const {
          'nombreNegocio': 'Bodega Rosa',
        },
      ),
      slug: 'bodega-rosa',
      plantilla: PlantillaWeb.cristal,
      plantillaProvieneDeCampoOficial: true,
      rubroCompleto: completo,
      negocioCompleto: completo,
      productosCompletos: completo,
      setupCompletePersistido: completo,
      productosConfirmadosPersistidos: completo,
    );

void main() {
  late BancoCaja banco;

  setUp(() => banco = BancoCaja());

  Future<void> mostrar(
    WidgetTester tester, {
    Size size = const Size(1400, 1000),
    bool completo = true,
    double letra = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ayuda_vista_inicio': true,
      'ayuda_vista_caja': true,
      'ayuda_vista_configuracion': true,
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(banco.dia.canal.close);
    final provider = DashboardProvider();
    addTearDown(provider.dispose);
    final apariencia = AparienciaProvider();
    addTearDown(apariencia.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: apariencia),
          Provider<NegocioRepository>.value(
            value: NegocioRepository(firestore: FakeFirebaseFirestore()),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(letra)),
            child: child!,
          ),
          home: DashboardWebScreen(
            uid: 'usuario-1',
            negocioId: 'negocio-1',
            progreso: _progreso(completo: completo),
            email: 'rosa@example.com',
            onAbrirEtapa: (_) {},
            onCerrarSesion: () {},
            cajaDependencies: banco.dependencias,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder enMenu(String texto) => find.descendant(
    of: find.byType(DashboardSidebar),
    matching: find.text(texto),
  );

  Future<void> abrir(WidgetTester tester, String texto) async {
    if (enMenu(texto).hitTestable().evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
    }
    await tester.tap(enMenu(texto).hitTestable());
    await tester.pumpAndSettle();
  }

  DashboardDestination activo(WidgetTester tester) => tester
      .widget<DashboardSidebar>(find.byType(DashboardSidebar))
      .destinoActivo;

  testWidgets('Negocio va donde estaba Configuración; Configuración y Plan '
      'van debajo de la raya', (tester) async {
    await mostrar(tester);

    final yNegocio = tester.getTopLeft(enMenu('Negocio')).dy;
    final yVentas = tester.getTopLeft(enMenu('Ventas')).dy;
    final yConfiguracion = tester.getTopLeft(enMenu('Configuración')).dy;
    final yPlan = tester.getTopLeft(enMenu('Plan')).dy;
    final yRaya = tester
        .getTopLeft(
          find.descendant(
            of: find.byType(DashboardSidebar),
            matching: find.byType(Divider),
          ),
        )
        .dy;

    expect(yVentas, lessThan(yNegocio));
    expect(yNegocio, lessThan(yRaya));
    expect(yRaya, lessThan(yConfiguracion));
    expect(yConfiguracion, lessThan(yPlan));
  });

  testWidgets('Negocio abre la configuración del negocio de siempre', (
    tester,
  ) async {
    await mostrar(tester);

    await abrir(tester, 'Negocio');

    expect(find.byType(ConfiguracionNegocioFlow), findsOneWidget);
    expect(activo(tester), DashboardDestination.negocio);
  });

  testWidgets('Configuración abre la apariencia, sin ayuda lateral', (
    tester,
  ) async {
    await mostrar(tester);

    await abrir(tester, 'Configuración');

    expect(find.byType(ConfiguracionAppScreen), findsOneWidget);
    expect(find.byType(ConfiguracionNegocioFlow), findsNothing);
    expect(activo(tester), DashboardDestination.configuracion);
    final shell = tester.widget<AuthenticatedShell>(
      find.byType(AuthenticatedShell),
    );
    expect(shell.contextualPanel, isNull);
  });

  testWidgets('elegir la letra en Configuración cambia toda la app', (
    tester,
  ) async {
    await mostrar(tester);
    await abrir(tester, 'Configuración');

    await tester.tap(find.byKey(const ValueKey('tamano-letra-grande')));
    await tester.pumpAndSettle();

    final contexto = tester.element(find.byType(ConfiguracionAppScreen));
    expect(
      Provider.of<AparienciaProvider>(contexto, listen: false).tamanoLetra,
      TamanoLetra.grande,
    );
  });

  testWidgets('Plan abre su texto y no deja abierta otra sección', (
    tester,
  ) async {
    await mostrar(tester);
    await abrir(tester, 'Ventas');
    expect(find.byType(CajaFlow), findsOneWidget);

    await abrir(tester, 'Plan');

    expect(find.byType(PlanesScreen), findsOneWidget);
    expect(find.text('Pronto tendremos planes'), findsOneWidget);
    expect(find.byType(CajaFlow), findsNothing, reason: 'Caja se cierra');
    expect(activo(tester), DashboardDestination.plan);
  });

  testWidgets('Configuración y Plan se abren aunque falten etapas', (
    tester,
  ) async {
    await mostrar(tester, completo: false);

    await abrir(tester, 'Configuración');
    expect(find.byType(ConfiguracionAppScreen), findsOneWidget);

    await abrir(tester, 'Plan');
    expect(find.byType(PlanesScreen), findsOneWidget);
    expect(
      find.text('Completa primero las etapas pendientes de configuración.'),
      findsNothing,
    );
  });

  for (final tamano in const [Size(400, 800), Size(1280, 900)]) {
    testWidgets('con letra «Muy grande» no se desborda en ${tamano.width} px', (
      tester,
    ) async {
      await mostrar(tester, size: tamano, letra: 1.3);
      expect(tester.takeException(), isNull, reason: 'Inicio');

      for (final seccion in ['Negocio', 'Ventas', 'Configuración', 'Plan']) {
        await abrir(tester, seccion);
        expect(tester.takeException(), isNull, reason: seccion);
      }
    });
  }
}
