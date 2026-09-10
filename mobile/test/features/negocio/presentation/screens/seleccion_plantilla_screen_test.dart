import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/application/use_cases/guardar_plantilla_web.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'package:mobile/features/negocio/presentation/screens/seleccion_plantilla_screen.dart';
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
          home: SeleccionPlantillaScreen(
            rubro: 'Bodega',
            onPlantillaSeleccionada: (_) {},
            abrirUrl: abridor.call,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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
