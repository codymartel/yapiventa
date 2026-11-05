import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_stock_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../helpers/pedidos_de_prueba.dart';

Producto? Function(String) catalogo(List<Producto> productos) {
  final porId = {for (final p in productos) p.id: p};
  return (id) => porId[id];
}

void main() {
  group('calcular: qué se descuenta', () {
    test(
      'suma todo el carrito por producto: dos líneas, un solo descuento',
      () {
        final r = CalculoStockPedido.calcular([
          lineaSimple(cantidad: 3),
          lineaSimple(cantidad: 4),
        ], catalogo([productoSimple(stock: 10)]));

        expect(r.ok, isTrue);
        expect(r.descuentos, hasLength(1));
        expect(r.descuentos.single.cantidad, 7);
        expect(r.descuentos.single.enBase, isFalse);
      },
    );

    test(
      'stock justo alcanza; uno menos, no: dice cuánto pide y cuánto hay',
      () {
        final justo = CalculoStockPedido.calcular([
          lineaSimple(cantidad: 10),
        ], catalogo([productoSimple(stock: 10)]));
        final corto = CalculoStockPedido.calcular([
          lineaSimple(cantidad: 11),
        ], catalogo([productoSimple(stock: 10)]));

        expect(justo.ok, isTrue);
        expect(corto.ok, isFalse);
        expect(corto.faltas.single.pide, 11);
        expect(corto.faltas.single.hay, 10);
        expect(corto.descuentos, isEmpty);
      },
    );

    test('por medida descuenta en unidad base (350 g de queso)', () {
      final r = CalculoStockPedido.calcular([
        lineaQueso(350),
      ], catalogo([quesoPorMedida(stockBase: 1200)]));

      expect(r.ok, isTrue);
      expect(r.descuentos.single.cantidad, 350);
      expect(r.descuentos.single.enBase, isTrue);
    });

    test('por medida que no alcanza: 1 300 g con 1 200 g', () {
      final r = CalculoStockPedido.calcular([
        lineaQueso(1300),
      ], catalogo([quesoPorMedida(stockBase: 1200)]));

      expect(r.faltas.single.hay, 1200);
      expect(r.faltas.single.pide, 1300);
    });

    test('modelo y fila: descuenta de la fila elegida', () {
      final r = CalculoStockPedido.calcular([
        lineaSimple(
          productoId: 'polo',
          nombre: 'Polo básico',
          cantidad: 2,
          modeloId: 'luna',
          filaId: 'm',
        ),
      ], catalogo([poloConModelos(stockM: 3)]));

      expect(r.ok, isTrue);
      expect(r.descuentos.single.filaId, 'm');
      expect(r.descuentos.single.cantidad, 2);
    });

    test('una fila con poco stock no se salva con el de otra fila', () {
      final r = CalculoStockPedido.calcular([
        lineaSimple(
          productoId: 'polo',
          nombre: 'Polo básico',
          cantidad: 4,
          modeloId: 'luna',
          filaId: 'm',
        ),
      ], catalogo([poloConModelos(stockM: 3, stockL: 9)]));

      expect(r.faltas.single.hay, 3);
    });

    test('una fila que ya no existe se avisa, no se descuenta', () {
      final r = CalculoStockPedido.calcular([
        lineaSimple(
          productoId: 'polo',
          nombre: 'Polo básico',
          modeloId: 'luna',
          filaId: 'xxl',
        ),
      ], catalogo([poloConModelos()]));

      expect(r.ok, isFalse);
      expect(r.sinProducto, ['Polo básico']);
      expect(r.descuentos, isEmpty);
    });

    test('un combo descuenta cada parte × cantidad y suma con lo suelto', () {
      final r = CalculoStockPedido.calcular(
        [
          lineaSimple(
            productoId: 'combo',
            nombre: 'Combo personal',
            cantidad: 2,
            precioCentavos: 1500,
          ),
          lineaSimple(cantidad: 1),
        ],
        catalogo([
          comboGaseosaYPapas(),
          productoSimple(stock: 10),
          productoSimple(id: 'papas', nombre: 'Papas', stock: 10),
        ]),
      );

      final porProducto = {
        for (final d in r.descuentos) d.productoId: d.cantidad,
      };
      expect(r.ok, isTrue);
      expect(porProducto['gaseosa'], 3); // 2 del combo + 1 suelta
      expect(porProducto['papas'], 4); // 2 combos × 2
    });

    test('un combo se frena por la parte que no alcanza', () {
      final r = CalculoStockPedido.calcular(
        [
          lineaSimple(
            productoId: 'combo',
            nombre: 'Combo personal',
            cantidad: 3,
          ),
        ],
        catalogo([
          comboGaseosaYPapas(),
          productoSimple(stock: 10),
          productoSimple(id: 'papas', nombre: 'Papas', stock: 5),
        ]),
      );

      expect(r.faltas.single.nombre, 'Papas');
      expect(r.faltas.single.pide, 6);
      expect(r.faltas.single.hay, 5);
    });

    test('stock infinito no descuenta nada', () {
      final r = CalculoStockPedido.calcular([
        lineaSimple(cantidad: 500),
      ], catalogo([productoSimple(stock: 0, infinito: true)]));

      expect(r.ok, isTrue);
      expect(r.descuentos, isEmpty);
    });

    test('un producto borrado se avisa por su nombre', () {
      final r = CalculoStockPedido.calcular([
        lineaSimple(nombre: 'Gaseosa Inca'),
      ], catalogo([]));

      expect(r.sinProducto, ['Gaseosa Inca']);
    });

    test('idsDeLineas no repite productos', () {
      final ids = CalculoStockPedido.idsDeLineas([
        lineaSimple(),
        lineaSimple(),
        lineaSimple(productoId: 'papas'),
      ]);

      expect(ids, ['gaseosa', 'papas']);
    });
  });

  group('aplicar: descontar y devolver sobre el producto', () {
    const descuento7 = DescuentoStock(productoId: 'gaseosa', cantidad: 7);

    test('descontar resta y devolver suma lo mismo', () {
      final bajo = CalculoStockPedido.aplicar(productoSimple(stock: 10), [
        descuento7,
      ], devolver: false);
      final vuelta = CalculoStockPedido.aplicar(bajo.producto, [
        descuento7,
      ], devolver: true);

      expect(bajo.producto.stock, 3);
      expect(vuelta.producto.stock, 10);
    });

    test('con modelos, baja la fila y recalcula el total del producto', () {
      final r =
          CalculoStockPedido.aplicar(poloConModelos(stockM: 3, stockL: 2), [
            const DescuentoStock(
              productoId: 'polo',
              modeloId: 'luna',
              filaId: 'm',
              cantidad: 2,
            ),
          ], devolver: false);

      final filas = r.producto.modelos.single.filas;
      expect(filas.firstWhere((f) => f.id == 'm').stock, 1);
      expect(filas.firstWhere((f) => f.id == 'l').stock, 2);
      expect(r.producto.stock, 3);
    });

    test(
      'por medida: si el vendedor repuso stock, cancelar suma sin perderlo',
      () {
        // Queso: 1 200 g, el pedido descuenta 350 g y quedan 850 g.
        const d = DescuentoStock(
          productoId: 'queso',
          cantidad: 350,
          enBase: true,
        );
        final bajo = CalculoStockPedido.aplicar(
          quesoPorMedida(stockBase: 1200),
          [d],
          devolver: false,
        );
        expect(bajo.producto.stockBase, 850);

        // El vendedor repone 500 g (850 → 1 350) y se cancela el pedido.
        final repuesto = bajo.producto.copyWith(stockBase: 1350);
        final vuelta = CalculoStockPedido.aplicar(repuesto, [
          d,
        ], devolver: true);

        expect(vuelta.producto.stockBase, 1700);
      },
    );

    test('una fila borrada se cuenta como omitida y el resto se devuelve', () {
      final r = CalculoStockPedido.aplicar(poloConModelos(stockM: 3), [
        const DescuentoStock(
          productoId: 'polo',
          modeloId: 'luna',
          filaId: 'xxl',
          cantidad: 1,
        ),
        const DescuentoStock(
          productoId: 'polo',
          modeloId: 'luna',
          filaId: 'm',
          cantidad: 2,
        ),
      ], devolver: true);

      expect(r.omitidos, 1);
      expect(
        r.producto.modelos.single.filas.firstWhere((f) => f.id == 'm').stock,
        5,
      );
    });

    test('ignora los descuentos de otros productos y el stock infinito', () {
      final otro = CalculoStockPedido.aplicar(productoSimple(stock: 10), [
        const DescuentoStock(productoId: 'papas', cantidad: 4),
      ], devolver: false);
      final infinito = CalculoStockPedido.aplicar(
        productoSimple(stock: 0, infinito: true),
        [descuento7],
        devolver: false,
      );

      expect(otro.producto.stock, 10);
      expect(infinito.producto.stock, 0);
    });

    test('nunca deja el stock en negativo', () {
      final r = CalculoStockPedido.aplicar(productoSimple(stock: 2), [
        descuento7,
      ], devolver: false);

      expect(r.producto.stock, 0);
    });
  });
}
