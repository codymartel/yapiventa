import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/widgets/mosaico_fotos.dart';
import 'package:mobile/features/productos/presentation/widgets/producto_card.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

Producto _p(
  String id,
  String nombre,
  int precio,
  int stock, {
  String foto = '',
}) => Producto(
  id: id,
  negocioId: 'n',
  nombre: nombre,
  precioCentavos: precio,
  stock: stock,
  urlImagen: foto,
);

Finder siDelCombo() => find.descendant(
  of: find.byKey(const Key('segmento-combo')),
  matching: find.text('Sí'),
);

Future<void> armarCombo(WidgetTester tester) async {
  await tester.ensureVisible(siDelCombo());
  await tester.tap(siDelCombo());
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('agregar-parte-combo')));
  await tester.tap(find.byKey(const Key('agregar-parte-combo')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('mas-pollo||')));
  await tester.tap(find.byKey(const Key('mas-papas||')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('agregar-partes')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  group('la foto del producto es obligatoria', () {
    testWidgets('sin foto avisa primero «Falta: foto del producto»', (
      tester,
    ) async {
      await montar(tester, formulario());
      await tester.enterText(campo('Nombre del producto *'), 'Cerveza');
      await tester.enterText(campo('Precio S/ *'), '8');
      await tester.enterText(campo('Stock *'), '12');
      await tester.pumpAndSettle();

      expect(find.text('Falta: foto del producto'), findsOneWidget);
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('con la foto puesta ya se puede guardar', (tester) async {
      await montar(tester, formulario());
      await tester.enterText(campo('Nombre del producto *'), 'Cerveza');
      await tester.enterText(campo('Precio S/ *'), '8');
      await tester.enterText(campo('Stock *'), '12');
      await ponerFotoDelProducto(tester);

      expect(find.text('Falta: foto del producto'), findsNothing);
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('la invitación ya no dice «opcional»', (tester) async {
      await montar(tester, formulario());

      expect(find.textContaining('Foto del producto *'), findsOneWidget);
      expect(find.textContaining('Foto del producto (opcional)'), findsNothing);
    });
  });

  group('la foto del combo', () {
    final pollo = _p('pollo', 'Pollo', 1800, 10, foto: 'https://x/pollo.png');
    final papas = _p('papas', 'Papas', 600, 7, foto: 'https://x/papas.png');

    testWidgets('si sus productos tienen foto, usa la imagen conjunta', (
      tester,
    ) async {
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
          productosParaCombo: [pollo, papas],
        ),
      );
      await tester.enterText(campo('Nombre del producto *'), 'Combo familiar');
      await armarCombo(tester);

      expect(find.byKey(const Key('imagen-conjunta')), findsOneWidget);
      expect(find.text('Falta: foto del combo'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final combo = capturarProductoCreado(provider);
      expect(combo.urlImagen, isEmpty);
      expect(combo.partes.map((p) => p.urlImagen), [
        'https://x/pollo.png',
        'https://x/papas.png',
      ]);
    });

    testWidgets('si ninguna parte tiene foto y no sube una, la pide', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(
          rubro: 'Restaurante',
          productosParaCombo: [
            _p('pollo', 'Pollo', 1800, 10),
            _p('papas', 'Papas', 600, 7),
          ],
        ),
      );
      await tester.enterText(campo('Nombre del producto *'), 'Combo');
      await armarCombo(tester);

      expect(find.text('Falta: foto del combo'), findsOneWidget);
    });

    testWidgets('puede subir una foto propia única', (tester) async {
      await montar(
        tester,
        formulario(
          rubro: 'Restaurante',
          productosParaCombo: [
            _p('pollo', 'Pollo', 1800, 10),
            _p('papas', 'Papas', 600, 7),
          ],
        ),
      );
      await tester.enterText(campo('Nombre del producto *'), 'Combo');
      await armarCombo(tester);
      await ponerFotoDelProducto(tester);

      expect(find.text('Falta: foto del combo'), findsNothing);
    });
  });

  group('MosaicoFotos', () {
    Future<void> montarMosaico(WidgetTester tester, List<String> urls) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 120,
            height: 120,
            child: MosaicoFotos(urls: urls),
          ),
        ),
      );
    }

    testWidgets('junta de 1 a 4 fotos, nunca más', (tester) async {
      for (final cuantas in [1, 2, 3, 4]) {
        await montarMosaico(tester, [
          for (var i = 0; i < cuantas; i++) 'https://x/$i.png',
        ]);
        expect(find.byType(Image), findsNWidgets(cuantas));
      }

      await montarMosaico(tester, [
        for (var i = 0; i < 7; i++) 'https://x/$i.png',
      ]);
      expect(find.byType(Image), findsNWidgets(MosaicoFotos.maximo));
    });

    testWidgets('ignora las partes sin foto y, sin ninguna, muestra un icono', (
      tester,
    ) async {
      await montarMosaico(tester, ['', 'https://x/a.png', '']);
      expect(find.byType(Image), findsOneWidget);

      await montarMosaico(tester, ['', '']);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });

  testWidgets('la tarjeta de un combo sin foto propia muestra el mosaico', (
    tester,
  ) async {
    final combo = Producto(
      id: 'c',
      negocioId: 'n',
      nombre: 'Combo familiar',
      precioCentavos: 2800,
      partes: const [
        ParteCombo(productoId: 'a', cantidad: 1, urlImagen: 'https://x/a.png'),
        ParteCombo(productoId: 'b', cantidad: 1, urlImagen: 'https://x/b.png'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductoCard(
            producto: combo,
            onEditar: null,
            onEliminar: null,
            onToggleDisponible: null,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mosaico-combo')), findsOneWidget);
  });
}
