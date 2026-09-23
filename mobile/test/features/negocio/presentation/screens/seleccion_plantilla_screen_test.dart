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
  Future<void> mostrarPantalla(
    WidgetTester tester, {
    _RepositorioSeleccionFake? repositorio,
    _AbridorFake? abridor,
    Map<String, WidgetBuilder> routes = const {},
    VoidCallback? onVolver,
    VoidCallback? alCompletar,
    Future<void> Function()? recargarProgreso,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = repositorio ?? _RepositorioSeleccionFake();
    final abridorFinal = abridor ?? _AbridorFake();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.8)),
          child: child!,
        ),
        routes: routes,
        home: SeleccionPlantillaScreen(
          uid: 'usuario-1',
          rubro: 'Bodega',
          seleccionInicial: SeleccionPlantillaInfo(
            slug: repo.slug,
            plantillaGuardada: repo.plantillaGuardada,
            provieneDeCampoOficial: true,
          ),
          dependencies: SeleccionPlantillaDependencies.fromRepository(repo),
          onVolver: onVolver ?? () {},
          onCompletado: alCompletar ?? () {},
          recargarProgreso: recargarProgreso,
          abrirUrl: abridorFinal.call,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('conserva un único Scaffold y delega en el flujo', (
    tester,
  ) async {
    await mostrarPantalla(tester);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(SeleccionPlantillaFlow), findsOneWidget);
    expect(find.byType(SeleccionPlantillaContent), findsOneWidget);
  });

  testWidgets('conserva la selección visual a través del provider', (
    tester,
  ) async {
    await mostrarPantalla(tester);

    final contexto = tester.element(find.byType(SeleccionPlantillaContent));
    final provider = Provider.of<SeleccionPlantillaProvider>(
      contexto,
      listen: false,
    );
    expect(provider.seleccionTemporal, PlantillaWeb.neon);

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-cristal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-cristal')));

    expect(provider.seleccionTemporal, PlantillaWeb.cristal);
    expect(provider.cambiosPendientes, isTrue);
  });

  testWidgets('guardar persiste y Finalizar solo completa', (tester) async {
    final repo = _RepositorioSeleccionFake();
    var recargas = 0;
    var completados = 0;
    await mostrarPantalla(
      tester,
      repositorio: repo,
      recargarProgreso: () async => recargas++,
      alCompletar: () => completados++,
    );

    await tester.ensureVisible(find.byKey(const Key('plantilla-card-galeria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plantilla-card-galeria')));
    await tester.ensureVisible(find.byKey(const Key('guardar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar-plantilla')));
    await tester.pumpAndSettle();

    expect(recargas, 1);
    expect(completados, 0);
    expect(find.byType(SeleccionPlantillaContent), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finalizar-plantilla')));
    await tester.pumpAndSettle();

    expect(repo.guardados, 1);
    expect(completados, 1);
  });

  testWidgets('ir al dashboard ejecuta onVolver', (tester) async {
    var volveres = 0;
    await mostrarPantalla(tester, onVolver: () => volveres++);

    await tester.ensureVisible(find.byKey(const Key('ir-dashboard-plantilla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-dashboard-plantilla')));

    expect(volveres, 1);
  });

  testWidgets('abre el dominio publico en una pestana nueva', (tester) async {
    final abridor = _AbridorFake();
    await mostrarPantalla(tester, abridor: abridor);

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
    await mostrarPantalla(tester, abridor: _AbridorFake(resultado: false));

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
    await mostrarPantalla(
      tester,
      abridor: _AbridorFake(error: StateError('plugin no registrado')),
    );

    await tester.tap(find.text('Ver tienda web'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ocurrió un error al abrir la tienda web. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('un slug vacio no intenta abrir ninguna URL', (tester) async {
    final abridor = _AbridorFake();
    await mostrarPantalla(
      tester,
      repositorio: _RepositorioSeleccionFake(slug: ''),
      abridor: abridor,
    );

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
  final PlantillaWeb plantillaGuardada = PlantillaWeb.neon;
  int guardados = 0;

  _RepositorioSeleccionFake({this.slug = 'mi-tienda'});

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    return SeleccionPlantillaInfo(
      slug: slug,
      plantillaGuardada: plantillaGuardada,
      provieneDeCampoOficial: true,
    );
  }

  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {
    guardados++;
  }
}
