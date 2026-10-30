import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/foto_producto.dart';
import 'package:mocktail/mocktail.dart';

import 'formulario_producto_helpers.dart';

void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));
  setUp(usarSelectorDeFotosFalso);

  ProductosProviderMock providerQueGuarda() {
    final provider = ProductosProviderMock();
    when(
      () => provider.crearProducto(
        any(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
        fotosModelos: any(named: 'fotosModelos'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => provider.guardarProducto(
        any(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
        fotosModelos: any(named: 'fotosModelos'),
      ),
    ).thenAnswer((_) async => true);
    return provider;
  }

  String? falta(WidgetTester tester) {
    final texto = find.byKey(const Key('falta-para-guardar'));
    return texto.evaluate().isEmpty ? null : tester.widget<Text>(texto).data;
  }

  Future<void> decirSi(WidgetTester tester) async {
    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();
  }

  /// Escribe en el campo número [indice] con esa etiqueta.
  Future<void> escribir(
    WidgetTester tester,
    String etiqueta,
    String texto, {
    int indice = 0,
  }) async {
    await tester.enterText(campo(etiqueta).at(indice), texto);
    await tester.pump();
  }

  Future<void> guardar(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar producto'));
    await tester.pump();
  }

  group('polo con modelos por presentación', () {
    Future<void> armarPolo(WidgetTester tester) async {
      await escribirNombre(tester);
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Color')));
      await tester.pump();

      await escribir(tester, 'Nombre del color *', 'Azul');
      await escribir(tester, 'Talla', 'S');
      await escribir(tester, 'Precio S/', '35');
      await escribir(tester, 'Stock', '4');
      await tester.tap(find.text('Agregar talla').first);
      await tester.pump();
      await escribir(tester, 'Talla', 'M', indice: 1);
      await escribir(tester, 'Precio S/', '38', indice: 1);
      await escribir(tester, 'Stock', '6', indice: 1);

      // Un modelo nuevo copia las tallas del primero: solo falta el stock.
      await tester.tap(find.byKey(const Key('agregar-modelo')));
      await tester.pump();
      await escribir(tester, 'Nombre del color *', 'Rojo', indice: 1);
      await escribir(tester, 'Stock', '2', indice: 2);
      await escribir(tester, 'Stock', '5', indice: 3);
      await ponerFotos(tester);
    }

    testWidgets('guarda modelos, filas, precio desde y stock total', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      await montar(tester, formulario(provider: provider, rubro: 'Ropa'));
      await armarPolo(tester);

      expect(falta(tester), isNull);
      await guardar(tester);

      final producto = capturarProductoCreado(provider);
      expect(producto.modoVenta, ModoVenta.presentacion);
      expect(producto.tituloModelos, 'Color');
      expect(producto.tituloFilas, 'Talla');
      expect(producto.modelos.map((m) => m.nombre), ['Azul', 'Rojo']);
      expect(producto.modelos.first.filas.map((f) => f.etiqueta), ['S', 'M']);
      expect(producto.modelos.last.filas.map((f) => f.etiqueta), ['S', 'M']);
      expect(producto.modelos.last.filas.map((f) => f.stock), [2, 5]);
      expect(producto.precioCentavos, 3500);
      expect(producto.stock, 17);

      // Lo que lee la tienda actual: precio desde y stock total.
      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['precio'], 35.0);
      expect(datos['stock'], 17);
      expect((datos['modelos'] as List), hasLength(2));
    });

    testWidgets('una foto principal elegida antes del Sí no se sube', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      await montar(tester, formulario(provider: provider, rubro: 'Ropa'));
      await tester.tap(find.byType(FotoProducto));
      await tester.pumpAndSettle();

      await armarPolo(tester);
      await guardar(tester);

      verify(
        () => provider.crearProducto(
          any(),
          imagenBytes: null,
          nombreArchivo: null,
          fotosModelos: any(named: 'fotosModelos'),
        ),
      ).called(1);
    });

    testWidgets('el total del modelo se suma solo, con candado', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await armarPolo(tester);

      final totales = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('total-modelo-'),
      );
      expect(totales, findsNWidgets(2));
      expect(tester.widgetList<Text>(totales).map((t) => t.data), ['10', '7']);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });

    testWidgets('«Falta» guía en el orden de la pantalla', (tester) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await escribirNombre(tester);
      await decirSi(tester);
      expect(falta(tester), 'Falta: cómo se llama lo que cambia');

      await tester.tap(find.byKey(const Key('sugerencia-Color')));
      await tester.pump();
      expect(falta(tester), 'Falta: nombre del color');

      await escribir(tester, 'Nombre del color *', 'Azul');
      expect(falta(tester), 'Falta: foto de Azul');

      await ponerFotos(tester);
      expect(falta(tester), 'Falta: nombre de talla de Azul');

      await escribir(tester, 'Talla', 'S');
      expect(falta(tester), 'Falta: precio de Azul · S');

      await escribir(tester, 'Precio S/', '35');
      expect(falta(tester), 'Falta: stock de Azul · S');

      await escribir(tester, 'Stock', '4');
      expect(falta(tester), isNull);
    });

    testWidgets('la misma talla dos veces avisa y no deja guardar', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Ropa'));
      await escribirNombre(tester);
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Color')));
      await tester.pump();
      await escribir(tester, 'Nombre del color *', 'Azul');
      await escribir(tester, 'Talla', 'M');
      await escribir(tester, 'Precio S/', '35');
      await escribir(tester, 'Stock', '3');
      await tester.tap(find.text('Agregar talla').first);
      await tester.pump();
      await escribir(tester, 'Talla', 'm', indice: 1);
      await escribir(tester, 'Precio S/', '35', indice: 1);
      await escribir(tester, 'Stock', '2', indice: 1);
      await ponerFotos(tester);

      expect(find.textContaining('dos veces'), findsOneWidget);
      expect(falta(tester), startsWith('Revisa:'));
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar producto'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('con stock infinito no se pide el stock de las filas', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      await montar(tester, formulario(provider: provider, rubro: 'Ropa'));
      await escribirNombre(tester);
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Color')));
      await tester.pump();
      await escribir(tester, 'Nombre del color *', 'Azul');
      await escribir(tester, 'Talla', 'S');
      await escribir(tester, 'Precio S/', '35');
      await ponerFotos(tester);

      expect(falta(tester), 'Falta: stock de Azul · S');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Stock infinito'));
      await tester.pump();

      expect(campo('Stock'), findsNothing);
      expect(falta(tester), isNull);
      await guardar(tester);
      expect(capturarProductoCreado(provider).esStockInfinito, isTrue);
    });
  });

  group('la talla no choca con la presentación', () {
    testWidgets('con formatos de botella la fila elige el tamaño real', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      await montar(tester, formulario(provider: provider, rubro: 'Bodega'));
      await escribirNombre(tester, 'Gaseosa');
      await elegirEnDropdown(tester, 'Presentación *', 'Botella');
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Sabor')));
      await tester.pump();
      await escribir(tester, 'Nombre del sabor *', 'Inca Kola');

      // El envase da nombre a la fila: no hay selector «Dentro de cada…».
      expect(find.textContaining('Dentro de cada'), findsNothing);
      expect(find.text('Talla'), findsNothing);
      await elegirEnDropdown(tester, 'Botella', 'de 625 ml');
      await escribir(tester, 'Precio S/', '2.5');
      await escribir(tester, 'Stock', '24');
      await ponerFotos(tester);
      await guardar(tester);

      final producto = capturarProductoCreado(provider);
      expect(producto.presentacionId, 'botella');
      final fila = producto.modelos.single.filas.single;
      expect(fila.etiqueta, '625 ml');
      expect(fila.formatoValorBase, 625);
      expect(fila.formatoFamilia, FamiliaUnidad.volumen);
      expect(fila.formatoUnidad, 'ml');
    });

    testWidgets('sin elegir el tamaño de la fila no se puede guardar', (
      tester,
    ) async {
      await montar(tester, formulario(rubro: 'Bodega'));
      await escribirNombre(tester, 'Gaseosa');
      await elegirEnDropdown(tester, 'Presentación *', 'Botella');
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Sabor')));
      await tester.pump();
      await escribir(tester, 'Nombre del sabor *', 'Inca Kola');
      await ponerFotos(tester);

      expect(falta(tester), 'Falta: nombre de formato de Inca Kola');
    });
  });

  group('por medida con modelos', () {
    testWidgets('queso fresco y andino: una fila por modelo', (tester) async {
      final provider = providerQueGuarda();
      await montar(
        tester,
        formulario(provider: provider, catalogoVenta: catalogoConMedida()),
      );
      await tester.tap(find.text('Lo peso'));
      await tester.pumpAndSettle();
      await escribirNombre(tester, 'Queso');
      await decirSi(tester);
      await tester.tap(find.byKey(const Key('sugerencia-Tipo')));
      await tester.pump();

      // El precio simple y el stock simple desaparecen: van en cada modelo.
      expect(campo('Precio S/ *'), findsNothing);
      expect(campo('Stock *'), findsNothing);
      expect(find.text('Cada precio es por *'), findsOneWidget);

      await escribir(tester, 'Nombre del tipo *', 'Fresco');
      await escribir(tester, 'Precio S/ por 1 kg', '18');
      await escribir(tester, 'Stock', '4');
      await tester.tap(find.byKey(const Key('agregar-modelo')));
      await tester.pump();
      await escribir(tester, 'Nombre del tipo *', 'Andino', indice: 1);
      await escribir(tester, 'Precio S/ por 1 kg', '24', indice: 1);
      await escribir(tester, 'Stock', '2.5', indice: 1);
      await ponerFotos(tester);

      expect(falta(tester), isNull);
      await guardar(tester);

      final producto = capturarProductoCreado(provider);
      expect(producto.modoVenta, ModoVenta.medida);
      expect(producto.cantidadReferenciaBase, 1000);
      expect(producto.precioCentavos, 1800);
      expect(producto.stockBase, 6500);
      expect(producto.modelos.map((m) => m.filas.single.stockBase), [
        4000,
        2500,
      ]);
      expect(producto.modelos.map((m) => m.filas.single.precioCentavos), [
        1800,
        2400,
      ]);
    });

    testWidgets('el total del modelo sale en la unidad del producto', (
      tester,
    ) async {
      await montar(tester, formulario(catalogoVenta: catalogoConMedida()));
      await tester.tap(find.text('Lo peso'));
      await tester.pumpAndSettle();
      await decirSi(tester);

      await escribir(tester, 'Stock', '2.5');

      expect(find.text('2.5 kg'), findsOneWidget);
    });
  });

  group('editar un producto con modelos', () {
    final guardado = Producto(
      id: 'p1',
      negocioId: 'n1',
      nombre: 'Polo básico',
      categoria: 'Bebidas',
      modoVenta: ModoVenta.presentacion,
      presentacionId: 'unidad',
      precioCentavos: 3500,
      stock: 10,
      tituloModelos: 'Color',
      tituloFilas: 'Talla',
      modelos: const [
        ModeloProducto(
          id: 'azul',
          nombre: 'Azul',
          urlImagen: 'https://img.test/azul.jpg',
          filas: [
            FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 4),
            FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 6),
          ],
        ),
      ],
    );

    testWidgets('vuelven los modelos, las filas y el total', (tester) async {
      await montar(tester, formulario(producto: guardado, rubro: 'Ropa'));

      expect(find.byKey(const Key('lista-modelos')), findsOneWidget);
      expect(campo('Nombre del color *'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Azul'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('total-modelo-azul'))).data,
        '10',
      );
      expect(falta(tester), isNull);
    });

    testWidgets('guarda sin perder los ids del modelo ni de las filas', (
      tester,
    ) async {
      final provider = providerQueGuarda();
      await montar(
        tester,
        formulario(producto: guardado, provider: provider, rubro: 'Ropa'),
      );

      await escribir(tester, 'Stock', '9');
      await guardar(tester);

      final nuevo = capturarProductoGuardado(provider);
      expect(nuevo.modelos.single.id, 'azul');
      expect(nuevo.modelos.single.filas.map((f) => f.id), ['s', 'm']);
      expect(nuevo.modelos.single.filas.first.stock, 9);
      expect(nuevo.stock, 15);
    });
  });

  group('la medida desactivada con modelos', () {
    testWidgets('se ve fija y los modelos siguen donde estaban', (
      tester,
    ) async {
      final queso = Producto(
        id: 'q1',
        negocioId: 'n1',
        nombre: 'Queso',
        categoria: 'Bebidas',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1800,
        stockBase: 4000,
        tituloModelos: 'Tipo',
        modelos: const [
          ModeloProducto(
            id: 'fresco',
            nombre: 'Fresco',
            filas: [FilaVenta(id: 'f', precioCentavos: 1800, stockBase: 4000)],
          ),
        ],
      );
      final desactivada = CatalogoVentaPersistido(
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
            activa: false,
          ),
        ],
      );

      await montar(
        tester,
        formulario(producto: queso, catalogoVenta: desactivada),
      );

      expect(find.byKey(const Key('medida-fija')), findsOneWidget);
      expect(find.byKey(const Key('lista-modelos')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Fresco'), findsOneWidget);
    });
  });
}

Future<void> escribirNombre(
  WidgetTester tester, [
  String nombre = 'Polo básico',
]) async {
  await tester.enterText(campo('Nombre del producto *'), nombre);
  await tester.pump();
}
