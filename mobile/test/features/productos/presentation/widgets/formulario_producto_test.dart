import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario_producto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _ProductosProviderMock extends Mock implements ProductosProvider {}

class _ProductoFake extends Fake implements Producto {}

void main() {
  setUpAll(() => registerFallbackValue(_ProductoFake()));

  Widget formulario({ProductosProvider? provider}) {
    final contenido = Scaffold(
      body: FormularioProducto(
        producto: Producto(
          id: 'producto-1',
          negocioId: 'usuario-1',
          nombre: 'Cafe',
          precio: 12.5,
          stock: 0,
          categoria: 'Bebidas',
          unidadMedidaNombre: 'Unidad',
        ),
        categoriasDisponibles: const ['Bebidas'],
        unidadesDisponibles: const [
          UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
        ],
        onCancelar: () {},
      ),
    );
    return MaterialApp(
      home: provider == null
          ? contenido
          : ChangeNotifierProvider<ProductosProvider>.value(
              value: provider,
              child: contenido,
            ),
    );
  }

  Finder campo(String etiqueta) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
  );

  testWidgets('permite editar un producto con stock cero', (tester) async {
    await tester.pumpWidget(formulario());

    expect(find.text('0'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Guardar producto'),
    );
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('precio acepta coma y máximo dos decimales', (tester) async {
    await tester.pumpWidget(formulario());
    final precio = campo('Precio S/ *');

    await tester.enterText(precio, '18,25');
    expect(tester.widget<TextField>(precio).controller!.text, '18,25');

    for (final valorInvalido in [
      '18,256',
      '18.2.5',
      '-18',
      '18 soles',
      '18 2',
    ]) {
      await tester.enterText(precio, valorInvalido);
      expect(tester.widget<TextField>(precio).controller!.text, '18,25');
    }

    await tester.enterText(precio, '0');
    await tester.pump();
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Guardar producto'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('stock acepta solo enteros no negativos', (tester) async {
    await tester.pumpWidget(formulario());
    final stock = campo('Cantidad en stock *');

    await tester.enterText(stock, '12');
    expect(tester.widget<TextField>(stock).controller!.text, '12');

    for (final valorInvalido in ['12.5', '-1', '+1', 'doce', '1 2']) {
      await tester.enterText(stock, valorInvalido);
      expect(tester.widget<TextField>(stock).controller!.text, '12');
    }
  });

  testWidgets('normaliza la coma del precio al guardar', (tester) async {
    final provider = _ProductosProviderMock();
    when(
      () => provider.guardarProducto(
        any(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
      ),
    ).thenAnswer((_) async => true);
    await tester.pumpWidget(formulario(provider: provider));

    await tester.enterText(campo('Precio S/ *'), '10,25');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
    await tester.pump();

    final productoGuardado =
        verify(
              () => provider.guardarProducto(
                captureAny(),
                imagenBytes: any(named: 'imagenBytes'),
                nombreArchivo: any(named: 'nombreArchivo'),
              ),
            ).captured.single
            as Producto;
    expect(productoGuardado.precio, 10.25);
    expect(productoGuardado.stock, 0);
  });
}
