import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/textos_tarjeta_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

/// Producto por medida tal como lo arma el formulario: SIN los campos viejos
/// precio y stock (en 0). La tarjeta no debe depender de ellos.
Producto _porMedida({
  required int referencia,
  required int centavos,
  String unidad = 'kg',
  int? stockBase,
  bool infinito = false,
}) => Producto(
  negocioId: 'n1',
  nombre: 'Jamonada',
  modoVenta: ModoVenta.medida,
  medidaFamilia: FamiliaUnidad.peso,
  medidaUnidad: unidad,
  cantidadReferenciaBase: referencia,
  precioCentavos: centavos,
  stockBase: stockBase,
  esStockInfinito: infinito,
);

void main() {
  group('precio por medida', () {
    test('lo que escribió + el precio por kg cuando la cuenta es exacta', () {
      final producto = _porMedida(referencia: 250, centavos: 300);
      expect(
        TextosTarjetaProducto.precio(producto),
        'S/ 3.00 / ¼ kg · S/ 12.00 / kg',
      );
    });

    test('por 1 kg no repite la equivalencia', () {
      final producto = _porMedida(referencia: 1000, centavos: 1200);
      expect(TextosTarjetaProducto.precio(producto), 'S/ 12.00 / kg');
    });

    test('si la cuenta no es exacta solo muestra lo escrito', () {
      // 5.00 por 300 g serían 16.666… por kg: no se inventa un precio.
      final producto = _porMedida(referencia: 300, centavos: 500);
      expect(TextosTarjetaProducto.precio(producto), 'S/ 5.00 / 300 g');
    });

    test('300 g a S/ 3.00 sí es exacto: S/ 10.00 por kg', () {
      final producto = _porMedida(referencia: 300, centavos: 300);
      expect(
        TextosTarjetaProducto.precio(producto),
        'S/ 3.00 / 300 g · S/ 10.00 / kg',
      );
    });

    test('con unidad habitual g el precio por kg también se ve', () {
      final producto = _porMedida(
        referencia: 100,
        centavos: 200,
        unidad: 'g',
        stockBase: 1500,
      );
      expect(
        TextosTarjetaProducto.precio(producto),
        'S/ 2.00 / 100 g · S/ 20.00 / kg',
      );
      expect(TextosTarjetaProducto.stock(producto), '1500 g');
    });
  });

  group('stock', () {
    test('por medida muestra decimales en la unidad del producto', () {
      final producto = _porMedida(
        referencia: 250,
        centavos: 300,
        stockBase: 16650,
      );
      expect(TextosTarjetaProducto.stock(producto), '16.65 kg');
    });

    test('stock ilimitado', () {
      final producto = _porMedida(
        referencia: 1000,
        centavos: 100,
        infinito: true,
      );
      expect(TextosTarjetaProducto.stock(producto), 'ilimitado');
    });

    test('por presentación dice botellas o unidades', () {
      final botellas = Producto(
        negocioId: 'n1',
        nombre: 'Cerveza',
        presentacionId: 'botella',
        precioCentavos: 850,
        stock: 12,
      );
      final unidades = Producto(
        negocioId: 'n1',
        nombre: 'Pan',
        presentacionId: 'unidad',
        precioCentavos: 100,
        stock: 1,
      );
      expect(TextosTarjetaProducto.stock(botellas), '12 botellas');
      expect(TextosTarjetaProducto.stock(unidades), '1 unidades');
    });
  });

  group('precio por presentación y antiguos', () {
    test('botella con su formato', () {
      final producto = Producto(
        negocioId: 'n1',
        nombre: 'Cerveza',
        presentacionId: 'botella',
        formatoValorBase: 625,
        formatoFamilia: FamiliaUnidad.volumen,
        formatoUnidad: 'ml',
        precioCentavos: 850,
        stock: 12,
      );
      expect(
        TextosTarjetaProducto.precio(producto),
        'S/ 8.50 / botella (625 ml)',
      );
    });

    test('unidad no repite el formato', () {
      final producto = Producto(
        negocioId: 'n1',
        nombre: 'Pan',
        presentacionId: 'unidad',
        formatoValorBase: 1,
        formatoFamilia: FamiliaUnidad.conteo,
        formatoUnidad: 'unidad',
        precioCentavos: 400,
        stock: 7,
      );
      expect(TextosTarjetaProducto.precio(producto), 'S/ 4.00 / unidad');
    });

    test('un producto antiguo se ve como siempre, con su unidad', () {
      final producto = Producto(
        negocioId: 'n1',
        nombre: 'Huevos',
        precioCentavos: 1650,
        stock: 12,
        unidadMedidaNombre: 'Saco',
        fraccionesSeleccionadas: const ['1/2'],
      );
      expect(TextosTarjetaProducto.precio(producto), 'S/ 16.50');
      expect(TextosTarjetaProducto.stock(producto), '12 uds.');
      expect(TextosTarjetaProducto.unidadAntigua(producto), 'Saco');
      expect(
        TextosTarjetaProducto.lineaUnidadAntigua(producto),
        'Saco · fracción: 1/2',
      );
    });

    test('los productos nuevos no repiten la unidad en otra línea', () {
      final producto = _porMedida(
        referencia: 1000,
        centavos: 450,
      ).copyWith(unidadMedidaNombre: 'kg');
      expect(TextosTarjetaProducto.unidadAntigua(producto), isEmpty);
      expect(TextosTarjetaProducto.lineaUnidadAntigua(producto), isEmpty);
    });
  });

  group('con modelos', () {
    Producto polo({List<int> precios = const [3500, 3500, 3800]}) => Producto(
      negocioId: 'n1',
      nombre: 'Polo básico',
      presentacionId: 'unidad',
      tituloModelos: 'Color',
      modelos: [
        ModeloProducto(
          id: 'azul',
          nombre: 'Azul',
          filas: [
            for (var i = 0; i < precios.length; i++)
              FilaVenta(
                id: 'f$i',
                etiqueta: 'T$i',
                precioCentavos: precios[i],
                stock: 4,
              ),
          ],
        ),
        const ModeloProducto(
          id: 'rojo',
          nombre: 'Rojo',
          filas: [FilaVenta(id: 'f', precioCentavos: 3500, stock: 2)],
        ),
      ],
    );

    test('precios distintos se muestran como «desde»', () {
      expect(TextosTarjetaProducto.precio(polo()), 'desde S/ 35.00 / unidad');
    });

    test('si todas las filas cuestan lo mismo no dice «desde»', () {
      expect(
        TextosTarjetaProducto.precio(polo(precios: [3500, 3500])),
        'S/ 35.00 / unidad',
      );
    });

    test('el stock es la suma de las filas y dice cuántos colores', () {
      // 3 filas × 4 + 2 = 14 unidades en 2 colores.
      expect(TextosTarjetaProducto.stock(polo()), '14 unidades · 2 colores');
    });

    test('con un solo modelo usa el singular', () {
      final uno = polo().copyWith(modelos: [polo().modelos.first]);
      expect(TextosTarjetaProducto.stock(uno), '12 unidades · 1 color');
    });

    test('la palabra la pone el vendedor: aromas, sabores…', () {
      final aromas = polo().copyWith(tituloModelos: 'Aroma');
      expect(TextosTarjetaProducto.stock(aromas), contains('2 aromas'));
      final sinPalabra = polo().copyWith(tituloModelos: '');
      expect(TextosTarjetaProducto.stock(sinPalabra), contains('2 modelos'));
    });

    test('con stock ilimitado no muestra cantidades', () {
      final infinito = polo().copyWith(esStockInfinito: true);
      expect(TextosTarjetaProducto.stock(infinito), 'ilimitado');
    });

    test('por medida suma el stock base de todos los modelos', () {
      final queso = Producto(
        negocioId: 'n1',
        nombre: 'Queso',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        tituloModelos: 'Tipo',
        modelos: const [
          ModeloProducto(
            id: 'a',
            nombre: 'Fresco',
            filas: [FilaVenta(id: 'f', precioCentavos: 1800, stockBase: 4000)],
          ),
          ModeloProducto(
            id: 'b',
            nombre: 'Andino',
            filas: [FilaVenta(id: 'f', precioCentavos: 2400, stockBase: 2500)],
          ),
        ],
      );

      expect(TextosTarjetaProducto.stock(queso), '6.5 kg · 2 tipos');
      expect(TextosTarjetaProducto.precio(queso), 'desde S/ 18.00 / kg');
    });
  });

  group('presentación propia del negocio (Jaba)', () {
    final huevos = Producto(
      negocioId: 'n1',
      nombre: 'Huevos',
      presentacionId: 'jaba',
      presentacionNombre: 'Jaba',
      precioCentavos: 1650,
      stock: 12,
    );

    test('el precio y el stock dicen «jaba» aunque no esté en el catálogo', () {
      expect(TextosTarjetaProducto.precio(huevos), 'S/ 16.50 / jaba');
      expect(TextosTarjetaProducto.stock(huevos), '12 jabas');
    });

    test('con variables dice jabas y cuántos tipos', () {
      final conTipos = huevos.copyWith(
        tituloModelos: 'Tipo',
        modelos: const [
          ModeloProducto(
            id: 'a',
            nombre: 'Rosados',
            filas: [FilaVenta(id: 'f', precioCentavos: 1650, stock: 12)],
          ),
          ModeloProducto(
            id: 'b',
            nombre: 'Blancos',
            filas: [FilaVenta(id: 'f', precioCentavos: 900, stock: 8)],
          ),
        ],
      );

      expect(TextosTarjetaProducto.stock(conTipos), '20 jabas · 2 tipos');
      expect(TextosTarjetaProducto.precio(conTipos), 'desde S/ 9.00 / jaba');
    });

    test('un producto anterior sin nombre guardado usa el del catálogo', () {
      final botella = Producto(
        negocioId: 'n1',
        nombre: 'Cerveza',
        presentacionId: 'botella',
        precioCentavos: 850,
        stock: 3,
      );
      expect(TextosTarjetaProducto.stock(botella), '3 botellas');
    });
  });
}
