import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

Producto _p(String id, String nombre, int precio, int stock) => Producto(
  id: id,
  negocioId: 'n',
  nombre: nombre,
  precioCentavos: precio,
  stock: stock,
);

final _pollo = _p('pollo', 'Pollo', 1800, 10);
final _papas = _p('papas', 'Papas', 600, 7);

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  Finder siDelCombo() => find.descendant(
    of: find.byKey(const Key('segmento-combo')),
    matching: find.text('Sí'),
  );

  Future<void> agregarPollosYPapas(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('agregar-parte-combo')));
    await tester.tap(find.byKey(const Key('agregar-parte-combo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mas-pollo||')));
    await tester.tap(find.byKey(const Key('mas-papas||')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agregar-partes')));
    await tester.pumpAndSettle();
  }

  group('pregunta «¿Es un combo?»', () {
    testWidgets('no aparece si no hay al menos 2 productos para juntar', (
      tester,
    ) async {
      await montar(tester, formulario(productosParaCombo: [_pollo]));

      expect(find.byKey(const Key('pregunta-combo')), findsNothing);
    });

    testWidgets('dice la palabra del rubro: «¿Es un kit?» en Belleza', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(
          rubro: 'Belleza y cuidado personal',
          productosParaCombo: [_pollo, _papas],
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('pregunta-combo')),
          matching: find.textContaining('¿Es un kit?'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('con «Sí» se esconde lo de presentación y variables', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(rubro: 'Restaurante', productosParaCombo: [_pollo, _papas]),
      );
      expect(find.text('Lo cuento'), findsOneWidget);

      await tester.ensureVisible(siDelCombo());
      await tester.tap(siDelCombo());
      await tester.pumpAndSettle();

      expect(find.text('Lo cuento'), findsNothing);
      expect(find.byKey(const Key('pregunta-modelos')), findsNothing);
      expect(find.byKey(const Key('agregar-parte-combo')), findsOneWidget);
      expect(find.byKey(const Key('linea-extras')), findsOneWidget);
    });
  });

  group('armar el combo', () {
    testWidgets('el precio arranca con la suma, y el stock se calcula', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(rubro: 'Restaurante', productosParaCombo: [_pollo, _papas]),
      );
      await tester.ensureVisible(siDelCombo());
      await tester.tap(siDelCombo());
      await tester.pumpAndSettle();

      await agregarPollosYPapas(tester);

      expect(find.text('Qué incluye · 2 productos'), findsOneWidget);
      expect(find.text('Suma de las partes: S/ 24.00'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('precio-combo')))
            .controller!
            .text,
        '24.00',
      );
      // pollo 10, papas 7: limita Papas.
      expect(find.text('7 · limita: Papas'), findsOneWidget);
    });

    testWidgets('con un precio menor se ve cuánto ahorra el cliente', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(rubro: 'Restaurante', productosParaCombo: [_pollo, _papas]),
      );
      await tester.ensureVisible(siDelCombo());
      await tester.tap(siDelCombo());
      await tester.pumpAndSettle();
      await agregarPollosYPapas(tester);

      await tester.enterText(find.byKey(const Key('precio-combo')), '20');
      await tester.pumpAndSettle();

      expect(find.text('El cliente ahorra S/ 4.00'), findsOneWidget);
    });

    testWidgets(
      'guarda el combo con su precio, sus partes y sin stock propio',
      (tester) async {
        final provider = ProductosProviderMock();
        when(
          () => provider.crearProducto(
            any(),
            imagenBytes: any(named: 'imagenBytes'),
            nombreArchivo: any(named: 'nombreArchivo'),
          ),
        ).thenAnswer((_) async => true);
        await montar(
          tester,
          formulario(
            provider: provider,
            rubro: 'Restaurante',
            productosParaCombo: [_pollo, _papas],
          ),
        );
        await ponerFotoDelProducto(tester);
        await tester.enterText(
          campo('Nombre del producto *'),
          'Combo familiar',
        );
        await tester.ensureVisible(siDelCombo());
        await tester.tap(siDelCombo());
        await tester.pumpAndSettle();
        await agregarPollosYPapas(tester);
        await tester.enterText(find.byKey(const Key('precio-combo')), '22');
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Guardar producto'),
        );
        await tester.pump();

        final combo = capturarProductoCreado(provider);
        expect(combo.esCombo, isTrue);
        expect(combo.partes.map((p) => p.productoId), ['pollo', 'papas']);
        expect(combo.precioCentavos, 2200);
        expect(combo.sumaPartesCentavos, 2400);
        expect(combo.stock, 0);
        expect(combo.modelos, isEmpty);
      },
    );

    testWidgets('con una sola parte avisa y no deja guardar', (tester) async {
      await montar(
        tester,
        formulario(rubro: 'Restaurante', productosParaCombo: [_pollo, _papas]),
      );
      await ponerFotoDelProducto(tester);
      await tester.enterText(campo('Nombre del producto *'), 'Combo');
      await tester.ensureVisible(siDelCombo());
      await tester.tap(siDelCombo());
      await tester.pumpAndSettle();

      expect(
        find.text('Falta: al menos 2 productos en el combo'),
        findsOneWidget,
      );
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  testWidgets('un combo guardado se abre con sus partes y precio', (
    tester,
  ) async {
    final combo = Producto(
      id: 'c1',
      negocioId: 'n',
      nombre: 'Combo familiar',
      categoria: 'Bebidas',
      precioCentavos: 2200,
      sumaPartesCentavos: 2400,
      partes: const [
        ParteCombo(productoId: 'pollo', cantidad: 1, nombre: 'Pollo'),
        ParteCombo(productoId: 'papas', cantidad: 1, nombre: 'Papas'),
      ],
    );

    await montar(
      tester,
      formulario(
        producto: combo,
        rubro: 'Restaurante',
        productosParaCombo: [_pollo, _papas, combo],
      ),
    );

    expect(find.text('Qué incluye · 2 productos'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('precio-combo')))
          .controller!
          .text,
      '22.00',
    );
    expect(find.byKey(const Key('aviso-partes-cambiaron')), findsNothing);
  });
}
