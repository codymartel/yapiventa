import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/authenticated_shell.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/dashboard/presentation/state/dashboard_ui_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_home_content.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_recent_orders.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sales_chart.dart';
import 'package:mobile/features/negocio/catalogo_negocio_dependencies.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/productos/productos_dependencies.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

void main() {
  Future<_EscenarioInicio> mostrarInicio(
    WidgetTester tester, {
    Size size = const Size(1400, 1000),
    TextScaler textScaler = TextScaler.noScaling,
    DashboardProvider? provider,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dashboardProvider =
        provider ?? DashboardProvider(initialState: _estadoInicio());
    if (provider == null) addTearDown(dashboardProvider.dispose);
    final dependenciasProductos = _ProductosDependenciesMock();
    final dependenciasCatalogo = _CatalogoNegocioDependenciesMock();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: dashboardProvider,
        child: Provider<NegocioRepository>.value(
          value: NegocioRepository(firestore: FakeFirebaseFirestore()),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
            home: Builder(
              builder: (context) => DashboardWebScreen(
                uid: 'usuario-1',
                negocioId: 'negocio-1',
                abrirUrl: (_, {String? webOnlyWindowName}) async => true,
                progreso: _progresoCompleto(),
                email: 'ana@example.com',
                onAbrirEtapa: (etapa) {
                  Navigator.of(context).pushNamed('/configurar-negocio');
                },
                onCerrarSesion: () {},
                productosDependencies: dependenciasProductos,
                catalogoDependencies: dependenciasCatalogo,
              ),
            ),
            routes: {
              '/elegir-rubro': (_) => const _RutaSencilla('Seleccion de rubro'),
              '/configurar-negocio': (_) =>
                  const _RutaSencilla('Configuracion de negocio'),
              '/productos': (_) => const _RutaSencilla('Lista de productos'),
              '/elegir-plantilla': (_) =>
                  const _RutaSencilla('Seleccion de plantilla'),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _EscenarioInicio(provider: dashboardProvider);
  }

  testWidgets(
    'el Inicio no desborda en la matriz de anchos y escalas de texto',
    (tester) async {
      const tamanos = [320.0, 360.0, 500.0, 768.0, 1050.0, 1440.0];
      for (final ancho in tamanos) {
        for (final escala in const [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await mostrarInicio(
            tester,
            size: Size(ancho, 900),
            textScaler: TextScaler.linear(escala),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow a $ancho px con escala $escala',
          );
          expect(find.text('Resumen de tu negocio'), findsOneWidget);
          expect(find.byType(DashboardHomeContent), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'el Inicio con texto ampliado conserva textos y métricas visibles',
    (tester) async {
      for (final escala in const [1.3, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await mostrarInicio(
          tester,
          size: const Size(360, 3000),
          textScaler: TextScaler.linear(escala),
        );

        expect(find.text('Resumen de tu negocio'), findsOneWidget);
        expect(find.text('Ventas online'), findsOneWidget);
        expect(find.text('S/ 1200.50'), findsOneWidget);
        expect(find.text('Ventas físicas'), findsOneWidget);
        expect(find.text('S/ 320.75'), findsOneWidget);
        expect(find.text('Acciones rápidas'), findsOneWidget);
        expect(find.text('Agregar producto'), findsOneWidget);
        expect(find.text('Pedidos recientes'), findsOneWidget);
        expect(find.text('Ver todos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('el gráfico continúa renderizándose con texto ampliado', (
    tester,
  ) async {
    for (final escala in const [1.3, 2.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await mostrarInicio(
        tester,
        size: const Size(360, 3000),
        textScaler: TextScaler.linear(escala),
      );

      final grafico = find.byType(DashboardSalesChart);
      expect(grafico, findsOneWidget);
      expect(tester.getSize(grafico).width, greaterThan(0));
      expect(tester.getSize(grafico).height, greaterThan(0));
      expect(find.text('Ventas de los últimos 7 días'), findsOneWidget);
      expect(find.text('Comparación por canal'), findsOneWidget);
      expect(find.byType(DashboardRecentOrders), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('el Inicio reconstruido conserva shell y DashboardProvider', (
    tester,
  ) async {
    final provider = DashboardProvider(initialState: _estadoInicio());
    addTearDown(provider.dispose);

    await mostrarInicio(
      tester,
      size: const Size(360, 1000),
      textScaler: const TextScaler.linear(2.0),
      provider: provider,
    );

    final elemento = tester.element(find.byType(AuthenticatedShell));
    final shellAntes = tester.element(find.byType(AuthenticatedShell));
    final proveedorAntes = Provider.of<DashboardProvider>(
      shellAntes,
      listen: false,
    );
    expect(identical(proveedorAntes, provider), isTrue);

    await mostrarInicio(
      tester,
      size: const Size(360, 1000),
      textScaler: const TextScaler.linear(1.3),
      provider: provider,
    );

    final shellDespues = tester.element(find.byType(AuthenticatedShell));
    final proveedorDespues = Provider.of<DashboardProvider>(
      shellDespues,
      listen: false,
    );
    expect(identical(shellAntes, shellDespues), isTrue);
    expect(identical(shellAntes, elemento), isTrue);
    expect(identical(proveedorDespues, provider), isTrue);
    expect(find.byType(DashboardHomeContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EscenarioInicio {
  final DashboardProvider provider;

  const _EscenarioInicio({required this.provider});
}

class _RutaSencilla extends StatelessWidget {
  final String texto;

  const _RutaSencilla(this.texto);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(texto)));
}

DashboardUiState _estadoInicio() => DashboardUiState(
  periodo: DashboardPeriod.semana,
  nombreNegocio: 'Bodega El Sol',
  ventasOnline: 1200.5,
  ventasFisicas: 320.75,
  pedidosPendientes: 3,
  productosActivos: 42,
  quejasPendientes: 1,
  productosStockBajo: 5,
  ventasUltimos7Dias: const [
    DashboardSalesPoint(label: 'L', online: 180, fisicas: 120),
    DashboardSalesPoint(label: 'M', online: 240, fisicas: 90),
    DashboardSalesPoint(label: 'X', online: 150, fisicas: 200),
    DashboardSalesPoint(label: 'J', online: 300, fisicas: 160),
    DashboardSalesPoint(label: 'V', online: 260, fisicas: 210),
    DashboardSalesPoint(label: 'S', online: 320, fisicas: 180),
    DashboardSalesPoint(label: 'D', online: 190, fisicas: 150),
  ],
  pedidosRecientes: const [
    DashboardRecentOrder(
      id: '#1042',
      cliente: 'María Fernández',
      hora: '10:32',
      total: 86.5,
      productos: 4,
      estado: DashboardOrderStatus.preparando,
    ),
    DashboardRecentOrder(
      id: '#1041',
      cliente: 'Carlos Quispe',
      hora: '09:15',
      total: 24.0,
      productos: 2,
      estado: DashboardOrderStatus.pendiente,
    ),
  ],
  necesitanAtencion: const [],
  productosDestacados: const [],
);

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

class _ProductosDependenciesMock extends Mock
    implements ProductosDependencies {}

class _CatalogoNegocioDependenciesMock extends Mock
    implements CatalogoNegocioDependencies {}
