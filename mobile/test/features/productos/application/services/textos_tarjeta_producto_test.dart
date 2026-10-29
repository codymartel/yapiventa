import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/textos_tarjeta_producto.dart';
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
}
