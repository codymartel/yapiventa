import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/foto_modelo.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/foto_producto.dart';
import 'package:mocktail/mocktail.dart';

import 'formulario_producto_helpers.dart';

/// La pregunta «¿viene en distintos …?» y lo que la acompaña.
void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  Future<void> decirSi(WidgetTester tester) async {
    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();
  }

  group('la pregunta', () {
    testWidgets('sin variables el producto queda simple, como siempre', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));

      expect(find.byKey(const Key('pregunta-modelos')), findsOneWidget);
      expect(find.byKey(const Key('lista-modelos')), findsNothing);
      expect(campo('Precio S/ *'), findsOneWidget);
      expect(campo('Stock *'), findsOneWidget);
    });

    testWidgets('el ejemplo y las palabras se adaptan al rubro', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Belleza y cuidado personal'));
      expect(find.textContaining('aromas o tonos'), findsOneWidget);
      await decirSi(tester);

      for (final palabra in ['Aroma', 'Tono', 'Fragancia']) {
        expect(find.byKey(Key('sugerencia-$palabra')), findsOneWidget);
      }
      expect(find.byKey(const Key('sugerencia-Color')), findsNothing);
    });

    testWidgets('las sugerencias son ayuda: se puede escribir otra palabra', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await decirSi(tester);

      await tester.enterText(find.byKey(const Key('titulo-modelos')), 'Diseño');
      await tester.pump();

      expect(campo('Nombre del diseño *'), findsOneWidget);
      expect(find.text('Agregar diseño'), findsOneWidget);
    });

    testWidgets('la presentación y lo que cambia dentro no se confunden', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Color')));
      await tester.pump();

      // La presentación se explica como «una sola para todo el producto».
      expect(
        find.byKey(const Key('ayuda-presentacion-modelos')),
        findsOneWidget,
      );
      // Lo de dentro de cada modelo se pregunta con palabras de la persona,
      // no con «título de las filas».
      expect(find.text('Dentro de cada color cambia:'), findsOneWidget);
      expect(find.text('Título de las filas:'), findsNothing);
    });

    testWidgets('sin variables no aparece la ayuda de la presentación', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));

      expect(find.byKey(const Key('ayuda-presentacion-modelos')), findsNothing);
    });

    testWidgets(
      'con variables no hay foto principal: cada modelo tiene la suya',
      (tester) async {
        await montar(tester, formulario(rubro: 'Ropa'));
        expect(find.byType(FotoProducto), findsOneWidget);
        expect(find.byType(FotoModelo), findsNothing);

        await decirSi(tester);

        expect(find.byType(FotoProducto), findsNothing);
        expect(find.byType(FotoModelo), findsOneWidget);
        expect(find.text('foto *'), findsOneWidget);
      },
    );

    testWidgets('al volver a No reaparece la foto principal', (tester) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await decirSi(tester);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(find.byType(FotoProducto), findsOneWidget);
      expect(find.byType(FotoModelo), findsNothing);
    });

    testWidgets('al tocar una sugerencia se llena la palabra', (tester) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await decirSi(tester);

      await tester.tap(find.byKey(const Key('sugerencia-Estilo')));
      await tester.pump();

      expect(campo('Nombre del estilo *'), findsOneWidget);
    });

    testWidgets('al decir Sí desaparecen el precio y el stock simples', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await decirSi(tester);

      expect(campo('Precio S/ *'), findsNothing);
      expect(campo('Stock *'), findsNothing);
      expect(find.byKey(const Key('lista-modelos')), findsOneWidget);
    });

    testWidgets('volver a No devuelve el precio y el stock simples', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await decirSi(tester);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lista-modelos')), findsNothing);
      expect(campo('Precio S/ *'), findsOneWidget);
    });
  });
}
