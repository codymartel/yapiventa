import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/application/use_cases/guardar_plantilla_web.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_plantilla_screen.dart';
import 'package:mobile/features/negocio/presentation/widgets/seleccion_plantilla_content.dart';
import 'package:provider/provider.dart';

void main() {
  Future<SeleccionPlantillaProvider> crearProvider({
    String slug = 'mi-tienda',
  }) async {
    final repositorio = _RepositorioSeleccionFake(slug: slug);
    final provider = SeleccionPlantillaProvider(
      uid: 'usuario-1',
      obtenerSeleccionPlantilla: ObtenerSeleccionPlantilla(repositorio),
      guardarPlantillaWeb: GuardarPlantillaWeb(repositorio),
    );
    await provider.cargar();
    return provider;
  }

  Future<void> mostrarPantalla(
    WidgetTester tester, {
    required SeleccionPlantillaProvider provider,
    required _AbridorFake abridor,
    Map<String, WidgetBuilder> routes = const {},
    Future<void> Function(String plantilla)? alGuardar,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          routes: routes,
          home: SeleccionPlantillaScreen(
            rubro: 'Bodega',
            onPlantillaSeleccionada: alGuardar ?? (_) async {},
            abrirUrl: abridor.call,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('conserva un único Scaffold y delega en el contenido', (
    tester,
  ) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake();
    await mostrarPantalla(tester, provider: provider, abridor: abridor);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(SeleccionPlantillaContent), findsOneWidget);
  });

  testWidgets('conserva la selección visual a través del provider', (
    tester,
  ) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake();
    await mostrarPantalla(tester, provider: provider, abridor: abridor);

    expect(provider.seleccionTemporal, PlantillaWeb.neon);
    await tester.ensureVisible(find.byKey(const Key('plantilla-card-cristal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-cristal')));

    expect(provider.seleccionTemporal, PlantillaWeb.cristal);
    expect(provider.cambiosPendientes, isTrue);
  });

  testWidgets('finalizar guarda y notifica la plantilla elegida', (
    tester,
  ) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake();
    final guardadas = <String>[];
    await mostrarPantalla(
      tester,
      provider: provider,
      abridor: abridor,
      alGuardar: (plantilla) async => guardadas.add(plantilla),
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-galeria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-galeria')));
    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();

    expect(guardadas, [PlantillaWeb.galeria.valorPersistencia]);
    expect(provider.cambiosPendientes, isFalse);
  });

  testWidgets('ir al dashboard reemplaza hacia la ruta de inicio', (
    tester,
  ) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake();
    await mostrarPantalla(
      tester,
      provider: provider,
      abridor: abridor,
      routes: {'/home': (_) => const Scaffold(body: Text('Inicio'))},
    );

    await tester.ensureVisible(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.byType(SeleccionPlantillaContent), findsNothing);
  });

  testWidgets('abre el dominio publico en una pestana nueva', (tester) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake();
    await mostrarPantalla(tester, provider: provider, abridor: abridor);

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(abridor.llamadas, 1);
    expect(
      abridor.ultimaUrl,
      Uri.parse('https://yapiventa-tienda.web.app/mi-tienda'),
    );
    expect(abridor.ultimoDestino, '_blank');
  });

  testWidgets('muestra un mensaje distinto cuando launchUrl devuelve false', (
    tester,
  ) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake(resultado: false);
    await mostrarPantalla(tester, provider: provider, abridor: abridor);

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(
      find.text('El navegador no pudo abrir la tienda web.'),
      findsOneWidget,
    );
  });

  testWidgets('captura una excepcion y conserva un mensaje comprensible', (
    tester,
  ) async {
    final provider = await crearProvider();
    final abridor = _AbridorFake(error: StateError('plugin no registrado'));
    await mostrarPantalla(tester, provider: provider, abridor: abridor);

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ocurrió un error al abrir la tienda web. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('un slug vacio no intenta abrir ninguna URL', (tester) async {
    final provider = await crearProvider(slug: '');
    final abridor = _AbridorFake();
    await mostrarPantalla(tester, provider: provider, abridor: abridor);

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(abridor.llamadas, 0);
    expect(
      find.text('La vista web estará disponible próximamente'),
      findsOneWidget,
    );
  });
}

class _AbridorFake {
  final bool resultado;
  final Object? error;
  int llamadas = 0;
  Uri? ultimaUrl;
  String? ultimoDestino;

  _AbridorFake({this.resultado = true, this.error});

  Future<bool> call(Uri url, {String? webOnlyWindowName}) async {
    llamadas++;
    ultimaUrl = url;
    ultimoDestino = webOnlyWindowName;
    if (error != null) throw error!;
    return resultado;
  }
}

class _RepositorioSeleccionFake implements RepositorioSeleccionPlantilla {
  final String slug;

  _RepositorioSeleccionFake({required this.slug});

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    return SeleccionPlantillaInfo(
      slug: slug,
      plantillaGuardada: PlantillaWeb.neon,
      provieneDeCampoOficial: true,
    );
  }

  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {}
}
