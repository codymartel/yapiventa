import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/authenticated_shell.dart';
import 'package:mobile/features/caja/presentation/widgets/caja_flow.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../caja/helpers/banco_caja_flow.dart';

// Caja conectada al tablero: el ítem «Ventas» del menú la abre con la
// configuración del negocio (sus formas de pago y sus zonas).

ProgresoConfiguracion _progreso({bool completo = true}) =>
    ProgresoConfiguracion(
      catalogo: CatalogoNegocio(
        rubro: 'Restaurante',
        categorias: const ['Platos'],
        unidadesMedida: const [],
        configuracionInicial: const {
          'nombreNegocio': 'El Buen Sabor',
          'metodosPago': ['efectivo', 'plin'],
          'delivery': true,
          'deliveryZonas': [
            {'zona': 'Centro', 'costo': 3.0},
          ],
        },
      ),
      slug: 'mi-tienda',
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

  Future<void> mostrar(
    WidgetTester tester, {
    Size size = const Size(1400, 1000),
    String? negocioId = 'negocio-1',
    bool completo = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ayuda_vista_inicio': true,
      'ayuda_vista_caja': true,
      'ayuda_vista_pedidos': true,
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(banco.dia.canal.close);
    final provider = DashboardProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: Provider<NegocioRepository>.value(
          value: NegocioRepository(firestore: FakeFirebaseFirestore()),
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: DashboardWebScreen(
              uid: 'usuario-1',
              negocioId: negocioId,
              progreso: _progreso(completo: completo),
              email: 'ana@example.com',
              onAbrirEtapa: (_) {},
              onCerrarSesion: () {},
              cajaDependencies: banco.dependencias,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirVentas(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DashboardSidebar),
        matching: find.text('Ventas'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => banco = BancoCaja());

  testWidgets('el menú de la versión 1 muestra Pedidos y Ventas', (t) async {
    await mostrar(t);

    final menu = find.byType(DashboardSidebar);
    for (final texto in ['Inicio', 'Productos', 'Pedidos', 'Ventas', 'Plan']) {
      expect(
        find.descendant(of: menu, matching: find.text(texto)),
        findsOneWidget,
        reason: texto,
      );
    }
    for (final texto in ['Reclamaciones']) {
      expect(
        find.descendant(of: menu, matching: find.text(texto)),
        findsNothing,
        reason: texto,
      );
    }
    expect(find.byType(CajaFlow), findsNothing, reason: 'no se abre sola');
    expect(banco.catalogo.consultas, 0, reason: 'sin lecturas hasta entrar');
  });

  testWidgets('«Ventas» abre Caja con el rubro, pagos y zonas del negocio', (
    t,
  ) async {
    await mostrar(t);
    await abrirVentas(t);

    expect(find.byType(CajaFlow), findsOneWidget);
    expect(banco.dia.escuchas, 1);
    expect(banco.catalogo.consultas, 1);
    // Rubro Restaurante → sus palabras de entrega.
    expect(find.text('En mesa'), findsOneWidget);
    expect(find.text('Para llevar'), findsOneWidget);
    // Solo las formas de pago que el negocio tiene activas.
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Plin'), findsOneWidget);
    expect(find.text('Yape'), findsNothing);

    await t.ensureVisible(find.text('Delivery'));
    await t.tap(find.text('Delivery'));
    await t.pumpAndSettle();
    expect(find.text('Centro · 3,00'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Caja trae su ayuda como los demás módulos', (t) async {
    await mostrar(t);
    await abrirVentas(t);

    await t.tap(find.byKey(AuthenticatedShell.helpButtonKey));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('caja-contextual-panel')), findsOneWidget);
    expect(find.text('LOS NÚMEROS DEL DÍA'), findsOneWidget);
  });

  testWidgets('al salir de Caja se cierran sus escuchas', (t) async {
    await mostrar(t);
    await abrirVentas(t);
    expect(banco.dia.canal.hasListener, isTrue);

    await t.tap(
      find.descendant(
        of: find.byType(DashboardSidebar),
        matching: find.text('Inicio'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byType(CajaFlow), findsNothing);
    expect(banco.dia.canal.hasListener, isFalse);
  });

  testWidgets('sin la configuración completa no deja entrar', (t) async {
    await mostrar(t, completo: false);
    await abrirVentas(t);

    expect(find.byType(CajaFlow), findsNothing);
    expect(
      find.text('Completa primero las etapas pendientes de configuración.'),
      findsOneWidget,
    );
  });

  testWidgets('sin negocio avisa y no abre', (t) async {
    await mostrar(t, negocioId: null);
    await abrirVentas(t);

    expect(find.byType(CajaFlow), findsNothing);
    expect(find.textContaining('No se encontró tu negocio'), findsOneWidget);
  });

  for (final (nombre, size) in const [
    ('celular', Size(390, 780)),
    ('celular de lado', Size(812, 375)),
    ('tableta', Size(820, 1100)),
    ('laptop', Size(1366, 768)),
  ]) {
    testWidgets('Caja dentro del tablero en $nombre: nada se desborda', (
      t,
    ) async {
      await mostrar(t, size: size);
      // En pantallas chicas el menú está en un cajón: se abre Caja por el
      // estado, igual que lo haría el menú.
      final menu = find.descendant(
        of: find.byType(DashboardSidebar),
        matching: find.text('Ventas'),
      );
      if (menu.evaluate().isEmpty) {
        await t.tap(find.byTooltip('Abrir menú').first);
        await t.pumpAndSettle();
      }
      await abrirVentas(t);
      await banco.llega(t, diaDePrueba(gastos: 1000));

      expect(find.byType(CajaFlow), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
