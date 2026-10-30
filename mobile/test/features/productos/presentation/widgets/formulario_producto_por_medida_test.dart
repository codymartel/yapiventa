import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  group('Bloque A: «Por», casos y «Falta»', () {
    MedidaVentaPersistida medida({
      required FamiliaUnidad familia,
      required UnidadRegistrada unidad,
      bool activa = true,
    }) {
      final peso = familia == FamiliaUnidad.peso;
      return MedidaVentaPersistida(
        id: peso ? 'peso' : 'volumen',
        nombre: peso ? 'Peso' : 'Volumen',
        familia: familia,
        unidadBase: RegistroUnidades.baseDe(familia),
        unidadVisual: unidad,
        minimoBase: peso ? 100 : 250,
        incrementoBase: peso ? 50 : 250,
        cantidadesRapidasBase: const [250, 500, 1000],
        activa: activa,
      );
    }

    CatalogoVentaPersistido catalogo(List<MedidaVentaPersistida> medidas) =>
        CatalogoVentaPersistido(
          presentaciones: [presentacion('unidad')],
          medidas: medidas,
        );

    ProductosProviderMock providerQueGuarda() {
      final provider = ProductosProviderMock();
      when(
        () => provider.crearProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);
      return provider;
    }

    String? falta(WidgetTester tester) {
      final texto = find.byKey(const Key('falta-para-guardar'));
      return texto.evaluate().isEmpty ? null : tester.widget<Text>(texto).data;
    }

    Future<void> abrirMedida(WidgetTester tester, Widget widget) async {
      await montar(tester, widget);
      await tester.tap(find.text('Lo peso'));
      await tester.pumpAndSettle();
    }

    testWidgets('ya no existe «Unidad de venta»: la unidad es la del negocio', (
      tester,
    ) async {
      await abrirMedida(tester, formulario(catalogoVenta: catalogoConMedida()));

      expect(find.text('Unidad de venta *'), findsNothing);
      final ayuda = tester.widget<Text>(
        find.byKey(const Key('unidad-habitual')),
      );
      expect(ayuda.data, contains('kg'));
    });

    testWidgets('el menú «Por» ofrece las cantidades típicas del peso', (
      tester,
    ) async {
      await abrirMedida(tester, formulario(catalogoVenta: catalogoConMedida()));

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField && w.decoration.labelText == 'Por *',
        ),
      );
      await tester.pumpAndSettle();

      for (final etiqueta in [
        '1 kg',
        '½ kg',
        '¼ kg',
        '100 g',
        'Otra cantidad…',
      ]) {
        expect(find.text(etiqueta), findsWidgets, reason: etiqueta);
      }
    });

    testWidgets(
      'S/ 3.00 por ¼ kg se guarda tal cual y muestra S/ 12.00 por kg',
      (tester) async {
        final provider = providerQueGuarda();
        await abrirMedida(
          tester,
          formulario(provider: provider, catalogoVenta: catalogoConMedida()),
        );
        await tester.enterText(campo('Nombre del producto *'), 'Jamonada');
        await tester.enterText(campo('Precio S/ *'), '3.00');
        await elegirEnDropdown(tester, 'Por *', '¼ kg');
        await tester.enterText(campo('Stock *'), '16.65');
        await tester.pump();

        final equivalencia = tester.widget<Text>(
          find.byKey(const Key('equivalencia-medida')),
        );
        expect(equivalencia.data, '= S/ 12.00 por kg');

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Guardar producto'),
        );
        await tester.pump();

        final producto = capturarProductoCreado(provider);
        expect(producto.cantidadReferenciaBase, 250);
        expect(producto.precioCentavos, 300);
        expect(producto.stockBase, 16650);
        expect(producto.medidaUnidad, 'kg');
      },
    );

    testWidgets('S/ 12 por 1 g avisa que son S/ 12000.00 por kg', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      await abrirMedida(
        tester,
        formulario(provider: provider, catalogoVenta: catalogoConMedida()),
      );
      await tester.enterText(campo('Nombre del producto *'), 'Azafrán');
      await tester.enterText(campo('Precio S/ *'), '12');
      await elegirEnDropdown(tester, 'Por *', 'Otra cantidad…');
      await tester.enterText(campo('Cantidad que cubre el precio *'), '1');
      await elegirEnDropdown(tester, 'Unidad', 'g');
      await tester.enterText(campo('Stock *'), '2');
      await tester.pump();

      final alarma = tester.widget<Text>(
        find.byKey(const Key('equivalencia-medida')),
      );
      expect(alarma.data, contains('= S/ 12000.00 por kg'));
      expect(alarma.data, contains('¿Es correcto?'));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      // Se guarda lo que el vendedor escribió, sin convertir.
      final producto = capturarProductoCreado(provider);
      expect(producto.cantidadReferenciaBase, 1);
      expect(producto.precioCentavos, 1200);
    });

    testWidgets('con unidad habitual g el stock se escribe en gramos', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      final especias = catalogo([
        medida(familia: FamiliaUnidad.peso, unidad: RegistroUnidades.g),
      ]);
      await abrirMedida(
        tester,
        formulario(provider: provider, catalogoVenta: especias),
      );
      await tester.enterText(campo('Nombre del producto *'), 'Comino');
      await tester.enterText(campo('Precio S/ *'), '2');
      await elegirEnDropdown(tester, 'Por *', '100 g');
      await tester.enterText(campo('Stock *'), '1500');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.medidaUnidad, 'g');
      expect(producto.cantidadReferenciaBase, 100);
      expect(producto.precioCentavos, 200);
      expect(producto.stockBase, 1500);
    });

    testWidgets('con varias medidas activas «Qué mides» no se elige solo', (
      tester,
    ) async {
      final bodega = catalogo([
        medida(familia: FamiliaUnidad.peso, unidad: RegistroUnidades.kg),
        medida(familia: FamiliaUnidad.volumen, unidad: RegistroUnidades.L),
      ]);
      await abrirMedida(tester, formulario(catalogoVenta: bodega));
      await tester.enterText(campo('Nombre del producto *'), 'Aceite');
      await tester.pump();

      expect(find.text('Elige qué mides'), findsOneWidget);
      expect(falta(tester), 'Falta: qué mides');

      await elegirEnDropdown(tester, 'Qué mides *', 'Volumen');
      expect(find.text('1 L'), findsOneWidget);
      expect(falta(tester), 'Falta: precio');
    });

    testWidgets('medida desactivada: se ve fija con aviso y no cambia', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      final desactivada = catalogo([
        medida(
          familia: FamiliaUnidad.peso,
          unidad: RegistroUnidades.kg,
          activa: false,
        ),
        medida(familia: FamiliaUnidad.volumen, unidad: RegistroUnidades.L),
      ]);
      final arroz = Producto(
        id: 'producto-1',
        negocioId: 'negocio-1',
        nombre: 'Arroz',
        categoria: 'Bebidas',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 450,
        stockBase: 25000,
      );
      await montar(
        tester,
        formulario(
          producto: arroz,
          provider: provider,
          catalogoVenta: desactivada,
        ),
      );

      expect(find.byKey(const Key('medida-fija')), findsOneWidget);
      expect(find.byKey(const Key('aviso-medida-desactivada')), findsOneWidget);
      expect(find.text('Qué mides *'), findsNothing);

      await tester.enterText(campo('Precio S/ *'), '5');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final guardado = capturarProductoGuardado(provider);
      expect(guardado.modoVenta, ModoVenta.medida);
      expect(guardado.medidaFamilia, FamiliaUnidad.peso);
      expect(guardado.medidaUnidad, 'kg');
      expect(guardado.precioCentavos, 500);
      expect(guardado.stockBase, 25000);
    });

    testWidgets('«Falta» sigue el orden del formulario en una medida', (
      tester,
    ) async {
      await abrirMedida(tester, formulario(catalogoVenta: catalogoConMedida()));

      expect(falta(tester), 'Falta: nombre del producto');
      await tester.enterText(campo('Nombre del producto *'), 'Arroz');
      await tester.pump();
      expect(falta(tester), 'Falta: precio');
      await tester.enterText(campo('Precio S/ *'), '4.50');
      await tester.pump();
      expect(falta(tester), 'Falta: stock');
      await tester.enterText(campo('Stock *'), '0,000');
      await tester.pump();
      expect(falta(tester), 'Revisa: stock');
      await tester.enterText(campo('Stock *'), '25');
      await tester.pump();
      expect(falta(tester), isNull);
    });

    testWidgets('«Falta» pide la cantidad de «Otra cantidad» antes del stock', (
      tester,
    ) async {
      await abrirMedida(tester, formulario(catalogoVenta: catalogoConMedida()));
      await tester.enterText(campo('Nombre del producto *'), 'Queso');
      await tester.enterText(campo('Precio S/ *'), '5');
      await elegirEnDropdown(tester, 'Por *', 'Otra cantidad…');
      await tester.pump();

      expect(falta(tester), 'Falta: cantidad de «Otra cantidad»');
      await tester.enterText(campo('Cantidad que cubre el precio *'), '300');
      await tester.pump();
      expect(falta(tester), 'Falta: stock');
    });

    testWidgets('«Falta» en presentación: nombre, precio y stock', (
      tester,
    ) async {
      await montar(tester, formulario());

      expect(falta(tester), 'Falta: nombre del producto');
      await tester.enterText(campo('Nombre del producto *'), 'Cerveza');
      await tester.pump();
      expect(falta(tester), 'Falta: precio');
      await tester.enterText(campo('Precio S/ *'), '8.50');
      await tester.pump();
      expect(falta(tester), 'Falta: stock');
      await tester.enterText(campo('Stock *'), '12');
      await tester.pump();
      expect(falta(tester), isNull);
    });
  });
}
