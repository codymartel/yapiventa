import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/apariencia/domain/tamano_letra.dart';
import 'package:mobile/features/apariencia/presentation/providers/apariencia_provider.dart';
import 'package:mobile/features/apariencia/presentation/screens/configuracion_app_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AparienciaProvider> mostrar(
    WidgetTester tester, {
    Size tamano = const Size(360, 800),
    TamanoLetra inicial = TamanoLetra.normal,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = AparienciaProvider(tamanoLetra: inicial);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: ConfiguracionAppScreen()),
        ),
      ),
    );
    return provider;
  }

  testWidgets('muestra las 3 opciones de letra y marca la elegida', (
    tester,
  ) async {
    await mostrar(tester, inicial: TamanoLetra.grande);

    for (final tamano in TamanoLetra.values) {
      expect(find.text(tamano.etiqueta), findsOneWidget);
    }
    expect(find.text('Así se verá'), findsOneWidget);
    bool? elegida(String etiqueta) => tester
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == etiqueta,
          ),
        )
        .properties
        .selected;
    expect(elegida('Letra Grande'), isTrue);
    expect(elegida('Letra Normal'), isFalse);
  });

  testWidgets('tocar una opción la elige y la guarda en el equipo', (
    tester,
  ) async {
    final provider = await mostrar(tester);

    await tester.tap(find.byKey(const ValueKey('tamano-letra-muy_grande')));
    await tester.pumpAndSettle();

    expect(provider.tamanoLetra, TamanoLetra.muyGrande);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('apariencia_tamano_letra'), 'muy_grande');
  });

  testWidgets('no ofrece lo que aún no existe (fondo claro)', (tester) async {
    await mostrar(tester);

    expect(find.textContaining('claro'), findsNothing);
    expect(find.textContaining('próximamente'), findsNothing);
  });

  testWidgets('en un celular chico con letra al tope no se desborda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = AparienciaProvider(tamanoLetra: TamanoLetra.muyGrande);
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(TamanoLetra.escalaMaxima),
            ),
            child: const Scaffold(body: ConfiguracionAppScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
