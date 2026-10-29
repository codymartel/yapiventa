import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mocktail/mocktail.dart';
import 'formulario_producto_helpers.dart';

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));

  group('modo medida', () {
    testWidgets('convierte kg con decimales a gramos enteros', (tester) async {
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
        formulario(provider: provider, catalogoVenta: catalogoConMedida()),
      );

      await tester.tap(find.text('Por medida'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nombre del producto *'), 'Arroz');
      await elegirEnDropdown(tester, 'Qué mides *', 'Peso');

      // El precio cubre 1 kg por defecto: no hay que escribir la cantidad.
      await tester.enterText(campo('Precio S/ *'), '10');
      await tester.enterText(campo('Stock *'), '1,5');
      await tester.pump();

      // El mínimo (100 g) y el incremento (50 g) NUNCA bloquean.
      final botonGuardar = find.widgetWithText(
        ElevatedButton,
        'Guardar producto',
      );
      await tester.tap(botonGuardar);
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.modoVenta, ModoVenta.medida);
      expect(producto.medidaFamilia, FamiliaUnidad.peso);
      expect(producto.medidaUnidad, 'kg');
      expect(producto.cantidadReferenciaBase, 1000);
      expect(producto.precioCentavos, 1000);
      expect(producto.stockBase, 1500);

      // La vista legacy que ve la web queda coherente: 1 kg, S/ 10.
      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['stock'], 1);
      expect(datos['precio'], 10.0);
      expect(datos['unidadMedidaNombre'], 'kg');
    });

    testWidgets('el stock por debajo del mínimo igual guarda', (tester) async {
      final provider = ProductosProviderMock();
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);

      final producto = Producto(
        id: 'producto-1',
        negocioId: 'negocio-1',
        nombre: 'Arroz',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1000,
        stockBase: 1500,
      );
      await montar(
        tester,
        formulario(
          producto: producto,
          provider: provider,
          catalogoVenta: catalogoConMedida(),
        ),
      );

      // 0,05 kg = 50 g: menos del mínimo (100 g) y no alineado al
      // incremento (50 g desde 100 g). Se guarda igual.
      await tester.enterText(campo('Stock *'), '0,05');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final guardado = capturarProductoGuardado(provider);
      expect(guardado.stockBase, 50);
    });

    testWidgets('una cantidad que truncada da cero se rechaza con mensaje', (
      tester,
    ) async {
      final provider = ProductosProviderMock();
      when(
        () => provider.guardarProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);

      final producto = Producto(
        id: 'producto-1',
        negocioId: 'negocio-1',
        nombre: 'Arroz',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1000,
        stockBase: 1500,
      );
      await montar(
        tester,
        formulario(
          producto: producto,
          provider: provider,
          catalogoVenta: catalogoConMedida(),
        ),
      );

      // 0,000 kg: el campo admite 3 decimales y truncado da 0 gramos.
      await tester.enterText(campo('Stock *'), '0,000');
      await tester.pump();

      expect(find.text('La cantidad es más pequeña que 1 g.'), findsOneWidget);
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  group('pasos 2 y 3: formulario sugerido', () {
    ProductosProviderMock providerQueCrea() {
      final provider = ProductosProviderMock();
      when(
        () => provider.crearProducto(
          any(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
        ),
      ).thenAnswer((_) async => true);
      return provider;
    }

    CatalogoVentaPersistido catalogoConRapidas() => CatalogoVentaPersistido(
      presentaciones: [presentacion('unidad')],
      medidas: [
        MedidaVentaPersistida(
          id: 'peso',
          nombre: 'Peso',
          familia: FamiliaUnidad.peso,
          unidadBase: RegistroUnidades.g,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 100,
          incrementoBase: 50,
          cantidadesRapidasBase: const [250, 500, 1000],
          permiteCantidad: true,
          permiteMonto: true,
          activa: true,
        ),
      ],
    );

    testWidgets('producto nuevo trae la primera presentación ya elegida', (
      tester,
    ) async {
      await montar(tester, formulario());

      expect(find.text('Formato: 1 unidad'), findsOneWidget);
      expect(find.text('por unidad'), findsOneWidget);
      expect(find.text('unidades'), findsOneWidget);
    });

    testWidgets('el precio dice por qué presentación y formato se cobra', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(catalogoVenta: catalogoConPresentaciones()),
      );

      await elegirEnDropdown(tester, 'Presentación *', 'Botella');
      await elegirEnDropdown(tester, 'Formato *', '625 ml');

      expect(find.text('por botella (625 ml)'), findsOneWidget);
      expect(find.text('botellas'), findsOneWidget);
    });

    testWidgets('con una sola medida activa, Qué mides viene elegido', (
      tester,
    ) async {
      final provider = providerQueCrea();
      await montar(
        tester,
        formulario(provider: provider, catalogoVenta: catalogoConMedida()),
      );

      await tester.tap(find.text('Por medida'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nombre del producto *'), 'Arroz');
      await tester.enterText(campo('Precio S/ *'), '4,50');
      await tester.enterText(campo('Stock *'), '25');
      await tester.pump();

      expect(find.text('1 kg'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.medidaFamilia, FamiliaUnidad.peso);
      expect(producto.cantidadReferenciaBase, 1000);
      expect(producto.precioCentavos, 450);
      expect(producto.stockBase, 25000);
      expect(producto.minimoBase, isNull);
      expect(producto.incrementoBase, isNull);
    });

    Producto jamonada(int referencia, int centavos) => Producto(
      id: 'producto-1',
      negocioId: 'negocio-1',
      nombre: 'Jamonada',
      modoVenta: ModoVenta.medida,
      medidaFamilia: FamiliaUnidad.peso,
      medidaUnidad: 'kg',
      cantidadReferenciaBase: referencia,
      precioCentavos: centavos,
      stockBase: 2000,
    );

    testWidgets('un producto guardado por 250 g abre en ¼ kg', (tester) async {
      await montar(
        tester,
        formulario(
          producto: jamonada(250, 300),
          catalogoVenta: catalogoConMedida(),
        ),
      );

      expect(find.text('¼ kg'), findsOneWidget);
      expect(campo('Cantidad que cubre el precio *'), findsNothing);
      final equivalencia = tester.widget<Text>(
        find.byKey(const Key('equivalencia-medida')),
      );
      expect(equivalencia.data, '= S/ 12.00 por kg');
    });

    testWidgets('un producto guardado por 300 g abre en otra cantidad', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(
          producto: jamonada(300, 500),
          catalogoVenta: catalogoConMedida(),
        ),
      );

      expect(find.text('Otra cantidad…'), findsOneWidget);
      expect(campo('Cantidad que cubre el precio *'), findsOneWidget);
      expect(find.widgetWithText(TextField, '300'), findsOneWidget);
      // 5.00 por 300 g no da un precio exacto por kg: se muestra con ≈.
      final equivalencia = tester.widget<Text>(
        find.byKey(const Key('equivalencia-medida')),
      );
      expect(equivalencia.data, contains('≈ S/ 16.66 por kg'));
    });

    testWidgets('mínimo e incremento propios se guardan en el producto', (
      tester,
    ) async {
      final provider = providerQueCrea();
      await montar(
        tester,
        formulario(provider: provider, catalogoVenta: catalogoConMedida()),
      );

      await tester.tap(find.text('Por medida'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nombre del producto *'), 'Arroz');
      await tester.enterText(campo('Precio S/ *'), '4,50');
      await tester.enterText(campo('Stock *'), '25');

      final interruptor = find.byKey(const Key('switch-regla-propia'));
      await tester.ensureVisible(interruptor);
      await tester.tap(interruptor);
      await tester.pumpAndSettle();
      // Parte de la regla del negocio (100 g, de 50 en 50 g).
      expect(find.widgetWithText(TextField, '100'), findsOneWidget);
      expect(find.widgetWithText(TextField, '50'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('minimo-propio')), '250');
      await tester.enterText(find.byKey(const Key('incremento-propio')), '250');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
      await tester.pump();

      final producto = capturarProductoCreado(provider);
      expect(producto.minimoBase, 250);
      expect(producto.incrementoBase, 250);
      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['minimoBase'], 250);
      expect(datos['incrementoBase'], 250);
    });

    testWidgets('la vista previa muestra rápidas con precio y el monto', (
      tester,
    ) async {
      await montar(tester, formulario(catalogoVenta: catalogoConRapidas()));

      await tester.tap(find.text('Por medida'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Precio S/ *'), '4,50');
      await tester.pump();

      expect(find.text('¼ kg · S/ 1.12'), findsOneWidget);
      expect(find.text('½ kg · S/ 2.25'), findsOneWidget);
      expect(find.text('1 kg · S/ 4.50'), findsOneWidget);
      final monto = tester.widget<Text>(find.byKey(const Key('monto-ejemplo')));
      expect(monto.data, contains('se cobra S/ 1.80'));
    });
  });

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
      await tester.tap(find.text('Por medida'));
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
